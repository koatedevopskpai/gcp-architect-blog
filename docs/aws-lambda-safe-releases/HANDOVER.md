# Handover — AWS Lambda safe releases

Last updated: 2026-10-20
Status: **Phase 3 complete; Phase 4 (Gate 2 evidence review) next**
Evidence: `evidence/raw/20261020-0251/` (gitignored)
Deploy/run commit: `9fc41bf` (Freeze C)

This note lets a fresh session continue without reconstructing context.

---

## 1. Where we are

| Phase | State |
|---|---|
| 0 — Preflight | Complete |
| 1 — Local implementation | Complete |
| Gate 1 — Independent plan review | Passed; F1–F7 dispositioned |
| 2 — Pre-run rehearsal | Complete; `REHEARSAL.md` |
| 3 — Live run | **Complete 2026-10-20**; evidence captured |
| 4 — Evidence freeze + Gate 2 | **Next** |
| 5 — Article and distribution | Not started |
| 6 — Publish and close | Not started |

The demo stack has been destroyed. The only AWS resource that remains is the
tag-scoped budget `aws-lambda-safe-releases-demo` (USD 5/month, alerts at
20/50/80/100%). Terraform state contains only that budget.

---

## 2. Live run result (2026-10-20, run `20261020-0251`)

| Field | Result |
|---|---|
| Region | `eu-west-2` |
| v1 | `baseline` (Terraform) |
| v2 | `candidate-healthy`, deployment `d-8YABO1E6K` — Succeeded |
| v3 | `candidate-faulty`, deployment `d-9PAMKTD6K` — 10% canary |
| Alarm | `ALARM` at `03:11:51` |
| Rollback | Deployment complete at `03:11:57` (artifact); poll observed `03:12:18`; rollback `d-YGITAAD6K` Succeeded |
| Recovery | alias `live` back at **v2**, weights cleared, alarm returned to `OK` |
| Load | 3,601 requests: 3,479 × 200, 120 × 500, 2 × 429 |
| Post-rollback plan | `No changes. Your infrastructure matches the configuration.` |
| Teardown | 25 resources destroyed; budget restored; all checks empty |

**The rollback target is v2, not v1.** The article must name exact versions.

Machine-readable evidence: `evidence/raw/20261020-0251/` — `load.json`,
`baseline-load.json`, `alarms.json`, `deployment.json`, `lambda-alias.json`,
`lambda-versions.json`, `codedeploy-*.json`, `post-rollback-plan.txt`,
`terraform-apply.txt`, `terraform-destroy.txt`, `teardown.txt`, `run-log.txt`.

Screenshots were taken by the user during the run. Raw originals are **untracked**
in `docs/aws-lambda-safe-releases/`. Publication copies belong in
`public/evidence/aws-lambda-safe-releases/` with the filenames above, after
checking that no account ID, ARN, email or root identity is visible.

**Screenshot status:** eight raw PNGs are currently **untracked** in this folder.
The independent review found 01–03 and 05–07 invalid (permissions or wrong URL),
04 usable after redaction, and 08 partial. See `CODEX_SCREENSHOT_REVIEW.md` and
`SCREENSHOT_COORDINATION.md`. Do not publish the current set as a full rollback
narrative.

---

## 3. Live-run findings (L1–L10)

| # | Severity | Finding | Disposition |
|---|---|---|---|
| L1 | High | **A Lambda CodeDeploy revision is the AppSpec, not the code zip.** The target version must be published first. | Fixed in `deploy.sh`: `update-function-code --publish`, then an `AppSpecContent` revision. The article must explain this. |
| L2 | Medium | Windows CLI added `\r`, producing `CurrentVersion: "1\r"`. | Fixed with `tr -d '\r'`. |
| L3 | Medium | `AWSCodeDeployRoleForLambda` alone lacked S3 read on the artifact bucket. | Fixed with an inline role policy. |
| L4 | Medium | WSL did not inherit PowerShell env vars. | Fixed with explicit `VAR='value' bash -c ...`. |
| L5 | Medium | Windows `aws.exe` could not read `/mnt/c/...` paths. | Fixed with `wslpath -w` / `cygpath -w`. |
| L6 | Low | PowerShell 5.1 treated native stderr as terminating. | Fixed with checked native-command helpers. |
| L7 | Low | Multi-line output broke `-split` ID parsing. | Fixed with regex extraction. |
| L8 | Medium | Rollback polling checked `FunctionVersion`, which stays at the base during a canary. | Fixed: poll `Stopped`/`Failed` plus cleared weights. |
| L9 | Low | `-Url ""` dropped by `powershell -File`. | Workaround: omit `-Url`. |
| L10 | Info | 2 × 429 at 10 req/s. | Accepted; burst artefact. |

