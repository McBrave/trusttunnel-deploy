variable "project_name" {
  description = "Short name used as a prefix for all resource tags/names in this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to create the security group in. Comes from modules/vpc output."
  type        = string
}

variable "public_subnet_id" {
  description = "Subnet ID to launch the instance in. Comes from modules/vpc output."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "Your existing SSH public key contents (e.g. the contents of ~/.ssh/id_ed25519.pub)."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH in, e.g. \"203.0.113.4/32\". Keep this scoped to your own IP."
  type        = string
}
