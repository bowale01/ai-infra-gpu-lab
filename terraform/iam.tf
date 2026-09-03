# IAM role + instance profile that lets the EC2 instance register with AWS Systems
# Manager (SSM). This is what enables Session Manager access with NO SSH port open.
#
# The AmazonSSMManagedInstanceCore managed policy grants exactly the permissions the
# SSM agent needs to talk to the SSM service — nothing more.

# Trust policy: WHO is allowed to assume this role. By naming the EC2 service as the
# principal, we say "EC2 instances may take on this role." Without this, attaching the
# role to an instance would be rejected. This is separate from WHAT the role can do —
# that comes from the policy attachment below.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.project_name}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Name = "${var.project_name}-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project_name}-ssm-profile"
  role = aws_iam_role.ssm.name
}
