# Gate 1 review findings — AWS Lambda safe releases

Reviewer: independent session (not the implementer)
Review target: commit `8b2c2a1` (Freeze A)
Date: 2026-10-19
Method: read the full frozen diff (`main.tf`, `variables.tf`, `versions.tf`, `outputs.tf`,
`handler.py`, `build.py`, `deploy.sh`, `load.py`, evidence/teardown scripts, tests,
README, workflow) against the Gate 1 checklist in `IMPLEMENTATION_PLAN.md`.

## Verdict

**PASS — no open High findings.** The core mechanism is correctly implemented.
One Medium finding (claim wording) and several Low/Info findings below. Per the plan,
the Medium must be fixed or explicitly accepted by the user in `STATUS.md` before
Freeze B.

---

## Confirmed correct (checked against the source, not just the plan)

| Checklist item | Status | Evidence |
|---|---|---|
| Alias ownership split | ✅ | `aws_lambda_alias.live` has `ignore_changes = [function_version, routing_config]` (main.tf:186-189); function has `ignore_changes = [filename, source_code_hash]` (main.tf:171-175). Both narrow and explained. |
| Fault is an exception, not a returned 500 | ✅ | `handler.py:38-39` raises `RuntimeError` when `fail_mode == "always"`; `test_handler.py:40-47` asserts the raise. Correctly increments Lambda `Errors`. |
| Alarm metric/dimensions | ✅ | `Errors` / `Sum`, dimensions `FunctionName` + `Resource = <fn>:live` (main.tf:192-211). Alias-scoped; count alarm avoids 10% canary dilution. |
| Alarm can fire inside the canary | ✅ | 60 s × 2 datapoints = ≤ ~3 min, inside the 10-minute canary (~7 min margin). |
| Missing-data handling | ✅ | `treat_missing_data = "notBreaching"` (main.tf:203) — no false `ALARM`/`INSUFFICIENT_DATA` before traffic. |
| CodeDeploy alarm + auto-rollback | ✅ | `alarm_configuration.enabled = true` references the alarm; `auto_rollback_configuration` = `DEPLOYMENT_FAILURE` + `DEPLOYMENT_STOP_ON_ALARM` (main.tf:257-265). |
| IAM separation + boundary | ✅ | Runtime role, CodeDeploy role (`AWSCodeDeployRoleForLambda`), and OIDC deploy role are separate. Boundary is logs-only and meaningful for this pure handler (main.tf:110-142). |
| OIDC scoping | ✅ | `id-token: write` (workflow:20-22); trust `sub` = `repo:…:ref:refs/heads/main`; provider reused via `count = 0` when `existing_oidc_provider_arn` is set (main.tf:318-328, 340-351). No long-lived keys. |
| Cost boundaries | ✅ | No NAT, provisioned concurrency, CMK, Security Hub, Config or X-Ray anywhere in `main.tf`. |
| Teardown coverage | ✅ | `force_destroy = true` removes S3 object versions; `destroy` removes Lambda (versions+alias), CodeDeploy, alarm, log group, HTTP API, IAM; shared OIDC provider is referenced, not owned. |
| No scope-creep claims | ✅ | README "Scope boundary" + "What this does not cover" correctly disclaim Step Functions/DynamoDB Streams/EventBridge/EKS/production scale. |
| Resource inventory consistency | ✅ | 24 `resource` blocks in `main.tf`; with OIDC `count = 0` (reuse) that is 23 to add, matching `PLAN_REVIEW.md`. |

---

## Findings

### F1 — Medium — "baseline" conflates the original version with the rollback target

**Files:** `README.md` (lines 9-10, 33, 96), `docs/aws-lambda-safe-releases/STATUS.md` §7,
`docs/aws-lambda-safe-releases/IMPLEMENTATION_PLAN.md` Phase 3 step 7.

The run publishes three versions in order:

1. **v1** `baseline` (deployed by Terraform),
2. **v2** `candidate-healthy` (deployed to 100% by CodeDeploy),
3. **v3** `candidate-faulty` (10% canary, then rolled back).

CodeDeploy rolls back to the version the alias pointed to *before* the faulty
deployment — **v2, the healthy candidate**, not v1. The docs say "shifts traffic
back to the baseline" / "alias restored to baseline", which a reader (and the Gate 2
evidence reviewer) could read as v1.

**Recommendation:** keep "baseline" for v1 only. Phrase recovery as "alias restored to
the previous healthy version (v2 = candidate-healthy)". The article and evidence must
name exact version numbers, since this is exactly the kind of precision Gate 2 checks.

### F2 — Low — load generator is sequential, not "concurrency 10"

**Files:** `scripts/load.py`, `STATUS.md` §5 ("Concurrency cap 10"),
`IMPLEMENTATION_PLAN.md` Phase 2 ("verify … concurrency 10").

