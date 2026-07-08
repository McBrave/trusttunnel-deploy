# Phase 4: k3s instance for the observability stack (Prometheus + Grafana).
#
# Lives in the SAME VPC as the VPN instance so Prometheus can scrape the
# metrics endpoint over the private network without exposing it publicly.

# Same AMI lookup as the EC2 module — Ubuntu 22.04 LTS.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Instance sizing ---
# t3.small (2 vCPU, 2 GB RAM) is the minimum viable for k3s + kube-prometheus-stack.
# The stack idles at ~1.2 GB RSS; t3.micro (1 GB) OOM-kills Prometheus during startup.
# t3.medium (4 GB) is more comfortable but doubles the cost (~$30/mo vs ~$15/mo).
# Start with t3.small — upgrade only if you see OOMKilled pods.
variable "k3s_instance_type" {
  description = "EC2 instance type for the k3s observability node."
  type        = string
  default     = "t3.medium"
}

# --- Security group for the k3s node ---
resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-k3s-sg"
  description = "k3s observability node: SSH, HTTP/S ingress for Grafana, k8s API"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTPS - Grafana via Ingress + cert-manager"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP - ACME HTTP-01 fallback and redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API - for remote kubectl (operator IP only)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-k3s-sg"
    Project = var.project_name
  }
}

# --- Metrics bridge: allow k3s to scrape the VPN instance on port 1987 ---
# SG-to-SG reference — survives destroy/recreate cycles because Terraform
# resolves the SG ID dynamically, never a hardcoded sg-xxxx string.
resource "aws_security_group_rule" "vpn_metrics_from_k3s" {
  type                     = "ingress"
  description              = "Prometheus scrape from k3s node (Phase 4 metrics bridge)"
  from_port                = 1987
  to_port                  = 1987
  protocol                 = "tcp"
  security_group_id        = module.ec2.security_group_id
  source_security_group_id = aws_security_group.k3s.id
}

# --- EC2 instance ---
resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.k3s_instance_type
  subnet_id              = module.vpc.public_subnet_id
  key_name               = module.ec2.key_pair_name
  vpc_security_group_ids = [aws_security_group.k3s.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project_name}-k3s"
    Project = var.project_name
  }
}

resource "aws_eip" "k3s" {
  instance = aws_instance.k3s.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-k3s-eip"
    Project = var.project_name
  }
}

# --- Outputs ---
output "k3s_public_ip" {
  description = "Public IP of the k3s node. Used by Ansible inventory and kubeconfig rewrite."
  value       = aws_eip.k3s.public_ip
}

output "k3s_private_ip" {
  description = "Private IP of the k3s node (for internal reference)."
  value       = aws_instance.k3s.private_ip
}

output "vpn_private_ip" {
  description = "Private IP of the VPN instance. Prometheus uses this to scrape metrics over the VPC."
  value       = module.ec2.private_ip
}
