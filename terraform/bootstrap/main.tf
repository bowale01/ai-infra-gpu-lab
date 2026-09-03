# ---------------------------------------------------------------------------
# Bootstrap: creates the S3 bucket + DynamoDB table used as the remote backend
# for the main configuration in ../.
#
# This solves the chicken-and-egg problem: the backend can't create the very
# resources it needs to store state. So this small config runs FIRST with LOCAL
# state to create them, then the main config uses them as its backend.
#
# Run once:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
#
# Then configure the backend in ../backend.hcl and run `terraform init` in ../.
#
# You normally never destroy this — it holds the state for everything else.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# S3 bucket that stores the Terraform state file.
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  # State is precious. Keep this bucket around even if the config is destroyed.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = var.state_bucket_name
    Purpose   = "terraform-remote-state"
    ManagedBy = "terraform-bootstrap"
  }
}

# Keep a version history of the state file so you can recover from mistakes.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (it can contain sensitive values).
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to the state bucket.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking. Prevents two people (or two runs) from
# writing state at the same time and corrupting it.
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = var.lock_table_name
    Purpose   = "terraform-state-locking"
    ManagedBy = "terraform-bootstrap"
  }
}
