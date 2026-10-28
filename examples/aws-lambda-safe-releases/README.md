# AWS Lambda safe releases: canary deployment with automatic rollback

A small, reproducible demonstration that a faulty Lambda release is **detected
and automatically rolled back** — not merely that a canary can be configured.

Terraform creates a Python Lambda, a published version behind a stable `live`
alias, a CodeDeploy Lambda deployment group, a CloudWatch error alarm, and a
minimal HTTP API. A deliberately faulty release is deployed at 10% traffic; the
alarm enters `ALARM`; CodeDeploy stops the deployment and shifts traffic back to
the previous healthy version automatically.

> **Scope boundary.** This example demonstrates Lambda release engineering. It
> does not demonstrate Step Functions, DynamoDB Streams, EventBridge, EKS or
> production-scale operation. See `docs/aws-lambda-safe-releases/` for the full
> brief and evidence rules.

## Architecture

```text
                 GitHub Actions (OIDC, no keys)
                            │
                            ▼
                    S3 artifact bucket
                            │
                            ▼
   HTTP API ──▶ Lambda alias "live" ──▶ version N   (90%)
                            └────────▶ version N+1  (10% canary)
                            │
                            ▼
                  CloudWatch alarm: Errors (count)
                            │  ALARM during deployment
                            ▼
              CodeDeploy auto-rollback → 100% previous healthy version
```

Terraform owns the function, alias **existence**, deployment group, alarm and
API. CodeDeploy owns the alias **routing** after creation. That split is why the
alias has a narrow `ignore_changes = [function_version, routing_config]`.

### Version semantics

This run publishes three versions:

| Version | Artifact | Where it ends up |
|---|---|---|
| **v1** | `baseline` | Created by Terraform; initial alias target |
| **v2** | `candidate-healthy` | Deployed to 100% by CodeDeploy |
| **v3** | `candidate-faulty` | 10% canary, then rolled back |

CodeDeploy rolls back to the version the alias pointed to **before** the faulty
deployment — here **v2**, not v1. Name exact versions in evidence and prose;
"baseline" refers only to v1.

## Prerequisites

- Terraform >= 1.5 and AWS credentials for a sandbox account.
- Python 3.11+ (standard library only; no boto3 required for tests). On WSL,
  use `python3` where the examples show `python`; the shell scripts resolve
  either automatically.
- AWS CLI v2 for deployment and evidence scripts.
- Bash (Git Bash or WSL on Windows).
- A budget alert. This example is cheap but not free.

## Reproduce

```bash
cd examples/aws-lambda-safe-releases

# 1. Build the baseline artifact (Terraform plans against this file).
python scripts/build.py baseline

# 2. Create the infrastructure.
terraform -chdir=infra init
cp infra/terraform.tfvars.example infra/terraform.tfvars   # edit region/OIDC if needed
terraform -chdir=infra apply

# 3. Capture the outputs you need for the scripts.
terraform -chdir=infra output
```

If the account already has a GitHub OIDC provider, set
`existing_oidc_provider_arn` in `terraform.tfvars`. The stack then references it
instead of creating one, so `terraform destroy` cannot remove shared
infrastructure.

## Run the experiment

```bash
export ARTIFACT_BUCKET="$(terraform -chdir=infra output -raw artifact_bucket)"
export AWS_REGION="eu-west-2"
export URL="$(terraform -chdir=infra output -raw api_url)"

# v1 baseline throughput sample.
python scripts/load.py --url "$URL" --seconds 60 --rate 10

# A healthy candidate (v2): goes to 100%, no rollback.
./scripts/deploy.sh healthy --wait
python scripts/load.py --url "$URL" --seconds 60 --rate 10

# A faulty candidate (v3): 10% canary, alarm, automatic rollback to v2.
./scripts/deploy.sh faulty
python scripts/load.py --url "$URL" --seconds 360 --rate 10 \
  --output evidence/raw/$(date -u +%Y%m%d-%H%M)/load.json
```

Watch three things, in order:

1. The alias routes ~10% to the new version.
2. `aws cloudwatch describe-alarms --alarm-names aws-lambda-safe-releases-live-errors`
   shows `ALARM` within roughly three minutes.
3. `aws deploy get-deployment --deployment-id <id>` shows the deployment stopped
   and rolled back; the alias returns to **v2**, the previous healthy version —
   not v1.

