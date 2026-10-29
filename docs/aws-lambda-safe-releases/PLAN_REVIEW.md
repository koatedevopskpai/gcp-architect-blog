# Gate 1 review packet — AWS Lambda safe releases

Review target: commit `8b2c2a1`
Plan generated: 2026-10-19
Region: `eu-west-2`
Terraform: `1.15.4` · provider: `hashicorp/aws 5.100.0`
Plan result: **23 to add, 0 to change, 0 to destroy**

No resources applied. No spend. This packet is redacted: account identifiers are
replaced with `<account>`.

> **Post-review addition:** a tag-scoped USD 5/month budget was added as a
> guardrail and created separately from the experiment resources. It does not
> change the alarm, canary, fault or IAM mechanics reviewed at Gate 1.

---

## What to review

The frozen diff at `8b2c2a1` plus the resource inventory below. Findings go in
`STATUS.md` §12 (or a separate `REVIEW_FINDINGS.md`) with severity and file
references. Do not edit implementation files during review.

Priority questions are in §4.

---

## 1. Resource inventory

| # | Resource | Key settings |
|---|---|---|
| 1 | `aws_lambda_function.app` | `python3.12`, 128 MB, 5 s, `publish = true`, handler `handler.handler` |
| 2 | `aws_lambda_alias.live` | Alias `live`, `ignore_changes = [function_version, routing_config]` |
| 3 | `aws_cloudwatch_metric_alarm.errors` | `Errors`, `Sum`, 60 s, 2 evaluation periods, 2 datapoints, threshold 1, `notBreaching` |
| 4 | `aws_codedeploy_app.app` | `compute_platform = "Lambda"` |
| 5 | `aws_codedeploy_deployment_group.app` | `LambdaCanary10Percent10Minutes`, `WITH_TRAFFIC_CONTROL`, `BLUE_GREEN`, alarm attached, auto-rollback on `DEPLOYMENT_FAILURE` + `DEPLOYMENT_STOP_ON_ALARM` |
| 6 | `aws_apigatewayv2_api.api` | HTTP API |
| 7 | `aws_apigatewayv2_integration.lambda` | `AWS_PROXY`, payload v2.0, targets the alias |
| 8 | `aws_apigatewayv2_route.get_root` | `GET /` |
| 9 | `aws_apigatewayv2_stage.default` | `$default`, throttle 20 rps / burst 50 |
| 10 | `aws_lambda_permission.apigw` | Scoped to API execution ARN, qualifier `live` |
| 11 | `aws_cloudwatch_log_group.lambda` | `/aws/lambda/<fn>`, 7-day retention |
| 12 | `aws_iam_role.lambda` | Runtime role, `permissions_boundary` attached |
| 13 | `aws_iam_policy.lambda_boundary` | Allows only `logs:CreateLogStream` + `logs:PutLogEvents` on the log group |
| 14 | `aws_iam_role_policy.lambda_logs` | Same logs-only permissions as identity policy |
| 15 | `aws_iam_role.codedeploy` | Trusts `codedeploy.amazonaws.com`; `AWSCodeDeployRoleForLambda` attached |
| 16 | `aws_iam_role.deploy` | Trusts the existing GitHub OIDC provider; `sub` scoped to `repo:koatedevopskpai/gcp-architect-blog:ref:refs/heads/main` |
| 17 | `aws_iam_role_policy.deploy` | S3 artifact RW, CodeDeploy in account/region, Lambda read, `iam:PassRole` scoped to the CodeDeploy role |
| 18 | `aws_s3_bucket.artifacts` | `<project>-<env>-<account>`, `force_destroy = true` |
| 19–23 | S3 versioning, public-access block, SSE-S3, lifecycle | 30-day expiry, 7-day noncurrent expiry |

Data sources: `aws_caller_identity`, `aws_region`, two IAM policy documents. The
GitHub OIDC provider is **reused**, not created (`count = 0`).

---

## 2. Alarm and canary arithmetic

- Time to `ALARM`: `period 60 s × datapoints_to_alarm 2 = 120 s`, plus up to one
  period of metric lag → **≤ ~3 min** after the first failing candidate request.
