# AWS Lambda safe releases - shared implementation brief

Date: 19 October 2026
Implementer: OpenCode (this session)
Reviewers: independent sessions for Gate 1 and Gate 2 · evidence capture: Codex or user
Execution model: sequential, one writer at a time — see `IMPLEMENTATION_PLAN.md`
Repository: C:\Users\koate\development\gcp-architect-blog
Canonical brief: docs/aws-lambda-safe-releases/IMPLEMENTATION_BRIEF.md
Status: ready for implementation; no deployment or spend performed by preparing this brief.

## 1. Objective and boundaries

**Amended 19 October 2026.** This section supersedes the original scope statement where the two differ. `STATUS.md` is the working record of resolved decisions and pre-computed run parameters.

Build a small, reproducible AWS demonstration that proves a faulty Lambda release is detected and automatically rolled back. Publish an evidence-backed AWS article, a measured-result LinkedIn draft and a 90-second recorded walkthrough. The intended signal is hands-on AWS release engineering and operations for platform/DevOps applications.

### In scope

- One Python Lambda function, Terraform-managed, with published versions and a stable alias.
- One deliberately faulty candidate release and one demonstrated automatic rollback.
- CodeDeploy application and deployment group with `alarm_configuration` and automatic rollback on `DEPLOYMENT_STOP_ON_ALARM`.
- At most two CloudWatch alarms, on Lambda `Errors` (count), with explicit missing-data handling.
- A **minimal HTTP API** so the weighted traffic split is externally visible in evidence.
- **GitHub Actions deploy via OIDC**, with no long-lived keys.
- A **permissions boundary** attached to the Lambda execution role.
- One successful candidate deployment at 100%, then one faulty candidate that rolls back.
- Synthetic input only.

### Out of scope for this artefact

- **DynamoDB, DynamoDB Streams, Step Functions, EventBridge and event-driven orchestration.** Tracked separately. The article must not imply they are demonstrated here.
- **EKS and any Kubernetes workload.** Lambda release operations do not evidence EKS operations; this remains a separate gap to close.
- NAT gateways, VPC placement, provisioned concurrency, customer-managed KMS keys, paid dashboards and AI services.
- Production-scale claims, measured billing without dated billing data, or any implication of commercial client implementation.

The narrow experiment is deliberate: one service, one fault, one rollback. Scope expansion belongs in a separate example or article, not in this run.

Estimated engineering/writing effort: **12-20 hours** (revised from 8-16; CodeDeploy alarm timing is the main source of uncertainty), plus 2-4 hours for distribution assets. Estimates are planning allowances, not promises. Keep weekday job applications the priority; schedule substantial implementation around the user's availability.

## 2. Execution model

This project runs **sequentially, one writer at a time**. The operational sequence, gates and contingencies live in `IMPLEMENTATION_PLAN.md`; `STATUS.md` holds current state and run parameters. Parallel editing of a shared working tree is explicitly out of scope.

| Role | Who | Responsibility |
|---|---|---|
| Implementer | OpenCode (this session) | Phases 0–6; drives the live run (Phase 3) with the user present |
| Plan reviewer | Independent session or model, **not the implementer** | Gate 1, before any AWS spend |
| Evidence reviewer | Independent session or model | Gate 2, article claims against captured artefacts |
| Run approver | User | Credentials, spend, go/no-go, retain-or-destroy |
| Evidence capture | Codex or user | Console screenshots during the live run |
| Publisher | User | Explicit approval before push, deploy or LinkedIn post |

Rules: freeze a commit before each gate and review the frozen SHA, not a moving tree; no AWS spend before Gate 1; no publication before Gate 2; reviewers return findings in `REVIEW_FINDINGS.md` and do not edit the implementation concurrently. Do not create remote tasks or send messages to other agents merely because this document names them; the user pastes prompts into the chosen sessions.

## 3. Proposed repository layout

Follow existing Astro/content conventions. Inspect actual filenames before choosing a unique post ID; do not reuse an occupied ID.

