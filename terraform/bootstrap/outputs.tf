output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state — put this in ../backend.hcl"
  value       = aws_s3_bucket.tf_state.id
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table — put this in ../backend.hcl"
  value       = aws_dynamodb_table.tf_lock.id
}

output "next_steps" {
  description = "What to do after bootstrapping"
  value       = "Copy ../backend.hcl.example to ../backend.hcl, fill in the bucket + table above, then run: cd .. ; terraform init -backend-config=backend.hcl"
}
