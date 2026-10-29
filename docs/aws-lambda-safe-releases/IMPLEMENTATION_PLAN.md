# Implementation plan — AWS Lambda safe releases

Status: **active**
Created: 2026-10-19
Supersedes: the parallel role matrix and work packages A–D in `IMPLEMENTATION_BRIEF.md` §2 and §5.
Companion documents: `IMPLEMENTATION_BRIEF.md` (scope, claim boundaries, evidence rules) · `STATUS.md` (current state, decisions, run parameters)

---

## 0. Execution model

This project runs **sequentially, one writer at a time**. There is no parallel editing of the same working tree, no agent-to-agent messaging, and no work started on Phase *n+1* before Phase *n* has a frozen commit and a recorded exit state.

The reason is not ceremony. The expensive mistakes in this project are design decisions — alias ownership, alarm metric, canary timing, deploy path — and those are cheapest to review on paper and most expensive to discover during a live run. Parallel implementation hides them until integration.

### Roles

| Role | Who | Responsibility |
|---|---|---|
| **Implementer** | OpenCode (this session) | Phases 0–6; drives the live run (Phase 3) with the user present |
| **Plan reviewer** | Independent session or model — **not the implementer** | Gate 1: frozen diff + Terraform plan, before any AWS spend |
| **Evidence reviewer** | Independent session or model | Gate 2: article claims against captured artefacts |
| **Run approver** | User | Credentials, spend approval, go/no-go, retain-or-destroy decision |
| **Evidence capture** | Codex or user | Console screenshots during Phase 4; video in Phase 6 |
| **Publisher** | User | Explicit approval before push, deploy or LinkedIn post |

Rules:

1. **One writer at a time.** Reviewers return findings in `REVIEW_FINDINGS.md`; they do not edit implementation files concurrently.
2. **Freeze before review.** Every gate reviews a named commit SHA, not a moving tree.
3. **No AWS spend before Gate 1.** No publication before Gate 2.
4. **The implementer does not review their own work.** A second session is required, even if it is the same model.
5. **The user is present for the live run.** The implementer may drive scripts; the user owns the account and approves spend.

---

## 1. Gates at a glance

| Gate | Position | Owner | Pass condition | Cost of failure |
|---|---|---|---|---|
| **0** | End of Phase 0 | User + implementer | Account, region, OIDC provider, state backend, budget alert and project tag recorded in `STATUS.md` §2 | Rework of environment assumptions |
| **1** | After Phase 1, **before any apply** | Independent reviewer | Frozen commit; `terraform fmt`/`validate` clean; reviewed plan; no open High findings | One re-run (~$0.03) and lost time |
| **2** | After Phase 4, **before publication** | Independent reviewer | Frozen evidence manifest; every numeric claim traceable to an artefact; estimates labelled | Credibility damage — the expensive one |
| **3** | Before publish/retain | User | Explicit approval of publication and of retain-or-destroy | Unapproved spend or disclosure |

If a gate fails, record the failure in `STATUS.md` and `REVIEW_FINDINGS.md`. Do not proceed and do not reword the claim to fit.

---

## 2. Phases

### Phase 0 — Preflight (≈0.5 h)

**Owner:** implementer, with user input.

Tasks:

- Confirm `aws sts get-caller-identity`; record account and region privately (never in the public repo).
- Check whether a shared GitHub OIDC provider for `token.actions.githubusercontent.com` already exists. **Reuse it; do not create a duplicate.**
- Check for an existing private Terraform state backend. Reuse if suitable.
- Set a **USD 5** budget with 50/80/100% notifications.
- Confirm no existing resources use the project tag value.
- Record all of the above in `STATUS.md` §2.

**Exit:** Gate 0 passed. No code written, no resources created.

---

### Phase 1 — Local implementation (5–8 h)

**Owner:** implementer only.

Build under `examples/aws-lambda-safe-releases/`:

| Path | Content |
|---|---|
| `app/` | Python handler; version marker in the response; deterministic fault via `FAIL_MODE`; no VPC |
| `tests/` | Handler unit tests; release-manifest validation test; no cloud credentials required |
| `infra/` | Terraform: function (`publish = true`), alias with `ignore_changes = [function_version, routing_config]`, CodeDeploy app + deployment group (`LambdaCanary10Percent10Minutes`, alarm attached, auto-rollback), one count alarm on Lambda `Errors`, minimal HTTP API, execution role + **permissions boundary**, deployment role (`AWSCodeDeployRoleForLambda`), log group with retention, artifact bucket |
| `scripts/` | Build/publish, bounded load generator, evidence collection, teardown verification |
| `README.md` | Reproduce → deploy → failure experiment → recovery → cleanup |