- examples/aws-lambda-safe-releases/README.md - reproduce, deploy, failure experiment, recovery and cleanup
- examples/aws-lambda-safe-releases/app/ - minimal Python handler, version marker and controlled faulty behaviour
- examples/aws-lambda-safe-releases/tests/ - meaningful handler and release-validation tests
- examples/aws-lambda-safe-releases/infra/ - Terraform, variables, outputs, lockfile and example variables without secrets
- examples/aws-lambda-safe-releases/scripts/ - release, bounded load, evidence collection and cleanup verification
- public/evidence/aws-lambda-safe-releases/ - redacted, publishable run artifacts only
- src/content/posts/platform-engineering-idp/<unique-id>-aws-lambda-safe-releases.mdx - cloud: aws
- docs/aws-lambda-safe-releases/STATUS.md - task ownership, completed work, review findings, blockers and next action
- docs/aws-lambda-safe-releases/REVIEW_FINDINGS.md - Claude/Codex findings and lead disposition

Private/raw artifacts belong in an explicitly ignored directory, not public/. Preserve evidence with a run ID, UTC timestamps and source commit. Check outputs for credentials, customer information and unnecessary personal/account identifiers before publication.

## 4. Minimal architecture and critical decisions

Terraform provisions a Lambda execution role **with an attached permissions boundary**, a managed log group with retention, published Lambda versions, a stable alias, a CodeDeploy application/deployment group, the necessary deployment role and **at most two** standard CloudWatch metric alarms on Lambda `Errors` (count). S3 stores deployment artifacts. A **minimal HTTP API is in scope** so the weighted traffic split is externally visible in evidence; give it throttling and the bounded request rate defined in `STATUS.md`.

OpenCode must document how Terraform and CodeDeploy share alias ownership. Prevent a later Terraform apply from unintentionally resetting a successfully deployed or rolled-back alias; any ignore_changes setting must be narrow and explained. Do not silently use a traffic-update script as a substitute for the CodeDeploy automatic rollback promised by the article.

Use on-demand execution. Choose one region after checking the user's existing account setup. Prefer existing suitable artifact/state infrastructure to duplicating it. Keep Terraform state private, versioned where appropriate and outside the public repository. Distinguish deployment permissions from runtime permissions.

Use a valid baseline version and a faulty candidate that reproducibly emits invocation failures. If an HTTP handler returns statusCode=500 normally, do not assume Lambda Errors increments: choose an exception-based fault or an explicitly suitable API/custom metric and verify it. Alarm dimensions must observe the candidate/alias traffic actually under test. Set missing-data handling deliberately; establish the alarm's baseline state before deployment.

CodeDeploy must explicitly monitor the selected alarm and have automatic rollback configured. Set bounded load sufficient for a small weighted sample, a defined failure threshold and a maximum runtime/request count. Configured routing weight and observed sampled percentage are different quantities.

## 5. Work packages and gates

The detailed phase sequence, owners, exit criteria and contingencies live in `IMPLEMENTATION_PLAN.md`. This section records only the gates and the live-run order.

| Gate | Position | Owner | Pass condition |
|---|---|---|---|
| 0 | After preflight | User + implementer | Account, region, OIDC provider, state backend, budget and tag recorded in `STATUS.md` §2 |
| 1 | After local implementation, **before any apply** | Independent reviewer | Frozen commit; `fmt`/`validate` clean; reviewed plan; no open High findings |
| 2 | After the live run, **before publication** | Independent reviewer | Frozen evidence manifest; every numeric claim traceable to an artefact |
| 3 | Before publish/retain | User | Explicit approval of publication and retention |

**Run sequence (Phase 3 in the plan):**

1. Deploy baseline and verify response/version under bounded load.
2. Deploy a healthy candidate and verify 100% traffic.
3. Publish the faulty candidate and start the CodeDeploy canary.
4. Capture active traffic split and version-specific results.
5. Capture the alarm in `ALARM` with its dimensions and time window.
6. Capture CodeDeploy rollback event/status linked to the failed deployment.
7. Verify the alias routes to the previous healthy version (v2 in this run, not v1) and requests succeed after rollback.
8. Record a follow-up `terraform plan` showing no alias drift.
9. Tear down unless retention is explicitly approved; verify residual resources by service.

**Contingency:** if the alarm has not reached `ALARM` by `t0 + 5 min`, stop the deployment with auto-rollback, record the detection failure as a negative result, and do not present the run as a success.

## 6. Codex screenshot responsibilities