A **fresh end-to-end run** is recommended before publishing, because the live run
was resumed manually after L1/L3 were fixed. The script now contains the fixes.

---

## 4. Next actions

1. **Save the screenshots** into `public/evidence/aws-lambda-safe-releases/` with
   the filenames above; redact account IDs and any personal identifiers.
   **Do not use the current set as-is:** see `SCREENSHOT_COORDINATION.md` and
   `CODEX_SCREENSHOT_REVIEW.md`; 01–03 and 05–07 must be replaced.
2. **Redact the text evidence** with
   `python scripts/redact-evidence.py evidence/raw/20261020-0251 --out <path>`.
   Images are skipped by the script and need manual review.
3. **Gate 2** — independent evidence-to-claim review. Every numeric or causal
   claim in the article must trace to an artefact. Estimates must be labelled.
4. **Write the article** at
   `src/content/posts/platform-engineering-idp/<unique-id>-aws-lambda-safe-releases.mdx`
   with `cloud: "aws"` and exactly one cross-cloud comparison table. Link the
   Cloud Run golden-path and SLO posts.
5. **Distribution** — LinkedIn draft, 90-second recording (a script alone does
   not pass), recruiter message, interview answer.
6. **Publish** only with explicit user approval; update `STATUS.md`,
   `REHEARSAL.md`, `HANDOVER.md` and `job-search/TRACKER.md`.
7. The backlog already has the post as topic `019`; set it to `published` with the
   final path and date when it ships.

Before writing any cost sentence, check AWS Billing after 24h. The budget showed
`$0.00` immediately after the run because cost data lags; the ~$0.03 figure is an
estimate, not measured spend.

---

## 5. Invariants — do not break

- **Lambda CodeDeploy revision model:** publish the target version first, then
  send `AppSpecContent` naming `CurrentVersion` and `TargetVersion`. Do not send a
  zip as the revision; CodeDeploy fails with `INVALID_REVISION`.
- **Terraform owns the alias's existence; CodeDeploy owns its routing.** Alias
  `ignore_changes = [function_version, routing_config]`; function
  `ignore_changes = [filename, source_code_hash]`. Post-rollback plan must be
  clean.
- **The fault raises an exception.** A returned `statusCode=500` does not move
  Lambda `Errors`.
- **Count alarm, not rate:** 60 s × 2 datapoints, threshold 1, `notBreaching`.
- **Canary 10 minutes;** the alarm fires in ~3 minutes. Stop with auto-rollback if
  no `ALARM` by `t0 + 5 min`.
- **No VPC/NAT, provisioned concurrency, CMK, Security Hub, Config or X-Ray.**
- **Do not use root** for the demo.
- **Do not commit** state, `terraform.tfvars`, `build/` or `evidence/raw/`.
- **Do not publish** account IDs, ARNs containing them, emails or access keys.

---

## 6. Rerun the live experiment

The stack is destroyed. A fresh run is:

```powershell
cd C:\Users\koate\development\gcp-architect-blog\examples\aws-lambda-safe-releases
python scripts/build.py baseline
terraform -chdir=infra apply
powershell -File scripts/run-live.ps1 -SkipApply
```

`run-live.ps1` now applies nothing if `-SkipApply` is set; use it only when the
stack already exists. Without it, the script asks for spend approval and applies
the stack first. The script now handles the AppSpec revision model, explicit bash
env, CRLF, WSL paths and the rollback check.

