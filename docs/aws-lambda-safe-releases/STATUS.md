# AWS Lambda safe releases — status and run parameters

Last updated: 2026-10-19
Status: **Phase 0 complete; Phase 1 implemented — local checks pass, awaiting Gate 1**
Canonical brief: `IMPLEMENTATION_BRIEF.md`
Implementation sequence: `IMPLEMENTATION_PLAN.md`
Owners: implementation — OpenCode · Gate 1 plan review — independent reviewer · Gate 2 evidence review — independent reviewer · evidence capture — Codex or user · go/no-go — user

This file is the single source of truth for scope decisions, pre-computed run parameters and progress. Update it before and after every live run. Do not record live results here until they exist.

---

## 0. Phase status

| Phase | Status | Notes |
|---|---|---|
| 0 — Preflight | **complete** | Existing sandbox account; `eu-west-2`; existing GitHub OIDC provider reused; local state |
| 1 — Local implementation | **complete** | 4 handler tests pass; `terraform validate` clean; plan: 23 to add |
| Gate 1 — Plan review | **passed** | Reviewer verdict PASS; F1–F7 dispositioned in §12; Freeze B `3143309` |
| 2 — Pre-run rehearsal | **complete** | `REHEARSAL.md`; no spend; two portability/tooling gaps fixed |
| 3 — Live run | **complete 2026-10-20** | Faulty v3 rolled back to v2; evidence in `evidence/raw/20261020-0251`; findings L1–L10 |
| 4 — Evidence freeze + Gate 2 | **next** | Redact and review evidence; article next |
| 5 — Article and distribution | not started | — |
| 6 — Publish and close | not started | — |

### Live run result — 2026-10-20

Run `20261020-0251` completed. v1 baseline → v2 healthy (deployment
`d-8YABO1E6K`) → v3 faulty canary (`d-9PAMKTD6K`). The alarm fired at
`03:11:51`; the faulty deployment reached `Stopped` at `03:11:57` (artifact
`completeTime`; poll observed at `03:12:18`) and rolled back via `d-YGITAAD6K`.
The alias returned to v2; the load produced 3,479 × 200 vs 120 × 500; the alarm
returned to `OK`; the post-rollback `terraform plan` was clean. Teardown
destroyed 25 resources and restored the tag-scoped budget.

Evidence: `evidence/raw/20261020-0251/` (gitignored). **Screenshots:** the eight
raw PNGs in this folder are untracked; the independent review found 01–03 and
05–07 invalid (permissions/URL), 04 usable after redaction and 08 partial. See
`SCREENSHOT_COORDINATION.md`; do not publish the current set as a full rollback
narrative. Findings and dispositions: `REHEARSAL.md` §Live-run findings (L1–L10).
A fresh end-to-end run is still recommended before publishing the article,
because the live run was resumed manually after the CodeDeploy revision-model
correction.

---

## 1. Scope decisions (resolved 2026-10-19)

| Decision | Resolution | Rationale |
|---|---|---|
| Experiment size | One service, one faulty release, one rollback | Ships; broad scope stalls |
| Step Functions / DynamoDB Streams / EventBridge | **Out of scope** — tracked separately | Keeps this artefact defensible; must not be implied in the article |
| EKS / Kubernetes | **Out of scope** — separate gap | Lambda release operations do not evidence EKS |
| HTTP API | **In scope, minimal** | Makes the weighted traffic split externally visible |
| GitHub Actions OIDC deploy | **In scope** | Directly evidences the OIDC identity pattern; no long-lived keys |
| Permission boundary on execution role | **In scope** | Directly evidences least-privilege IAM |
| Successful candidate deployment | **In scope** | A failure-only demo reads as "cannot ship" |
| Region | **`eu-west-2`** | UK relevance and consistency with `ai-platform-proof`; the cost difference is negligible |
| Terraform state | **Local, gitignored** for the example | Reproducible for readers, no shared infrastructure to own; production note in the README |
| GitHub OIDC provider | **Reuse the existing provider** (the account already has one) | One per issuer per account; referenced rather than owned, so `destroy` cannot remove shared infrastructure |
| Retention after run | **Destroy**, with scripts to re-create on demand | Matches the blog's "destroyed same day" FinOps narrative; a live URL cannot re-demonstrate rollback |

### Claim boundaries for the article

**May claim:** a faulty Lambda release was detected by a CloudWatch alarm and automatically rolled back by CodeDeploy, with measured intervals and a bounded sample.