| Screenshot | What it must establish |
|---|---|
| 01-baseline.png | Named service/version, healthy baseline response or relevant metrics, run time |
| 02-canary-routing.png | Alias/version weights or CodeDeploy traffic shift, identifiable deployment |
| 03-alarm.png | Correct alarm, ALARM state, observed metric and visible time window |
| 04-automatic-rollback.png | CodeDeploy rollback status/events linked to the failed deployment |
| 05-recovery.png | Alias restored and post-rollback request success, with timestamps |
| 06-cleanup.png | Relevant resource checks; supplement with CLI inventory rather than claiming one image proves complete cleanup |

Use Codex's supported browser controls for AWS console and rendered blog checks. Do not use hidden browser state, raw browser-network requests or an unapproved automation workaround. Screenshots should be legible, contextual and redacted before entering public/evidence. Never fabricate/recreate console screenshots. Annotated images must remain clearly labelled. Preserve original raw captures in ignored storage when needed.

Screenshots document visible state; the deployment events, configuration and request logs establish the causal sequence. A screenshot alone does not prove correct implementation, actual billing or complete cleanup.

Browser screenshot capability does not by itself provide screen-video recording. OpenCode coordinates available recording tooling or user-assisted capture; Codex supplies framing and browser views. A storyboard is not a recording.

## 7. Evidence and measurements

Required artifacts: source commit, region, run ID, UTC timeline, relevant Terraform version/provider versions, baseline/candidate identifiers, deployment configuration and ID, alarm description/history, alias configuration before/during/after, bounded invocation summary, redacted response/error samples, rollback result and teardown inventory.

Define intervals before publishing: failure start -> detection; detection -> rollback completion; failure start -> verified recovery. Report measured intervals, sample size and polling/time precision. Do not treat total incident duration as every one of those measures. Do not report configured canary weight as measured traffic distribution.

Success means the faulty candidate is observable, the alarm triggers configured CodeDeploy handling, traffic returns to the previous healthy version automatically, and healthy responses are verified. The run also includes one **successful** candidate deployment to 100%, so the evidence set shows both the good path and the rollback; this is in scope, not an optional extension.

## 8. Exactly one compact cross-cloud comparison table

| Concern | AWS demonstration | Existing Cloud Run demonstration |
|---|---|---|
| Traffic split | Alias weighted routing across published Lambda versions | Traffic allocation across Cloud Run revisions |
| Rollback | CodeDeploy automatic rollback, configured and tested | Operator runs gcloud run services update-traffic |
| Detection | CloudWatch alarm connected to deployment handling | Cloud Monitoring alert informs operator action |

This compares the chosen examples. It does not imply Cloud Run cannot automate rollback or that all Lambda releases roll back automatically. No separate cross-cloud article.

## 9. Cost assumptions and operational controls

Planning estimate checked 19 October 2026: roughly USD0.10-0.50 for several small runs; expected below USD1 for the minimal scoped experiment. Proposed testing allowance USD2-5. These are estimates using indicative US East rates, before applicable tax, without relying on free allowances. Exact region and account configuration must be checked before the live run. This brief is not evidence of budget approval or deployment.

Example arithmetic (matches the bounded run in `STATUS.md`): 3,600 invocations * 0.125 GB * 0.2 seconds = 90 GB-seconds; execution plus request charges are around USD0.002 at the cited indicative rate. HTTP API 3,600 requests around USD0.004; 10 MB logs ingestion around USD0.005; two single-metric standard alarms for one day around USD0.007. Artifact storage/request charges add small amounts. Additional retries, hooks, test runs and retained resources must be included in the final estimate.

- Avoid NAT/VPC endpoints, provisioned concurrency, custom keys, paid dashboards and unrelated services in this scope.
- Manage log groups explicitly with retention. Set request, concurrency, timeout and load-generator bounds; none is an account-wide billing cap.
- A budget alert is notification, not a hard spending limit; billing data can lag.
- Teardown must inspect Lambda, alias/versions, CodeDeploy resources, alarms, log groups, HTTP API, S3 objects/versions and project-created IAM resources. Preserve intentionally shared state infrastructure with documented ownership.
- Tag-based discovery supplements service-specific inventory; it cannot prove no resources survived.
- If retained, low-traffic cost might be USD0.50-2/month, but public use can change it. Retention is a separate user decision.
- Report actual billing only from dated billing data. Do not label calculation-based estimates as measured spend.

## 10. Definition of done

