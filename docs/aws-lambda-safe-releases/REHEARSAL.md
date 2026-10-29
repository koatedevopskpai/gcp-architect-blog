# Phase 2 rehearsal — AWS Lambda safe releases

Date: 2026-10-19
Commit under test: `3143309` (Freeze B), plus the Phase 2 tooling committed after this record
Spend: **none**
Region: `eu-west-2` (plan only; no resources created)

## Result

**PASS.** The artifacts, load generator, deploy flow (against a fake AWS CLI),
redaction path and teardown checks behave as specified. Two portability/tooling
gaps were found and fixed.

## Checks

| # | Check | Command | Result |
|---|---|---|---|
| 1 | Handler tests | `python -m pytest tests -q` | 4 passed |
| 2 | Terraform format/validate | `terraform fmt -check -recursive`, `validate` | clean |
| 3 | Plan | `terraform plan` | 23 to add, region `eu-west-2` |
| 4 | Artifacts | `python scripts/rehearse.py` | 19/19 checks passed |
| 5 | Load generator | local HTTP server via `rehearse.py` | 200s counted, version marker seen, zero errors |
| 6 | Deploy flow | `bash build/rehearse-deploy.sh` (fake `aws`) | current 2, target 4, canary config, AppSpec `2 → 4` |
| 7 | Redaction | `scripts/redact-evidence.py` on a sample | account, ARN, email and access key replaced; PNG skipped |
| 8 | Evidence paths | `git check-ignore` | `evidence/raw/` and `build/` ignored |
| 9 | Budget visibility | `aws budgets describe-notifications-for-budget` | existing budgets have 50/85/100% notifications |
| 10 | Stop command | `aws deploy stop-deployment help` | `--auto-rollback-enabled` available |
| 11 | Site build | `npm run build` | 53 pages, new post route present |
| 12 | Teardown verifier (pre-deploy) | `bash scripts/verify-teardown.sh` | all sections empty — clean slate |

## Findings fixed during rehearsal

**R1 — `python` is not on `PATH` in WSL.** `deploy.sh` called `python`; this WSL
environment provides `python3`. Fixed by resolving `python`, `python3` or
`python.exe`, with a `PYTHON_BIN` override. This also removes a latent CI risk.

**R2 — no redaction tooling.** The plan required a redaction step, but no script
existed. Added `scripts/redact-evidence.py`: it copies text artifacts with
account/ARN/email/access-key substitutions and refuses to copy images, listing
them for manual review in `REDACTION_REPORT.md`.

**R3 — WSL bash could not see the AWS CLI.** The scripts called `aws`; this WSL
environment exposes `aws.exe` only. Fixed with `scripts/common.sh`, which
resolves `aws`/`aws.exe` and `python`/`python3`/`python.exe` to absolute paths.
(The first attempt returned the bare command name and the new `aws()` wrapper
called itself recursively; the rehearsal caught that immediately.) `AWS_BIN` and
`PYTHON_BIN` remain available as overrides.

None of these changes alter experiment mechanics. The alarm, canary configuration,
fault, alias ownership and IAM boundaries are unchanged. A delta review of
`deploy.sh` and `common.sh` is recommended but not blocking.

## Numbers re-checked against code

| Claim | Code | Match |
|---|---|---|
| Alarm 60 s × 2, threshold 1, `notBreaching` | `variables.tf` defaults + `main.tf` | yes |
| Canary 10% for 10 minutes | `CodeDeployDefault.LambdaCanary10Percent10Minutes` | yes |
| Load 10 req/s × 360 s, max 5,000 | `load.py` defaults | yes |
| Sequential load (concurrency 1) | single rate-paced loop | yes |
| Rollback target is v2, not v1 | docs and AppSpec flow | yes |
| Cost ~$0.03 per run | 3,600 × 0.125 GB × 0.2 s etc. | yes (conservative) |

## Before the live run

