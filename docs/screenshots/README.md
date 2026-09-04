# Screenshots

AWS console screenshots documenting the live GPU run. Drop your image files in this
folder (`.png` or `.jpg`).

## Suggested filenames

Using these names means they'll match the embed links already prepared for the main
README, so they show up automatically once you add them:

| Filename | What to capture |
|---|---|
| `ec2-instance-running.png`   | EC2 → Instances → the g4dn.xlarge, State: Running |
| `security-group-no-inbound.png` | EC2 → Security Groups → `ai-infra-gpu-benchmark-sg` → empty Inbound rules |
| `ssm-online.png`             | Systems Manager → Fleet Manager / Session Manager → instance Online |
| `iam-ssm-role.png`           | IAM → Roles → `ai-infra-gpu-benchmark-ssm-role` |
| `s3-state-bucket.png`        | S3 → the state bucket → `ai-infra/` + `benchmark-results/` |
| `dynamodb-lock-table.png`    | DynamoDB → Tables → `ai-infra-tf-locks` |
| `nvidia-smi-terminal.png`    | Your SSM terminal showing `nvidia-smi` (Tesla T4) |

Any extra shots are welcome — just add them and tell me and I'll link them in.

> Tip: crop out any personal account details you don't want public (account number in the
> top-right, email, etc.). The account ID isn't a secret but it's tidy to blur it.
