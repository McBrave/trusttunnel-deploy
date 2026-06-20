# Remote state. Bucket and table names here must match the outputs
# from terraform/bootstrap (run once, separately, with local state).
#
# Terraform backend blocks cannot reference variables, so these values
# are duplicated here by hand after bootstrap creates them. Copy this
# file to backend.tf and fill in your actual bucket name, or pass
# -backend-config flags to `terraform init` instead if you'd rather
# not hardcode it.
terraform {
  backend "s3" {
    bucket         = "trusttunnelmcbrave21" # must match bootstrap's state_bucket_name
    key            = "environments/dev/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "trusttunnel-tf-lock" # must match bootstrap's lock_table_name
    encrypt        = true
  }
}
