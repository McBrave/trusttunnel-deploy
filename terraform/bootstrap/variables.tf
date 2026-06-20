variable "aws_region" {
  description = "AWS region to create the state bucket and lock table in."
  type        = string
  default     = "eu-north-1"
}

variable "state_bucket_name" {
  description = <<-EOT
    Globally unique S3 bucket name for Terraform remote state.
    S3 bucket names are global across all of AWS, not just your account,
    so the default below will likely collide with someone else's bucket.
    Override this in terraform.tfvars or via -var.
  EOT
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking."
  type        = string
  default     = "trusttunnel-tf-lock"
}
