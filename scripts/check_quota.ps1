# check_quota.ps1 - is the GPU (G/VT) vCPU quota approved yet?
#
# Usage:
#   ./scripts/check_quota.ps1
#
# The G and VT On-Demand vCPU quota is 0 on new accounts. We requested 4 (enough for one
# g4dn.xlarge). This tells you whether AWS has granted it yet.
#
#   Effective quota 4.0  -> APPROVED, safe to `terraform apply` the GPU instance.
#   Effective quota 0.0  -> still pending; the request status shows CASE_OPENED / PENDING.

param(
    [string]$Region   = "us-east-1",
    [string]$QuotaCode = "L-DB2E81BA"  # Running On-Demand G and VT instances
)

Write-Host "Region: $Region  |  Quota: Running On-Demand G and VT instances" -ForegroundColor Cyan

$effective = aws service-quotas get-service-quota `
    --service-code ec2 --quota-code $QuotaCode --region $Region `
    --query "Quota.Value" --output text

$status = aws service-quotas list-requested-service-quota-change-history `
    --service-code ec2 --region $Region `
    --query "RequestedQuotas[?QuotaCode=='$QuotaCode'] | [0].Status" --output text

Write-Host ""
Write-Host ("Effective vCPU quota : {0}" -f $effective)
Write-Host ("Last request status  : {0}" -f $status)
Write-Host ""

if ([double]$effective -ge 4) {
    Write-Host "APPROVED - you can deploy the GPU instance now." -ForegroundColor Green
} else {
    Write-Host "Still pending. Re-run this later, or watch for the AWS email." -ForegroundColor Yellow
}