**Must not claim:** production-scale operation, commercial client delivery, EKS experience, event-driven orchestration, or measured billing unless dated billing data exists.

---

## 2. Environment

| Item | Value |
|---|---|
| AWS account | Existing sandbox account (ID recorded privately in `infra/terraform.tfvars`, gitignored) |
| Region | `eu-west-2` |
| Terraform state | Local, gitignored (`infra/terraform.tfstate`) — remote state is a production note, not a demo dependency |
| Run ID | `<YYYYMMDD-HHMM>-<short-sha>` |
| Source commit | `<sha>` |
| Terraform / provider versions | `1.15.4` / `hashicorp/aws 5.100.0` |
| Freeze A | `8b2c2a1` (2026-10-19) — implementation commit reviewed at Gate 1 |
| Freeze B | `3143309` (2026-10-19) — Gate 1 fixes |
| Freeze B2 | `3ec44d6` (2026-10-19) — Phase 2 tooling and portability fix |
| Freeze B3 | `bfb87e6` (2026-10-19) — cross-shell CLI resolution; **deploy commit** (no experiment-mechanics change) |
| Freeze B4 | `6054ec7` (2026-10-19) — tag-scoped budget and screenshot orchestration; no experiment-mechanics change |
| Freeze C | `9fc41bf` (2026-10-20) — post-live-run correctness fixes; evidence `20261020-0251` frozen |
| Freeze C+ | `124545a` (2026-10-20) — code artifact separated from AppSpec; no behaviour change |

**Pre-flight checks**

- [x] AWS identity confirmed (`aws sts get-caller-identity`); account recorded privately, not in this file.
- [x] Shared GitHub OIDC provider exists for `token.actions.githubusercontent.com` — reused via `existing_oidc_provider_arn`; it is not owned by this stack.
- [x] Terraform state decision: local and gitignored for the example.
- [x] Tag-scoped budget `aws-lambda-safe-releases-demo` (USD 5/month; filter `user:Project$aws-lambda-safe-releases`; alerts at 20/50/80/100% to the configured email). `Project` is now an active cost-allocation tag. Cost data can lag up to 24h, so this is a retained guardrail, not an instantaneous cap.
- [x] No existing resources use the `Project=aws-lambda-safe-releases` tag.

---

## 3. Alias ownership contract

Terraform and CodeDeploy both want to control the alias. Resolve it explicitly:

| Owner | Controls |
|---|---|
| **Terraform** | `aws_lambda_function` (`publish = true`), the alias **resource's existence**, name, description, initial `function_version` |
| **CodeDeploy** | The alias `function_version` and `routing_config` **after creation** |

Required Terraform setting:

```hcl
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.app.function_name
  function_version = aws_lambda_function.app.version

  lifecycle {
    # CodeDeploy owns routing after creation. Keep this list narrow and documented.
    ignore_changes = [function_version, routing_config]
  }
}
```

**Gate:** after the rollback, a follow-up `terraform plan` must show **no alias diff**. Record the plan output (redacted) as evidence. If a diff appears, the ownership contract is wrong — do not paper over it with a broader `ignore_changes`.

Deployment group settings to verify in the plan:

- `deployment_style { deployment_option = "WITH_TRAFFIC_CONTROL" }`
- `deployment_config_name = "CodeDeployDefault.LambdaCanary10Percent10Minutes"`
- `auto_rollback_configuration { enabled = true, events = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"] }`
- `alarm_configuration { enabled = true, alarms = [aws_cloudwatch_metric_alarm.errors.alarm_name] }`
- CodeDeploy service role trusts `codedeploy.amazonaws.com` and carries `AWSCodeDeployRoleForLambda`.

---

## 4. Alarm design and timing arithmetic

**Metric choice:** Lambda `Errors`, **count** (Sum), dimensioned on `FunctionName` + `Resource = <function>:live`.

**Why a count alarm, not a percentage:** CodeDeploy publishes the candidate version at deployment time, so Terraform cannot pre-know the version number and cannot dimension an alarm on `ExecutedVersion`. The alias aggregate is therefore the only stable target. A count alarm is immune to the dilution that affects a percentage alarm.

**Dilution, stated explicitly:** with a 10% canary and a 100%-failing candidate, the alias error *rate* is ~10%, not 100%. A rate alarm would need a threshold below 10%. We avoid the issue by alerting on count.

