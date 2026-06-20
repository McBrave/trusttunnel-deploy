variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Short name used as a prefix for all resource tags/names."
  type        = string
  default     = "trusttunnel"
}

variable "instance_type" {
  description = "EC2 instance type for the VPN endpoint."
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "Your SSH public key contents, used to create the AWS key pair."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH in, e.g. \"203.0.113.4/32\". Keep this scoped to your own IP."
  type        = string
}
