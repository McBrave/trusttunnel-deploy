output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state. Used in environments/*/backend.tf."
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  description = "Name of the DynamoDB table used for state locking. Used in environments/*/backend.tf."
  value       = aws_dynamodb_table.tf_lock.name
}
