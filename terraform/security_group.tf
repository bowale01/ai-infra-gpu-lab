# Security group for the benchmark instance.
#
# Access is via AWS Systems Manager (SSM) Session Manager, NOT SSH. SSM works entirely
# over the instance's OUTBOUND connection to the SSM service, so we open ZERO inbound
# ports. No SSH, no public notebook port, no attack surface. This is the big security win
# of the SSM approach.
#
# Egress stays open so the SSM agent can reach the service and so we can pip-install
# packages / download anything the benchmark needs.
resource "aws_security_group" "gpu_sg" {
  name        = "${var.project_name}-sg"
  description = "No inbound; SSM-only access for the benchmark instance"

  egress {
    description = "Allow all outbound (SSM endpoints, package installs, downloads)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}
