# AI Infra Lab — CPU vs GPU Performance for Machine Learning

![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?logo=amazonwebservices&logoColor=white)
![EC2 GPU](https://img.shields.io/badge/EC2-g4dn.xlarge-FF9900?logo=amazonec2&logoColor=white)
![NVIDIA T4](https://img.shields.io/badge/NVIDIA-T4%20GPU-76B900?logo=nvidia&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?logo=pytorch&logoColor=white)
![CUDA](https://img.shields.io/badge/CUDA-76B900?logo=nvidia&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)
![SSM](https://img.shields.io/badge/Access-SSM%20Session%20Manager-232F3E?logo=amazonwebservices&logoColor=white)
![License: Unlicense](https://img.shields.io/badge/License-Unlicense-blue.svg)

> **Stack in one line:** Terraform provisions an AWS EC2 GPU instance (NVIDIA T4, Deep
> Learning AMI); PyTorch/CUDA run the CPU-vs-GPU benchmarks; access is via SSM (no SSH);
> Terraform state lives in S3 + DynamoDB.

A hands-on infrastructure project that provisions a GPU-backed EC2 instance on AWS with
**Terraform**, runs a set of **PyTorch** benchmarks comparing CPU vs GPU, and produces
charts you can publish. Built as a portfolio piece for AI Infrastructure / GPU / HPC work.

> Everything is defined as code. Spin the environment up with one command, run the
> benchmarks, publish the results, then tear it all down with `terraform destroy` so you
> never pay for an idle GPU.

---

## What exactly are we doing here?

**In one sentence:** we use Terraform to stand up a real GPU server on AWS, run the same
machine-learning math on a CPU and on the GPU, measure how much faster the GPU is, and
then destroy the server so it costs almost nothing.

That's the whole loop. But the *reason* it's built this way is the point of the project,
so here's the longer version.

Modern AI runs on **accelerators** — GPUs today, and increasingly specialized chips. A
model like an LLM or an image classifier is, under the hood, a mountain of the same small
math operation (multiply-add) repeated billions of times. A CPU does those more or less
one after another with a handful of powerful cores. A GPU has thousands of smaller cores
that do them all *at the same time*. When the work is big and parallel, that's the
difference between a training job finishing in an hour versus a week.

This project makes that difference **visible and measurable** with two workloads:

- **Matrix multiplication** at growing sizes — the raw building block of every neural
  network layer. It shows the exact point where the GPU stops being overkill and starts
  crushing the CPU.
- **CNN training** — a small image model trained for a few steps, measured in
  images/second. This is closer to a real training job.

### Why this matters for AI Infrastructure and HPC

I'm using this as a stepping stone into **AI infrastructure, GPU, and HPC** work, so the
project is deliberately about the *infrastructure engineer's* job, not the data
scientist's. The model is trivial on purpose — the interesting, career-relevant skills are
everything around it:

- **Provisioning accelerators as code.** Real GPU fleets aren't clicked together in a
  console; they're described in Terraform so they're reproducible, reviewable, and
  disposable. That's the core HPC/infra discipline.
- **Access without attack surface.** Instead of opening SSH to the internet, access goes
  through **AWS SSM Session Manager** — no inbound ports, no SSH keys to leak, every
  session authenticated by IAM and logged. This is how mature teams reach their machines.
- **Remote, locked state.** Terraform state lives in **S3 with DynamoDB locking**, the
  same pattern a team would use so two engineers can't corrupt each other's changes.
- **Cost control as a first-class concern.** GPUs are expensive by the hour. The project
  bakes in `terraform destroy` and an **auto-shutdown safety net** so an idle accelerator
  can't quietly rack up a bill — exactly the discipline that matters when you own a fleet.
- **Measuring, not guessing.** Knowing *when* a GPU actually helps (big parallel work) and
  when it's wasted money (tiny models, tiny batches) is the judgment call infra engineers
  are paid to make. This project builds the intuition with real numbers.

Put simply: the benchmark is the hook, but the **infrastructure around it is the résumé.**

### The full loop this demonstrates

1. **Provision** a GPU instance reproducibly (Terraform + AWS Deep Learning AMI)
2. **Secure** it (access via SSM Session Manager — zero inbound ports, no SSH keys, IAM-controlled and logged)
3. **Benchmark** CPU vs GPU on representative workloads (matrix multiply + CNN training)
4. **Measure & visualize** where the GPU wins and by how much
5. **Tear down** cleanly to control cost (plus an auto-shutdown safety net)

---

## Tech stack — what each piece does

| Tool / service | Role in this project |
|---|---|
| **Terraform** | Infrastructure as code. Declares the whole environment (GPU instance, IAM, security group, state backend) so it's reproducible and can be created or destroyed with one command. |
| **AWS EC2** | The compute. A `g4dn.xlarge` instance provides the physical GPU we benchmark against a CPU. |
| **NVIDIA T4 GPU** | The accelerator under test — the hardware that runs the parallel math the benchmarks measure. |
| **AWS Deep Learning AMI** | The instance's operating system image, with NVIDIA drivers, CUDA, and PyTorch preinstalled — so no manual GPU driver setup. |
| **AWS SSM Session Manager** | How we get a shell into the instance. Works over the instance's outbound connection, so **no inbound ports / no SSH keys**. IAM-gated and logged. |
| **AWS IAM** | The permissions layer. An IAM role + instance profile grants the instance exactly the access it needs to register with SSM — nothing more. |
| **Amazon S3** | Stores the Terraform state file remotely — versioned and encrypted — so state is durable and shareable rather than trapped on one laptop. |
| **Amazon DynamoDB** | State **locking**. Prevents two `terraform apply` runs from writing state at the same time and corrupting it. |
| **Security Group** | The instance firewall. Configured with **zero inbound rules** (SSM needs none) and open egress for package downloads. |
| **PyTorch** | The ML framework the benchmarks are written in. Runs the same operations on CPU and GPU so the comparison is apples-to-apples. |
| **CUDA** | NVIDIA's GPU compute layer that PyTorch calls under the hood to actually run work on the T4. |
| **Python** | The language for the benchmark scripts and the results/plotting glue. |
| **Matplotlib** | Renders the benchmark results into the charts you publish. |
| **Jupyter Notebook** | An interactive version of the benchmarks (`notebooks/cpu_vs_gpu.ipynb`), mirroring the original lab, reached via SSM port-forwarding. |
| **AWS CLI** | Drives AWS from the terminal — checking the GPU quota, opening SSM sessions, and authenticating Terraform. |
| **Bash / PowerShell** | Helper scripts: `setup.sh` prepares the instance; the rest of the workflow runs from PowerShell on Windows. |

---

## Architecture

```
Local machine                                   AWS (us-east-1)
+-------------------+                       +----------------------------------+
|  Terraform CLI    |  ---- provision --->  |  EC2 g4dn.xlarge (NVIDIA T4)     |
|  AWS CLI + SSM    |  <== SSM session ==>  |  AWS Deep Learning AMI          |
|  plugin           |   (no inbound ports)  |  PyTorch + CUDA pre-installed   |
|  Jupyter (browser)|  <= SSM port-fwd ===  |  IAM role: SSM core             |
+-------------------+                       |  Security group: NO inbound     |
        |                                   +----------------------------------+
        v
   Terraform state ->  S3 bucket (versioned, encrypted) + DynamoDB lock table
```

Access runs *over the instance's outbound connection to the SSM service*, so the security
group opens **zero inbound ports** — no SSH, no public notebook. Jupyter is reached by
forwarding a port through the same SSM channel.

---

## Repository layout

```
AI-Infra/
├── README.md                  # This file
├── .gitignore
├── terraform/                 # Infrastructure as code
│   ├── main.tf                # EC2 instance + AMI lookup + S3 backend + auto-shutdown
│   ├── iam.tf                 # IAM role + instance profile for SSM access
│   ├── variables.tf           # region, instance type, AMI choice, auto-shutdown
│   ├── outputs.tf             # SSM session + port-forward commands
│   ├── security_group.tf      # NO inbound; egress-only (SSM)
│   ├── backend.hcl.example    # S3 backend config (bucket, region, lock table)
│   ├── terraform.tfvars.example
│   └── bootstrap/             # creates the S3 bucket + DynamoDB lock table
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── benchmarks/
│   ├── requirements.txt
│   ├── bench_utils.py         # device detection + accurate CUDA timing helpers
│   ├── matmul_benchmark.py    # CPU vs GPU matrix multiply
│   ├── cnn_benchmark.py       # CPU vs GPU CNN training
│   └── plot_results.py        # renders charts from results/
├── notebooks/
│   └── cpu_vs_gpu.ipynb       # Notebook version (mirrors the lab)
├── scripts/
│   ├── setup.sh               # install deps / verify GPU on the instance
│   └── tunnel.sh              # (legacy SSH tunnel; SSM port-forward is preferred)
├── results/                   # benchmark output (json + png)
└── docs/
    └── writeup.md             # blog-post-style narrative for your site
```

---

## Prerequisites

- An AWS account with permission to create EC2, IAM roles, security groups, S3, DynamoDB
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured (`aws configure` or SSO)
- The [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
  for the AWS CLI (on Windows: `winget install Amazon.SessionManagerPlugin`). This is what
  lets you open a shell into the instance — no SSH key needed.
- **GPU vCPU quota**: new accounts typically have a **0 quota** for G/VT instances (it's
  0 in every region until you ask). Request an increase for "Running On-Demand G and VT
  instances" — `terraform apply` fails with `VcpuLimitExceeded` until it's granted:

  ```powershell
  # Easiest: use the helper script to file the request and track its status
  ./scripts/check_quota.ps1 -Request     # file a request for 4 vCPUs
  ./scripts/check_quota.ps1              # check current quota + request status
  ```

  Or with the raw AWS CLI:

  ```powershell
  aws service-quotas request-service-quota-increase --service-code ec2 --quota-code L-DB2E81BA --desired-value 4 --region us-east-1
  ```

---

## Quick start

### 1. Configure your variables

```powershell
cd terraform
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. For the real GPU run:

- `instance_type = "g4dn.xlarge"`
- `use_deep_learning_ami = true`
- `root_volume_size = 120`
- `auto_shutdown_hours = 4`   # safety net; set 0 to disable

No SSH key or IP allow-listing needed — access is via SSM.

### 2. Bootstrap the remote state backend (one time)

State lives in **S3** with **DynamoDB** locking so it's durable, versioned, and safe for
concurrent runs. The bucket and lock table are created first by a small bootstrap config
(you can't store state in a backend that doesn't exist yet):

```powershell
cd bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars -> set a globally-unique state_bucket_name
terraform init
terraform apply
cd ..
```

Then point the main config at that backend:

```powershell
Copy-Item backend.hcl.example backend.hcl
# edit backend.hcl -> paste the bucket + table names from the bootstrap output
```

### 3. Provision

```powershell
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Terraform prints ready-to-paste **SSM** commands (session + Jupyter port-forward) and the
auto-shutdown status. It can take a minute or two after apply for the instance to register
with SSM before a session will connect.

### 4. Connect and run the benchmarks

Open a shell on the instance via SSM (no SSH, no key):

```powershell
aws ssm start-session --target <instance-id> --region us-east-1
```

On the instance, get the code there (`git clone` your repo), then:

```bash
cd AI-Infra/benchmarks
bash ../scripts/setup.sh        # verifies the GPU, installs matplotlib/jupyter
python matmul_benchmark.py
python cnn_benchmark.py
python plot_results.py          # writes charts into ../results/
```

To use the notebook instead, start Jupyter on the instance and forward its port through
SSM (no public port opened):

```powershell
aws ssm start-session --target <instance-id> --region us-east-1 `
  --document-name AWS-StartPortForwardingSession `
  --parameters '{\"portNumber\":[\"8888\"],\"localPortNumber\":[\"8888\"]}'
```

Then open the `http://localhost:8888/?token=...` URL Jupyter prints.

### 5. Tear it all down

```powershell
terraform destroy
```

This deletes the instance, IAM role, and security group so billing stops. The S3 state
bucket stays put for next time. **Do this when you're done** — and the auto-shutdown net
will power the box off after `auto_shutdown_hours` even if you forget.

---

## Cost note

`g4dn.xlarge` (NVIDIA T4) runs about **$0.53/hour** on-demand in `us-east-1`. The
benchmarks finish in minutes, so a full session is realistically **under ~$1**. Storage
(gp3 root) and the S3/DynamoDB state backend are pennies; SSM access is free.

Two layers of protection against surprise bills:

1. `terraform destroy` removes everything when you're done.
2. `auto_shutdown_hours` (default 4) tells the instance to power itself off after N hours,
   so even a forgotten box stops the compute charge on its own.

An idle GPU left running is ~$12.60/day — the whole point of doing this as code is that
"off" is as easy as "on." You can switch instance types via `instance_type` (e.g.
`p3.2xlarge` for a V100 at higher cost).

---

## Results

See [`docs/writeup.md`](docs/writeup.md) for the full narrative and analysis. Charts land
in [`results/`](results/) after you run `plot_results.py`.

---

## License

Released into the **public domain** under [The Unlicense](https://unlicense.org). No
restrictions, no attribution required — copy it, fork it, use it however you like. See
[`LICENSE`](LICENSE).
