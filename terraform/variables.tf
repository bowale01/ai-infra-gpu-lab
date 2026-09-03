variable "region" {
  description = "AWS region to deploy into. GPU instances and the Deep Learning AMI are widely available in us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type. Use a cheap CPU type (e.g. t3.medium) for the dry-run, then g4dn.xlarge (NVIDIA T4) for the real GPU benchmark once the G/VT vCPU quota is approved."
  type        = string
  default     = "g4dn.xlarge"
}

variable "use_deep_learning_ami" {
  description = "true = AWS Deep Learning AMI (PyTorch/CUDA preinstalled, needed for GPU). false = plain Ubuntu 22.04 (fine + cheap for the CPU dry-run, where we pip-install torch)."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB. The Deep Learning AMI needs headroom for CUDA + frameworks; a plain Ubuntu dry-run can use much less."
  type        = number
  default     = 120
}

variable "auto_shutdown_hours" {
  description = "Safety net: automatically shut the instance down after this many hours so a forgotten instance can't keep billing. Set to 0 to disable."
  type        = number
  default     = 4

  validation {
    condition     = var.auto_shutdown_hours >= 0
    error_message = "auto_shutdown_hours must be 0 (disabled) or a positive number."
  }
}

variable "project_name" {
  description = "Name tag applied to all resources for easy identification and cost tracking."
  type        = string
  default     = "ai-infra-gpu-benchmark"
}