Expected timing is documented in `docs/aws-lambda-safe-releases/STATUS.md` §4 and
§7. Treat it as a target until the run confirms it.

## Abort and roll back by hand

If the alarm has not reached `ALARM` by `t0 + 5 min`, or anything looks wrong,
stop the deployment rather than waiting for the canary window:

```bash
export DEPLOYMENT_ID=d-XXXXXXXX
aws deploy stop-deployment --deployment-id "$DEPLOYMENT_ID" --auto-rollback-enabled
aws deploy get-deployment --deployment-id "$DEPLOYMENT_ID" \
  --query 'deploymentInfo.status' --output text
aws lambda get-alias --function-name aws-lambda-safe-releases --name live \
  --query 'FunctionVersion' --output text
```

Record the outcome in `STATUS.md`. Do not present a failed detection as a
successful run.

## GitHub Actions (optional)

The workflow deploys through OIDC, with no long-lived keys. After
`terraform apply`, set:

- **Secret** `AWS_DEPLOY_ROLE_ARN` = `terraform -chdir=infra output -raw deploy_role_arn`
- **Variables** `AWS_REGION`, `ARTIFACT_BUCKET`, `FUNCTION_NAME`, `ALIAS_NAME`,
  `CODEDEPLOY_APP`, `CODEDEPLOY_GROUP`

Then run **Actions → aws-lambda-safe-releases → Run workflow** and choose the
release. The role trust is scoped to `repo:<owner>/<repo>:ref:refs/heads/main`;
change `github_repo` and `github_branch` in `terraform.tfvars` if yours differ.

## Evidence

```bash
DEPLOYMENT_ID=d-XXXXXXXX ./scripts/collect-evidence.sh
```

Raw output lands in `evidence/raw/<run-id>/` and is gitignored. Redact account
IDs, ARNs, emails and tokens before copying anything into
`public/evidence/aws-lambda-safe-releases/`.

## Cost

Estimated at `eu-west-2` list prices — an estimate, not a billing export:

| Line | Estimate |
|---|---|
| Lambda (3,600 invocations, 128 MB, 200 ms) | ~$0.002 |
| HTTP API (3,600 requests) | ~$0.004 |
| CloudWatch Logs (~10 MB) | ~$0.005 |
| Two alarms, one day | ~$0.007 |
| S3 artifacts/state | <$0.01 |
| CodeDeploy for Lambda | $0 |
| **Per run** | **~$0.03** |

Three runs plus retries should stay under $0.20. The stack deliberately avoids
NAT gateways, provisioned concurrency, customer-managed KMS keys, Security Hub,
Config and X-Ray — each of which can cost more per day than this whole demo.

If retained, expect roughly **$0.50–2/month** from alarms and log storage.
Retention is a deliberate decision, not a default.

## Teardown

```bash
terraform -chdir=infra destroy
./scripts/verify-teardown.sh
```

`force_destroy` on the artifact bucket removes object versions. The script checks
Lambda, CodeDeploy, alarms, log groups, buckets and IAM roles. Tag discovery
supplements those checks; it does not prove that nothing survived.

## Design notes worth knowing

- **A Lambda CodeDeploy revision is the AppSpec, not the code zip.** `deploy.sh`
  publishes the target version with `update-function-code --publish`, then sends
  an `AppSpecContent` revision naming `CurrentVersion` and `TargetVersion`.
  CodeDeploy shifts traffic between published versions; it does not publish the
  version for you.
- **Returning `statusCode=500` does not increment Lambda `Errors`.** A returned
  response is a successful invocation. The faulty release raises an exception,
  which is what the alarm watches.
- **Use a count alarm, not a rate alarm.** A 10% canary with a 100%-failing
  candidate produces a ~10% alias error *rate*, not 100%. Counting errors avoids
  that dilution.
- **The alarm must fire inside the canary window.** `60s × 2` evaluation periods
  fits inside a 10-minute canary with roughly seven minutes of margin. A
  5-minute canary leaves too little headroom.
- **Configured weight is not observed weight.** Report both.

## What this does not cover

- Event-driven orchestration (API Gateway → DynamoDB Streams → Step Functions).
- EKS/Kubernetes operations.
- Multi-region or production-scale load.
- Measured billing (only dated billing data can support that claim).

## Licence

MIT, consistent with the parent repository.