- [ ] User approves this runbook and is present for the run.
- [ ] Confirm no resources are tagged `Project=aws-lambda-safe-releases`.
- [ ] Deploy commit recorded (Freeze B / B2) and the working tree clean.
- [x] Tag-scoped USD 5 budget active (`aws-lambda-safe-releases-demo`), filtered to `user:Project$aws-lambda-safe-releases`, alerts at 20/50/80/100%; `Project` activated as a cost-allocation tag (cost data can lag 24h).

## Run log — live run 2026-10-20

| Field | Value |
|---|---|
| Run ID | `20261020-0251` |
| Stack apply | 23 resources, then +1 CodeDeploy S3 policy and +1 budget |
| v1 / v2 / v3 | v1 `baseline`; v2 `candidate-healthy`; v3 `candidate-faulty` |
| Healthy deployment | `d-8YABO1E6K` — Succeeded |
| Faulty deployment | `d-9PAMKTD6K` — 10% canary to v3 |
| Alarm fired | `2026-10-20T03:11:51+01:00` (`ALARM`) |
| Rollback triggered | Deployment `completeTime` `2026-10-20T03:11:57+01:00` (poll observed `03:12:18`) — `Stopped`, rollback `d-YGITAAD6K` Succeeded |
| Recovery | alias `live` back at v2, no additional weights; alarm returned to `OK` |
| Load result | 3,601 requests: 3,479 × 200 (`candidate-healthy`), 120 × 500, 2 × 429 |
| Observed canary effect | ~3.3% failures across the whole 6-minute load; the 10% canary was active for only part of it |
| Post-rollback plan | `No changes. Your infrastructure matches the configuration.` |
| Teardown | 25 resources destroyed; budget restored; all teardown sections empty |

## Live-run findings (L1–L10)

| # | Severity | Finding | Disposition |
|---|---|---|---|
| L1 | High | For Lambda, a CodeDeploy **revision is the AppSpec**, not the code zip. The target Lambda version must be published first. | **Fixed** — `deploy.sh` publishes via `update-function-code --publish`, then sends an `AppSpecContent` revision. The article must explain this. |
| L2 | Medium | Windows CLI output added `\r`, producing `CurrentVersion: "1\r"` in the AppSpec. | **Fixed** — `tr -d '\r'` on captured values. |
| L3 | Medium | `AWSCodeDeployRoleForLambda` alone did not grant S3 read on the artifact bucket (`IAM_ROLE_PERMISSIONS`). | **Fixed** — inline role policy for `s3:GetObject`, `GetObjectVersion`, `ListBucket`, `GetBucketLocation`. |
| L4 | Medium | WSL did not inherit `ARTIFACT_BUCKET` and other PowerShell env vars. | **Fixed** — explicit `VAR='value'` on each `bash -c` call. |
| L5 | Medium | Windows `aws.exe` could not read the WSL artifact path `/mnt/c/...`. | **Fixed** — `wslpath -w` / `cygpath -w` conversion. |
| L6 | Low | PowerShell 5.1 treated native stderr as terminating under `$ErrorActionPreference = "Stop"`. | **Fixed** — `Invoke-CheckedBash` / `Invoke-CheckedTerraform` capture stderr and check exit codes. |
| L7 | Low | Parsing `deployment_id` from a multi-line string with `-split` returned the wrong token. | **Fixed** — regex extraction. |
| L8 | Medium | Rollback polling checked `FunctionVersion`, which stays at the base version during a canary. | **Fixed** — poll for `Stopped`/`Failed` plus cleared weights. |
| L9 | Low | `powershell -File show-stage.ps1 -Url ""` drops the empty argument. | **Workaround** — omit `-Url` for prompts that need no console page. |
| L10 | Info | 2 × 429 from API Gateway during the load at 10 req/s (limit 20 rps / burst 50). | **Accepted** — burst artefact; the failing candidate still produced the expected 500s. |

The live run was resumed manually after L1/L3 fixes; the automated script's Stage 2 parsing and Stage 5 rollback check were corrected afterwards. A fresh end-to-end run should be done before publishing the article.
