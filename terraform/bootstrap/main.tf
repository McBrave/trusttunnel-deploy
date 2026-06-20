terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Intentionally local state here. This config creates the bucket and
  # table that every other root module uses for remote state, so it
  # can't depend on remote state itself (chicken-and-egg). Run this
  # once, by hand, and treat it as effectively read-only afterward.
}

provider "aws" {
  region = var.aws_region
}

# Bucket that will hold the .tfstate files for environments/dev (and
# any future environments).
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  # Safety net: without this, a stray `terraform destroy` against the
  # bootstrap config (or an accidental console deletion) could take
  # the bucket out from under every other environment's state.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Table used for state locking, so two `terraform apply` runs against
# the same environment can't stomp on each other.
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}
