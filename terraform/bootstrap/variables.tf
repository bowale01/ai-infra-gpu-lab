variable "region" {
  description = "AWS region for the state bucket and lock table. Keep this the same as your main config's region."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state. S3 bucket names are global, so add something unique (e.g. your initials or account id)."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name used for state locking."
  type        = string
  default     = "ai-infra-tf-locks"
}