- [ ] OpenCode records resource inventory and resolves material Claude/Codex findings.
- [ ] Local checks pass; Terraform plan reviewed; permissions, account, region and live-run budget resolved.
- [ ] Fault -> alarm -> automatic rollback -> verified recovery evidenced with linked events.
- [ ] Successful candidate deployment to 100% evidenced alongside the failure case.
- [ ] No alias ownership conflict concealed by the deployment scripts.
- [ ] Codex screenshot set captured and reviewed for readability and disclosure.
- [ ] Teardown verified or explicitly documented user-approved retention.
- [ ] Article drafted with cloud: aws, correct proof boundaries and one comparison table.
- [ ] Relevant site checks and rendered-page inspection completed.
- [ ] LinkedIn write-up leads with a real measured result and links to proof.
- [ ] Ninety-second recording exists and is readable; script alone does not pass.
- [ ] Recruiter-message draft and 60-90-second interview answer saved with likely follow-ups.
- [ ] User can explain alias routing, alarm semantics, IaC ownership and rollback unaided.

## 11. Copy/paste session instructions

Use these **one at a time**, in order. Do not start a later prompt before the prior phase has a frozen commit and a recorded exit state. The full sequence is in `IMPLEMENTATION_PLAN.md`.

### 1 — Implementer (Phases 0–2)

Read `docs/aws-lambda-safe-releases/IMPLEMENTATION_BRIEF.md`, `IMPLEMENTATION_PLAN.md` and `STATUS.md` in `C:\Users\koate\development\gcp-architect-blog`. You are the sole implementer. Start with Phase 0 preflight and record the environment facts in `STATUS.md` §2. Then implement Phase 1 under `examples/aws-lambda-safe-releases/`: Terraform, Python handler, tests, scripts, HTTP API, OIDC workflow, permissions boundary. Run local checks and `terraform plan`; do not apply. Freeze commit A and record the SHA. Stop at Gate 1 and hand over for review. Do not claim live results, deployment, publication or recorded video before they exist.

### 2 — Gate 1 reviewer (plan and failure-mode review)

Read `IMPLEMENTATION_BRIEF.md`, `IMPLEMENTATION_PLAN.md`, `STATUS.md` and the frozen commit A diff plus the redacted `terraform plan`. You are an independent reviewer, not the implementer. Review alias ownership, alarm metric/dimensions/missing data, canary-vs-alarm timing, deterministic fault semantics, CodeDeploy alarm attachment and auto-rollback, IAM separation and permissions boundary, OIDC trust scoping, cost boundaries and teardown coverage. Return findings with severity and file references in `REVIEW_FINDINGS.md`. Do not edit implementation files. Do not invent results or broaden scope.

### 3 — Evidence capture (live run, Phase 3)

Read `IMPLEMENTATION_BRIEF.md`, `IMPLEMENTATION_PLAN.md` and `STATUS.md`. The user approves spend and is present; the implementer drives the run. Capture the baseline, healthy candidate, canary routing, alarm in `ALARM`, CodeDeploy automatic rollback, recovery and cleanup views at the coordinated stages. Save raw captures privately and publishable redacted evidence in the planned paths. Do not fabricate console evidence, deploy unrelated resources or publish without authorisation. Note explicitly that screenshot tooling cannot record video.

### 4 — Gate 2 reviewer (evidence-to-claim)

Read `IMPLEMENTATION_PLAN.md`, `STATUS.md`, the evidence manifest and the article draft. Check every numeric and causal claim against the captured artefacts: intervals, sample sizes, configured versus observed traffic, cost labels, rollback causality and cleanup completeness. Flag anything that is an estimate presented as measured, or a design intent presented as a result. Return findings in `REVIEW_FINDINGS.md`. Do not edit the article.

## 12. Pricing and technical references

- https://aws.amazon.com/lambda/pricing/
- https://aws.amazon.com/api-gateway/pricing/
- https://aws.amazon.com/cloudwatch/pricing/
- https://aws.amazon.com/codedeploy/pricing/
- https://docs.aws.amazon.com/us_en/lambda/latest/dg/configuring-alias-routing.html
- https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-groups-configure-advanced-options.html

Prior editorial plan: C:\Users\koate\Documents\Codex\2026-10-16\files-mentioned-by-the-user-ai\outputs\Blog_Editorial_Plan_19Oct2026\Next_Session_Blog_Plan.md
