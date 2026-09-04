terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in S3 with DynamoDB locking.
  # Values are supplied at init time via a backend config file so the bucket name
  # (and your account specifics) stay out of version control:
  #   terraform init -backend-config=backend.hcl
  # The S3 bucket and DynamoDB table are created first by ./bootstrap.
  backend "s3" {
    key     = "ai-infra/terraform.tfstate"
    encrypt = true
    # bucket         -> from backend.hcl
    # region         -> from backend.hcl
    # dynamodb_table -> from backend.hcl
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

# Look up the latest AWS Deep Learning AMI (GPU, PyTorch) — NVIDIA drivers, CUDA, and
# PyTorch preinstalled. Used for the real GPU benchmark.
data "aws_ami" "deep_learning" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Deep Learning OSS Nvidia Driver AMI GPU PyTorch*Ubuntu*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Plain Ubuntu 22.04 — cheap and quick for the CPU dry-run, where we pip-install torch.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  # Pick the AMI based on the run type: the Deep Learning AMI for the real GPU benchmark
  # (drivers + CUDA + PyTorch baked in), or plain Ubuntu for a cheap CPU dry-run.
  ami_id = var.use_deep_learning_ami ? data.aws_ami.deep_learning.id : data.aws_ami.ubuntu.id

  # Auto-shutdown safety net. If auto_shutdown_hours > 0, schedule a poweroff so a
  # forgotten instance stops billing itself. `terraform destroy` still removes it fully;
  # this just stops the compute charge if we both forget.
  #
  # `user_data` is a script the instance runs once at first boot. Here it calls the Linux
  # `shutdown` command with a delay in MINUTES (hours * 60), and `-P` means power off
  # (not just halt), which actually stops EC2 billing for compute.
  shutdown_script = <<-EOF
    #!/bin/bash
    shutdown -P +${var.auto_shutdown_hours * 60} "Auto-shutdown safety net: powering off after ${var.auto_shutdown_hours}h"
  EOF

  # If the safety net is disabled (0), pass null so no user_data script runs at all.
  user_data = var.auto_shutdown_hours > 0 ? local.shutdown_script : null
}

resource "aws_instance" "gpu" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  vpc_security_group_ids = [aws_security_group.gpu_sg.id]
  user_data              = local.user_data

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  tags = {
    Name = var.project_name
  }
}
