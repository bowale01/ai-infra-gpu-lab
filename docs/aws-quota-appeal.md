# AWS Service Quota Appeal — G/VT vCPU increase

> Paste the message below into the reopened AWS Support case (the same case that was
> denied — reopen it rather than filing a new request). If there is a "use case
> description" field, paste it there too.

---

Hello,

Thank you for the response. I'd like to reopen this case and provide a more detailed use case.

I am requesting a modest increase to **4 vCPUs** for On-Demand G and VT instances so I can launch a **single `g4dn.xlarge`** instance for a short-term, personal proof-of-concept project.

**Purpose:** I am building a portfolio project that benchmarks CPU vs GPU performance for machine learning (matrix multiplication and CNN training in PyTorch). It is a learning and demonstration exercise as I develop skills in AI infrastructure.

**Scope and duration:** I only need one small GPU instance, run interactively for testing, for approximately **1 hour total**. The instance will be **terminated as soon as the benchmark completes**.

**Cost controls already in place:** The environment is fully managed with Terraform, so it is torn down with a single `terraform destroy`. I have also configured an **automatic shutdown** on the instance that powers it off after a short period as a safety net, so there is no risk of an idle instance generating unexpected charges. Expected total cost is under $2.

I am only requesting the minimum 4 vCPUs needed for this single instance — not a large or scaling workload. I would appreciate it if you could re-assess this request.

Thank you.

---

## How to submit

1. Go to the AWS **Support Center** (or Service Quotas → the denied request).
2. Open the existing case that was denied and choose **Reopen** / **Reply**.
3. Paste the message above.
4. Submit and wait for the email reply.

## If denied again

- New accounts sometimes need a little billing history first. Running any small non-GPU
  instance for a day or two, or simply letting the account age, often helps.
- As a fallback, a GPU from Google Colab, Lambda, or Paperspace can stand in to capture
  the benchmark numbers — but exhaust the AWS appeal first since the project is built
  around AWS.