To stop a deployment:

```bash
aws deploy stop-deployment --deployment-id <id> --auto-rollback-enabled
aws lambda get-alias --function-name aws-lambda-safe-releases --name live \
  --query 'FunctionVersion'
```

To destroy and preserve the budget:

```bash
terraform -chdir=infra destroy -auto-approve
terraform -chdir=infra apply -auto-approve -target="aws_budgets_budget.demo"
bash scripts/verify-teardown.sh
```

---

## 7. Files and commits

| File | Purpose |
|---|---|
| `IMPLEMENTATION_BRIEF.md` | Scope, claim boundaries, evidence rules |
| `IMPLEMENTATION_PLAN.md` | Phases, gates, freeze protocol |
| `STATUS.md` | Current state, run parameters, dispositions, run result |
| `REVIEW_FINDINGS.md` | Independent Gate 1 review (F1–F7) |
| `PLAN_REVIEW.md` | Redacted resource inventory and reviewer questions |
| `REHEARSAL.md` | Phase 2 checks and live-run findings L1–L10 |
| `CODEX_CAPTURE_REQUEST.md` | Codex capture coordination request |
| `CODEX_SCREENSHOT_REVIEW.md` | Independent review of the eight raw PNGs |
| `SCREENSHOT_COORDINATION.md` | Capture readiness, URL fix, policy proposal, checkpoints |
| `examples/aws-lambda-safe-releases/` | Code, Terraform, scripts, README |
| `scripts/run-live.ps1` | Orchestrated live run with screenshot prompts |
| `scripts/show-stage.ps1` | Standalone screenshot prompt used during recovery |

| Freeze | SHA | Meaning |
|---|---|---|
| A | `8b2c2a1` | Implementation reviewed at Gate 1 |
| B | `3143309` | Gate 1 fixes |
| B2 | `3ec44d6` | Phase 2 tooling |
| B3 | `bfb87e6` | Cross-shell CLI resolution |
| B4 | `6054ec7` | Budget + screenshot orchestration |
| C | `9fc41bf` | Post-live-run correctness fixes; evidence frozen |
| C+ | `124545a` | Code artifact separated from AppSpec (cleanup) |

---

## 8. Open decisions

1. **Post ID** — choose the next free numeric prefix; `npm run new:post` now
   refuses duplicates.
2. **Retention** — the stack is destroyed. If a live demo is wanted later,
   redeploy deliberately, throttle it and document the monthly cost.
3. **Screenshot ownership** — the user captured them; they still need to be filed
   and redacted.
4. **Delta review** — `deploy.sh`, `common.sh`, `run-live.ps1` and the CodeDeploy
   S3 policy changed after Gate 1. A short review of that diff is reasonable.

---

## 9. First commands for a fresh session

```bash
cd C:\Users\koate\development\gcp-architect-blog\examples\aws-lambda-safe-releases
git status --short
terraform -chdir=infra state list          # should show only aws_budgets_budget.demo
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=aws-lambda-safe-releases \
  --region eu-west-2 --query 'ResourceTagMappingList[].ResourceARN'
ls evidence/raw/20261020-0251
```

Expected: clean tree, only the budget in state, no tagged demo resources, and the
evidence directory from the run.

## 22 October 2026 — publication preparation update

Supersedes earlier "Phase 5 not started" and screenshot instructions for publication. Article 019, LinkedIn text, public redacted evidence, a hash manifest, and a 90-second script now exist. Read START_HERE_PUBLICATION.md first.

The primary run remains 20261020-0251. A later capture run 20261020-030749-native-capture saved healthy/canary screenshots but timed out at the alarm checkpoint and cleaned up. The public article labels those separately. It does not claim a full screenshot narrative or unattended success.

Fresh 22 October inventory: eight service checks and Project-tag sweep empty; Terraform state only aws_budgets_budget.demo. Handler tests: four passed. Full npm build passed using the existing Playwright browser path. Article rendered and inspected in Chrome. Nothing deployed or posted. Video remains unrecorded; native-helper parity issues are tracked separately.