| Parameter | Value | Why |
|---|---|---|
| `metric_name` | `Errors` | Invocation failures, not returned 500s |
| `namespace` | `AWS/Lambda` | — |
| `statistic` | `Sum` | Count of errors |
| `period` | `60` s | Fast enough to fire inside the canary |
| `evaluation_periods` | `2` | Avoids a single-blip page |
| `datapoints_to_alarm` | `2` | Both periods must breach |
| `threshold` | `1` | Any error in two consecutive minutes |
| `comparison_operator` | `GreaterThanOrEqualToThreshold` | — |
| `treat_missing_data` | `notBreaching` | No traffic must not fabricate an alarm |
| `alarm_actions` | none (or SNS for visibility) | CodeDeploy observes state; no pager needed |

**Time to ALARM:** `period × datapoints_to_alarm = 120 s`, plus up to one period of metric lag → **expect ALARM within ~3 minutes of the first failing candidate request.**

**Canary window:** 10 minutes. Margin after alarm: **~7 minutes** for CodeDeploy to detect and roll back. This is the headroom the 5-minute canary does not give.

**If the alarm has not reached ALARM by `t0 + 5 min`:** stop the deployment manually with `--auto-rollback-enabled`, record the detection failure honestly, and do not retitle the run as a success.

---

## 5. Load plan and sample arithmetic

| Parameter | Value |
|---|---|
| Request rate | 10 req/s (600/min) |
| Duration | 6 min |
| Total requests | 3,600 (hard cap 5,000) |
| Concurrency | 1 — sequential, rate-paced loop (no thread pool) |
| Run bound | `--seconds` (360 s) plus `--max-requests` 5,000; no separate wall-clock timeout |
| Candidate share (configured) | 10% |
| Expected candidate requests | ~360 |
| Expected non-candidate requests | ~3,240 |
| Candidate failure rate | 100% (deterministic) |
| Expected errors | ~360 |
| Expected errors/min | ~60 |

**Check:** 60 errors/min against a threshold of 1 error in 2 consecutive 60 s periods → ALARM at the first opportunity, with large margin. Sample size is not the constraint; timing is.

**Do not report configured weight as observed distribution.** Record the observed request counts per version from the load script and report both.

---

## 6. Fault injection

- Deterministic, not random: the candidate artifact is built with `release.json` = `{"label":"candidate-faulty","fail_mode":"always"}`, so every candidate invocation raises an unhandled exception.
- Each response carries a `version` marker sourced from the deployed version, so v1/v2 and candidate responses are distinguishable in the evidence.
- **Do not** return `statusCode=500` from the handler and expect Lambda `Errors` to move. A returned response is a successful invocation. Use an exception, or alarm on API Gateway `5xx`/`5XXError` instead.
- v1 and v2 must be error-free for the duration of the run; verify before shifting any traffic.

---

## 7. Expected timeline (targets, not claims)

**Version semantics (Gate 1 F1).** v1 = `baseline` (created by Terraform). v2 = `candidate-healthy` (deployed to 100%). v3 = `candidate-faulty` (10% canary, rolled back). The rollback target is **v2** — the version the alias pointed to before the faulty deployment — **not v1**. Name exact versions in evidence and prose.

| Stage | Target | Notes |
|---|---|---|
| `t0` deployment starts; 10% shift | 0:00 | Record UTC |
| First candidate failure | ~0:15 | Confirm in logs |
| Alarm enters `ALARM` | ≤ 3:00 | 2 × 60 s + metric lag |
| CodeDeploy begins rollback | ≤ 4:00 | Alarm attached to deployment group |
| Alias restored to previous healthy version (v2) | ≤ 5:00 | Verify alias config |
| Recovery verified under load | ≤ 6:00 | v2 responses succeed |
| Canary window would have ended | 10:00 | 7 min margin used or unused |

**Intervals to report (they are different quantities):**

1. failure start → detection
2. detection → rollback initiated
3. rollback initiated → rollback complete
4. failure start → verified recovery

Report actual measured values, sample size, and polling precision. Do not collapse them into "the incident lasted N minutes".

---

## 8. Cost estimate (planning, not measured billing)

| Line | Arithmetic | Estimate |
|---|---|---|
| Lambda execution | 3,600 × 0.125 GB × 0.2 s = 90 GB-s × $0.0000166667 | ~$0.0015 |
| Lambda requests | 3,600 × $0.20/1M | ~$0.0007 |
| HTTP API | 3,600 × $1.00/1M | ~$0.0036 |
| CloudWatch Logs | ~10 MB ingest | ~$0.005 |
| CloudWatch alarms | 2 × $0.10/month × 1/30 | ~$0.007 |
| S3 artifacts/state | a few MB | <$0.01 |
| CodeDeploy (Lambda) | — | $0 |
| **Per run** | | **~$0.03** |