Also:

- `.github/workflows/` — OIDC deploy job (`id-token: write`, `role-to-assume`, no long-lived keys).
- Update `STATUS.md` §3–§8 with the implemented values; the pre-computed numbers in §4–§8 are the specification, not a guess to be filled in later.

**Local checks before stopping:**

```bash
terraform -chdir=examples/aws-lambda-safe-releases/infra fmt -check -recursive
terraform -chdir=examples/aws-lambda-safe-releases/infra validate
terraform -chdir=examples/aws-lambda-safe-releases/infra plan -out=tfplan   # credentials required
pytest examples/aws-lambda-safe-releases/tests
```

**Exit:**

- Tests pass locally.
- `terraform validate` clean.
- A redacted `terraform plan` is saved as a review artefact.
- **Freeze commit A** and record its SHA in `STATUS.md`.

Do not apply.

---

### Gate 1 — Plan review (1–2 h)

**Owner:** independent reviewer. **No implementer edits during review.**

Review the frozen commit and the plan output against:

- [ ] Alias ownership: Terraform owns existence; CodeDeploy owns routing; `ignore_changes` is narrow and explained; a post-rollback plan shows no diff.
- [ ] Alarm: metric is `Errors` (or a justified alternative), dimensions observe the traffic under test, `period`/`evaluation_periods`/`datapoints_to_alarm` can reach `ALARM` inside the canary window, missing-data handling is deliberate.
- [ ] Fault is deterministic and actually increments the chosen metric (not a returned `statusCode=500`).
- [ ] CodeDeploy: alarm attached to the deployment group; `auto_rollback_configuration` includes `DEPLOYMENT_STOP_ON_ALARM`; deployment role and trust correct.
- [ ] IAM: runtime and deployment roles separated; permissions boundary present and meaningful.
- [ ] OIDC: `id-token: write`; role trust scoped by `sub`; no long-lived keys.
- [ ] Cost: estimate labelled as estimate; no NAT, provisioned concurrency, CMK, Security Hub, Config or X-Ray.
- [ ] Teardown covers Lambda versions, alias, CodeDeploy, alarms, log group, HTTP API, S3 object versions, IAM — and preserves shared state/OIDC infrastructure.
- [ ] Claim boundaries: nothing in the code or docs implies Step Functions, DynamoDB Streams, EKS or production scale.

**Output:** `REVIEW_FINDINGS.md` entries with severity (High/Medium/Low) and file references.

**Exit:** no open High findings. Medium findings resolved or explicitly accepted by the user in writing in `STATUS.md`.

**Freeze commit B** after fixes. This is the commit that will be deployed.

---

### Phase 2 — Pre-run rehearsal (1–2 h)

**Owner:** implementer, with user available.

- Walk the runbook end to end without spending: confirm every command, path and output location.
- Verify the load generator caps: 10 req/s, 6-minute duration, 5,000-request hard stop. The generator is sequential (concurrency 1); there is no separate wall-clock timeout.
- Verify evidence collection writes only to the ignored raw directory; verify the redaction step.
- Confirm the manual stop command is to hand: `aws deploy stop-deployment --deployment-id <id> --auto-rollback-enabled`.
- Re-read `STATUS.md` §4–§7 and confirm the numbers match the code.

**Exit:** runbook approved by the user; budget alert visible; commit B is the deployed commit.

---

### Phase 3 — Live run (0.5–1 h)

**Owner:** implementer drives; user approves and is present; Codex or user captures screenshots.

Sequence:

1. Deploy baseline; verify healthy response and version under bounded load.
2. Deploy a **healthy** candidate; verify 100% traffic and version marker.
3. Publish the **faulty** candidate; start the CodeDeploy canary.
4. Capture the active traffic split and version-specific results.
5. Capture the alarm in `ALARM` with metric, dimensions and time window.
6. Capture CodeDeploy rollback event/status linked to the failed deployment.
7. Verify the alias routes to the previous healthy version (v2 in this run, not v1) and requests succeed under load after rollback.
8. Run `terraform plan`; capture that it shows **no alias drift**.
9. Decide retain or destroy with the user; if destroy, run teardown and verify inventory.

**Timing targets** (from `STATUS.md` §4): ALARM ≤ ~3 min after the first failing candidate request; canary window 10 min gives ~7 min margin.