`load.py` is a single `while` loop with sleep-pacing (load.py:44-67); it cannot issue
concurrent requests. The stated "concurrency 10" is not implemented, and the Phase 2
rehearsal step will not verify against it.

Not a correctness problem — 10 req/s sequential still produces ~60 candidate errors/min,
far above the alarm threshold — but the docs overstate the generator's capability.
**Recommendation:** either add a `--concurrency`/thread pool to `load.py`, or correct
`STATUS.md` §5 and Phase 2 to "sequential, concurrency 1 (within cap 10)".

### F3 — Low — STATUS.md §3 references a non-existent alarm resource

**File:** `docs/aws-lambda-safe-releases/STATUS.md` line 105.

The snippet reads `alarms = [aws_cloudwatch_metric_alarm.candidate_errors.alarm_name]`,
but the actual resource is `aws_cloudwatch_metric_alarm.errors` (main.tf:192). A reader
copying the snippet gets a reference error.

### F4 — Low — CodeDeploy IAM actions scoped to account/region `*`

**File:** `infra/main.tf` lines 388-390.

`codedeploy:CreateDeployment`, `RegisterApplicationRevision`, etc. are allowed on
`arn:aws:codedeploy:<region>:<account>:*` — every application and deployment group in
the account. The demo needs only the one app/group. Acceptable for a demo, but tighter
scoping to the specific application and deployment-group ARN would better match the
least-privilege framing the article relies on.

### F5 — Low — verify-teardown.sh does not check the HTTP API or the boundary policy

**File:** `scripts/verify-teardown.sh`.

It checks Lambda, CodeDeploy applications, alarms, log groups, buckets and IAM roles,
but not the API Gateway v2 API/stage/integration (covered only indirectly by tag
discovery, which the script itself caveats) and not the `aws_iam_policy.lambda_boundary`
(roles are checked, the boundary policy is not). `STATUS.md` §10 already lists the full
set, so this is a gap in the verification script only, not in the teardown plan.

### F6 — Info — "Load-generator timeout 10 min" has no parameter in load.py

**File:** `scripts/load.py`, `STATUS.md` §5.

`load.py` exposes `--timeout 5.0` (per-request HTTP timeout) and `--seconds` (duration,
default 360 s), with a `--max-requests 5000` hard stop. There is no 10-minute wall-clock
cap. If a 10-minute ceiling is intended, it is not implemented; otherwise document the
actual parameters.

### F7 — Info — `iam:PassRole` in the GitHub deploy role is unused by the current flow

**File:** `infra/main.tf` lines 407-418.

`deploy.sh` calls `create-deployment`, which does not require `iam:PassRole` (the
deployment group's service role is set by Terraform). The scoped PassRole grant is
harmless defence-in-depth but currently dead; keep it only if a future step will create
or update deployment groups.

---

## Answers to the priority questions (PLAN_REVIEW.md §4)

1. **Alias ownership** — Sufficient. `ignore_changes = [function_version, routing_config]`
   on the alias plus `[filename, source_code_hash]` on the function covers the drift
   CodeDeploy introduces (alias routing, published versions, `$LATEST` code). The
   authoritative check remains the post-rollback `terraform plan` gate (Phase 3 step 8);
   execute it rather than reasoning it away.
2. **Alarm dimensions** — Correct. `Resource = <fn>:live` observes alias traffic, and
   `notBreaching` avoids `INSUFFICIENT_DATA`/`ALARM` at deployment start when there is no
   traffic.
3. **Canary vs alarm timing** — Adequate. 60 s × 2 gives ~3 min to `ALARM` inside a
   10-minute canary. No tightening required; the 5-minute stop contingency is a sound
   fallback.
4. **AppSpec target version** — `max + 1` is acceptable for a single-writer demo. The
   failure mode (a concurrent publish) fails the deployment rather than corrupting
   traffic, as documented in `PLAN_REVIEW.md` §5. Note F1's version-number precision.
5. **IAM** — Boundary is meaningful (logs only); runtime/CodeDeploy/deploy roles are
   separated; `iam:PassRole` is scoped and condition-guarded. F4 (CodeDeploy `*` scope)
   is the only tightening worth considering.
6. **OIDC** — Reuse with a `sub`-scoped trust policy is safe; `destroy` cannot remove the
   shared provider (`count = 0` when reused).
7. **Teardown** — `force_destroy` removes versioned objects; Lambda versions/alias,
   CodeDeploy, alarms, log group and deploy role are all covered. See F5 for the two
   gaps in the verify script.
8. **Claims** — No Step Functions / DynamoDB Streams / EKS / production-scale language in
   the README or Terraform. F1 is the one claim-precision fix needed.
