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

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-deployer-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "trusttunnel" {
  name        = "${var.project_name}-sg"
  description = "SSH from a single trusted IP, plus 443/80 for TrustTunnel and ACME"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from trusted IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "TrustTunnel (TLS over HTTP/2 and HTTP/3)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TrustTunnel HTTP/3 (QUIC, UDP)"
    from_port   = 443
    to_port     = 443
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ACME HTTP-01 challenge for Lets Encrypt certbot"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

resource "aws_instance" "trusttunnel" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.trusttunnel.id]

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project_name}-vpn-endpoint"
    Project = var.project_name
  }
}

resource "aws_eip" "trusttunnel" {
  instance = aws_instance.trusttunnel.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}