**Contingency:** if the alarm has not reached `ALARM` by `t0 + 5 min`, stop the deployment with auto-rollback, record the detection failure as a negative result, and do not present the run as a success. Fix the timing parameters, re-run Gate 1 for the changed alarm block, then repeat Phase 3.

**Exit:** all evidence items captured; run ID and UTC timeline recorded; **Freeze commit C** (if code changed) and an evidence manifest.

---

### Phase 4 — Evidence freeze and Gate 2 (1–2 h)

**Owner:** implementer freezes; independent reviewer assesses.

- Redact: account IDs, ARNs containing account IDs, emails, tokens, personal identifiers.
- Write `public/evidence/aws-lambda-safe-releases/MANIFEST.md`: file list, SHA-256 checksums, run ID, commit SHA, UTC timestamps, what each artefact establishes.
- Draft the article **from the captured results only**.
- Reviewer checks every numeric and causal claim against the manifest: intervals, sample sizes, configured vs observed traffic, cost labels, rollback causality, cleanup completeness.

**Exit:** Gate 2 passed. Any claim without an artefact is removed or explicitly marked as a design intent.

---

### Phase 5 — Article and distribution (3–5 h)

**Owner:** implementer drafts; independent editorial/technical review; user records video.

- Article at `src/content/posts/platform-engineering-idp/<unique-id>-aws-lambda-safe-releases.mdx`, `cloud: aws`, exactly one cross-cloud comparison table, link to the Cloud Run golden path and SLO posts.
- Required sections: problem, design, failure, detection, rollback, verification, cost (estimate vs actual), limits.
- LinkedIn draft leading with the measured result.
- 90-second video script **and** a real recording — a script alone does not pass.
- Recruiter message and 60–90 second interview answer with likely follow-ups.
- Site build and rendered-page inspection.

**Exit:** article reviewed; video exists; no unverified claim.

---

### Phase 6 — Publish and close (0.5 h)

**Owner:** user approves; implementer executes.

- User approves publication and the retain-or-destroy decision (Gate 3).
- Push, deploy and post only on explicit approval.
- Update `job-search/TRACKER.md` and the blog backlog/scorecard with the published post.
- If destroyed: attach the teardown inventory to the manifest.
- If retained: record the expected monthly cost and the review date.

---

## 3. Freeze protocol

| Freeze | When | What is frozen | Recorded in |
|---|---|---|---|
| **A** | End of Phase 1 | Code + Terraform + plan output | `STATUS.md` §2 |
| **B** | After Gate 1 fixes | The commit that will be deployed | `STATUS.md` §2 |
| **C** | End of Phase 3 | Code state + evidence set | `MANIFEST.md` |

Rules: no force-push during a freeze; no edits between Gate 1 and Phase 3 except fixes that trigger a re-review of the changed block; evidence files are append-only.

---

## 4. Contingencies

| Event | Response |
|---|---|
| Alarm does not fire inside the canary | Stop with auto-rollback; record as negative; fix `period`/`evaluation_periods` or threshold; re-review the alarm block; re-run |
| Rollback does not occur | Capture the failure as the finding; do not claim automatic rollback; investigate deployment-group alarm attachment |
| Candidate traffic is not observable | Check alias weighting and HTTP API integration; do not substitute configured weight for observed counts |
| Terraform plan shows alias drift after rollback | Stop; the ownership contract is wrong; fix `ignore_changes` narrowly and re-review |
| Credentials or region unavailable | Pause. Do not silently switch accounts or regions; record the blocker |
| Cost exceeds the allowance | Destroy immediately; record actuals; do not continue the run |
| Screenshot capture unavailable | Publish machine-readable evidence only; state the limitation; do not fabricate console images |

---

## 5. Budget

| Item | Allowance |
|---|---|
| AWS, three runs plus retries | **< $0.20** actual; **$2–5** approved ceiling |
| Implementer time | 12–20 h |
| Review time | 2–4 h |
| Distribution assets | 2–4 h |

The largest controllable cost is a wasted live run. Gate 1 exists to prevent it.

---

## 6. Definition of done

`STATUS.md` §13 is authoritative. In summary: Gate 0–3 passed, both the successful and faulty releases evidenced, automatic rollback verified, no alias drift, evidence redacted and traceable, teardown verified or retention approved, article and video published with correct claim boundaries, and the user able to explain alias routing, alarm semantics, IaC ownership and rollback unaided.
