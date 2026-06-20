variable "project_name" {
  description = "Short name used as a prefix for all resource tags/names in this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet."
  type        = string
}
