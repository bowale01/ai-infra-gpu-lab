output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.gpu.id
}

output "ami_id" {
  description = "Resolved AMI ID (Deep Learning or Ubuntu depending on use_deep_learning_ami)"
  value       = local.ami_id
}

output "ssm_start_session_command" {
  description = "Open an interactive shell on the instance via SSM (no SSH, no key needed)"
  value       = "aws ssm start-session --target ${aws_instance.gpu.id} --region ${var.region}"
}

output "ssm_jupyter_port_forward_command" {
  description = "Forward the instance's Jupyter port 8888 to your localhost:8888 via SSM"
  value       = "aws ssm start-session --target ${aws_instance.gpu.id} --region ${var.region} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"8888\"],\"localPortNumber\":[\"8888\"]}'"
}

output "auto_shutdown" {
  description = "Auto-shutdown safety net status"
  value       = var.auto_shutdown_hours > 0 ? "Instance will auto power-off after ${var.auto_shutdown_hours}h" : "disabled"
}

output "reminder" {
  description = "Cost reminder"
  value       = "Run 'terraform destroy' when finished to stop billing and remove all resources."
}