Three runs plus retries: **< $0.20**. Approved testing allowance: **$2–5**. These are `eu-west-2` list-price estimates, **not** a billing export; label them as such in the article.

**Guardrail:** a tag-scoped USD 5/month budget (`aws-lambda-safe-releases-demo`) is active, filtered to `user:Project$aws-lambda-safe-releases`, with alerts at 20/50/80/100%. `Project` is an active cost-allocation tag. Cost data can lag up to 24h, so the budget protects retained resources and future runs rather than acting as an instantaneous cap.

**Actual spend:** the budget's `CalculatedSpend` read $0.00 immediately after the run (cost data lag). Check AWS Billing after 24h before writing any "measured spend" sentence; until then, the ~$0.03 figure is an estimate.

If retained at low traffic: **$0.50–2/month** (alarms, log storage, DynamoDB-free stack). Retention is a separate user decision.

---

## 9. Evidence checklist

- [ ] Source commit, run ID, region, UTC timeline.
- [ ] Terraform and provider versions.
- [ ] Baseline version and healthy response under load.
- [ ] Successful candidate deployment to 100% (version marker visible).
- [ ] Faulty candidate published; CodeDeploy deployment ID.
- [ ] Alias traffic split during canary (configured **and** observed).
- [ ] Alarm `ALARM` state with metric, dimensions and time window.
- [ ] CodeDeploy rollback event/status linked to the failed deployment.
- [ ] Alias restored to the previous healthy version (v2); post-rollback success under load.
- [ ] Follow-up `terraform plan` showing no alias drift.
- [ ] Teardown inventory (or documented retention).
- [ ] Redaction pass: no account IDs, ARNs containing account IDs, emails, or tokens.

Screenshots document visible state; deployment events and request logs establish causality. Neither alone proves implementation, billing, or complete cleanup.

---

## 10. Teardown checklist

- [ ] `terraform destroy` (or targeted destroys in dependency order).
- [ ] Lambda function deleted (versions and alias go with it).
- [ ] CodeDeploy application and deployment group deleted.
- [ ] CloudWatch alarms deleted; log group deleted (or retention set and retention documented).
- [ ] HTTP API, stage, integration and Lambda permission deleted.
- [ ] S3 artifact bucket: **delete all object versions and delete markers**, then the bucket.
- [ ] IAM: execution role, permissions-boundary policy, deployment role. **Do not delete a shared OIDC provider.**
- [ ] Verify with `aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=aws-lambda-safe-releases --region <region>`.
- [ ] Service-specific sweep: `aws lambda list-functions`, `aws deploy list-applications`, `aws cloudwatch describe-alarms`, `aws logs describe-log-groups`.
- [ ] Note: tag-based discovery supplements service inventory; it does not prove nothing survived.

---

## 11. Blockers and open questions

| # | Question | Owner | Status |
|---|---|---|---|
| 1 | Account and region | user | **resolved** — existing sandbox account, `eu-west-2` |
| 2 | Shared OIDC provider exists? | user | **resolved** — exists; reused, not owned |
| 3 | Shared Terraform state backend? | user | **resolved** — local, gitignored for the example |
| 4 | Deploy path: local Terraform or GitHub Actions OIDC? | user | **resolved** — local scripts plus a GitHub Actions OIDC deploy role |
| 5 | Retain live demo or destroy? | user | **resolved** — destroy; scripts recreate on demand |
| 6 | Backlog/scorecard reconciliation before new post ID | user | **resolved 2026-10-19** — backlog reconciled (7 published, 1 merged, 13 planned); duplicate `003` renumbered to `004` with a Firebase redirect; `new:post` now guards duplicate IDs; scorecard regenerated |
| 7 | Console sign-in for `FranklinWhyte` | user | **resolved 2026-10-20** — signed in; live run completed |
| 8 | Valid screenshot set | user/Codex | **open** — 01–03 and 05–07 invalid, 04 usable after redaction, 08 partial; see `SCREENSHOT_COORDINATION.md` |

---

## 12. Review findings log