- Canary window: **10 min** → **~7 min margin** for CodeDeploy to detect and roll
  back. A 5-minute canary would leave ~2 min and is not used.
- Fault: the candidate artifact raises `RuntimeError` on every invocation, so
  Lambda `Errors` increments. Returning `statusCode=500` would not.
- Why a **count** alarm: CodeDeploy publishes the candidate version, so Terraform
  cannot dimension the alarm on `ExecutedVersion`; the alias aggregate is the
  stable target. A count alarm avoids the 10% canary dilution that would hide a
  failing candidate from a rate alarm.

---

## 3. Deploy flow

1. `scripts/build.py <release>` writes `handler.py`, `release.json` and
   `appspec.yaml` into `build/<release>.zip`.
2. `scripts/deploy.sh` reads the alias's current version, computes the target as
   `max(published versions) + 1`, rebuilds the artifact with those values, uploads
   it to S3, and calls `aws deploy create-deployment` with the S3 revision.
3. CodeDeploy reads `appspec.yaml` from the zip root, publishes the target
   version, shifts 10%, watches the alarm, and rolls back on `ALARM` to the
   version the alias pointed to before the deployment (v2 in this run, not v1).

`release.json` makes each published version self-describing:
`baseline` / `candidate-healthy` / `candidate-faulty` plus `fail_mode`.

---

## 4. Questions for the reviewer

1. **Alias ownership.** Is `ignore_changes = [function_version, routing_config]`
   on the alias, plus `[filename, source_code_hash]` on the function, sufficient
   to keep a post-rollback `terraform plan` clean? Is anything else likely to
   drift?
2. **Alarm dimensions.** Does `Resource = <fn>:live` capture alias traffic as
   intended, and does `treat_missing_data = notBreaching` avoid CodeDeploy
   failing on `INSUFFICIENT_DATA` at deployment start?
3. **Canary vs alarm timing.** Is 60 s × 2 inside a 10-minute canary with enough
   margin, or should the period/evaluation be tightened?
4. **AppSpec target version.** `deploy.sh` predicts `max + 1`. Is that acceptable
   for a single-writer demo, and what is the failure mode if a publish races it?
5. **IAM.** Is the boundary meaningful (logs only), are runtime and deployment
   roles separated, and is `iam:PassRole` scoped correctly?
6. **OIDC.** Is reusing the existing provider with a `sub`-scoped trust policy
   safe, and does `destroy` avoid touching shared infrastructure?
7. **Teardown.** Does `force_destroy` remove versioned objects? Are Lambda
   versions, CodeDeploy resources, alarms, log groups and the deploy role all
   covered?
8. **Claims.** Does anything in the README or Terraform imply Step Functions,
   DynamoDB Streams, EKS or production scale?

---

## 5. Known deviations and accepted risks

| Item | Decision | Rationale |
|---|---|---|
| Dedicated USD 5 budget | **Deferred** | Two account budgets exist; an account-wide $5 limit would fire on unrelated spend, and a tag-scoped budget needs cost-allocation tag activation (up to 24h). Run 1 relies on the existing budgets, the ~$0.03 estimate and immediate teardown. |
| Local Terraform state | Accepted | Reproducible example; remote state is documented as the production pattern. |
| Target version by `max + 1` | Accepted | Single-writer demo; a concurrent publish would fail the deployment, not corrupt traffic. |
| No `ExecutedVersion` alarm | Accepted | Version is unknown at plan time; count alarm avoids dilution. |

---

## 6. Local checks already run

```
python -m pytest examples/aws-lambda-safe-releases/tests -q   # 4 passed
terraform -chdir=.../infra fmt -check -recursive             # clean
terraform -chdir=.../infra validate                          # success
terraform -chdir=.../infra plan                              # 23 to add
```

Two defects were caught during implementation and fixed before freeze:

1. The AWS provider was not pinned to `var.aws_region`; the plan resolved
   `data.aws_region.current` to `us-east-1`. Fixed with an explicit `provider` block.
2. The Lambda AppSpec omitted the required `CurrentVersion` / `TargetVersion`.
   Fixed after checking the CodeDeploy AppSpec reference; `deploy.sh` now computes
   both.