| Date | Reviewer | Severity | Finding | Disposition |
|---|---|---|---|---|
| 2026-10-19 | Gate 1 (independent) | Medium | F1: "baseline" conflates v1 with the rollback target (v2) | **Fixed** — README, STATUS §7, plan and brief now name exact versions; v1/v2/v3 semantics recorded |
| 2026-10-19 | Gate 1 | Low | F2: load generator is sequential; docs claimed concurrency 10 | **Fixed** — docs now state sequential, concurrency 1 |
| 2026-10-19 | Gate 1 | Low | F3: STATUS §3 referenced `candidate_errors` | **Fixed** — now `errors` |
| 2026-10-19 | Gate 1 | Low | F4: CodeDeploy IAM scoped to account/region `*` | **Fixed** — scoped to the app, deployment group, two configs and `deployment:*` |
| 2026-10-19 | Gate 1 | Low | F5: teardown script omitted HTTP API and boundary policy | **Fixed** — both checks added |
| 2026-10-19 | Gate 1 | Info | F6: no 10-minute wall-clock timeout in `load.py` | **Accepted** — `--seconds` and `--max-requests` are the bounds; docs corrected |
| 2026-10-19 | Gate 1 | Info | F7: `iam:PassRole` unused by the current flow | **Fixed** — removed from the deploy role; Terraform passes the CodeDeploy role at deployment-group creation |
| 2026-10-19 | Phase 2 rehearsal | Low | R1: shell scripts assumed `python`; WSL provides `python3` | **Fixed** — `deploy.sh` resolves `python`/`python3`/`python.exe`, or honours `PYTHON_BIN` |
| 2026-10-19 | Phase 2 rehearsal | Low | R2: plan required a redaction step but no tooling existed | **Fixed** — `scripts/redact-evidence.py` added and tested; images are skipped for manual review |
| 2026-10-19 | Phase 2 rehearsal | Low | R3: WSL bash exposes `aws.exe`, not `aws`; scripts called `aws` | **Fixed** — `scripts/common.sh` resolves `aws`/`aws.exe` and `python`/`python3` to absolute paths; `AWS_BIN`/`PYTHON_BIN` overrides |
| 2026-10-20 | Phase 3 live run | High | L1: Lambda CodeDeploy revision is the AppSpec, not the code zip; target version must be published first | **Fixed** — `deploy.sh` publishes with `update-function-code --publish`, then sends `AppSpecContent` |
| 2026-10-20 | Phase 3 live run | Medium | L2/L3/L4/L5/L8: CRLF in AppSpec; missing CodeDeploy S3 read; WSL env not inherited; `/mnt/c` path rejected by `aws.exe`; rollback poll checked the wrong field | **Fixed** — CRLF stripping, inline S3 policy, explicit bash env, `wslpath`, status+weights check |
| 2026-10-20 | Phase 3 live run | Low | L6/L7/L9: native stderr terminating; multi-line ID parsing; empty `-Url` dropped by `powershell -File` | **Fixed/workaround** — checked native helpers, regex parsing, omit empty `-Url` |
| 2026-10-20 | Phase 3 live run | Info | L10: 2 × 429 at 10 req/s | **Accepted** — burst artefact; the fault still produced the expected errors |

---

## 13. Definition of done (this run)

- [ ] Resource inventory recorded; material review findings resolved.
- [ ] Local tests pass; Terraform plan reviewed; region/account/budget confirmed.
- [ ] Fault → alarm → automatic rollback → verified recovery, with linked events.
- [ ] Successful candidate deployment also evidenced.
- [ ] No alias ownership conflict concealed by scripts.
- [ ] Evidence captured, redacted and reviewed for readability.
- [ ] Teardown verified, or retention explicitly approved.
- [ ] Article drafted with `cloud: aws`, correct claim boundaries and exactly one comparison table.
- [ ] Site build and rendered-page inspection complete.
- [ ] LinkedIn draft leads with a measured result and links to proof.
- [ ] 90-second recording exists (script alone does not pass).
- [ ] Recruiter message and 60–90 second interview answer saved with follow-ups.
- [ ] User can explain alias routing, alarm semantics, IaC ownership and rollback unaided.

## Publication preparation — 22 October 2026

See START_HERE_PUBLICATION.md and PUBLICATION_CHECKS.json. Article 019 and LinkedIn text prepared; public evidence separated by run and redacted. Build and four handler tests pass; desktop article preview inspected. Fresh service sweep and tag sweep empty, budget retained. Independent publication review is being recorded separately. No publication performed. Video remains a script, not a recording; full course/distribution definition of done remains open.
