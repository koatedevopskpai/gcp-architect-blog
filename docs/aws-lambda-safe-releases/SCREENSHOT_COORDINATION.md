# Screenshot capture coordination — AWS Lambda safe releases

Prepared: 2026-10-20
Owner: OpenCode (lead) · Browser capture: Codex
Request: `CODEX_CAPTURE_REQUEST.md`
Review: `CODEX_SCREENSHOT_REVIEW.md`

This is a coordination handoff, not a claim that capture has happened. No rerun,
IAM change, credential change, commit or publication was performed while preparing
it.

---

## 1. Readiness

| Item | State |
|---|---|
| Live experiment | Complete; stack destroyed |
| Existing run | `20261020-0251` |
| Region | `eu-west-2` |
| Raw evidence | `examples/aws-lambda-safe-releases/evidence/raw/20261020-0251/` |
| Screenshots | 8 raw PNGs, **untracked**, in `docs/aws-lambda-safe-releases/` |
| Screenshot review | 01–03 and 05–07 need replacement; 04 usable after redaction; 08 needs context or replacement |
| Observer console session | Chrome session established as observer (`FranklinWhyte`), reported by Codex/user — see §2 |
| URL interpolation bug | Fixed and verified — see §3 (uncommitted) |
| Observer read-policy gaps | Applied and verified by Codex as inline `DemoScreenshotObservedReadGaps` on `FranklinWhyte` — see §4 |
| Headless capture mode | Implemented in `run-live.ps1`; local self-test passing — see §10 |

The current screenshot set must **not** be published as a successful full
rollback narrative. Only `04-alarm.png` is usable as-is after redaction, and it
does not alone prove CodeDeploy caused the rollback.

---

## 2. Observer session and browser routing

Reported state (2026-10-20): the Chrome session is signed in as the read-only
observer (`FranklinWhyte`) and Codex owns all browser capture. Edge is no longer
the blocking path.

Before any new capture:

1. Confirm the Chrome console can view Lambda, CodeDeploy and CloudWatch without
   AccessDenied.
3. Do not use root. Do not use hidden browser state, raw network calls or any
   workaround that bypasses the approved session.
4. Do not change credentials or IAM permissions as part of this request.

If the observer session cannot be established, stop. Do not capture with a
different identity and do not fabricate console views.

---

## 3. URL interpolation fix (verified)

File: `examples/aws-lambda-safe-releases/scripts/run-live.ps1`,
`Get-DeploymentUrl`.

The old expression treated `Id?region` as a variable name and produced a URL with
`/deployments/=eu-west-2`. The fix braces the interpolation:

```powershell
return "https://${region}.console.aws.amazon.com/codesuite/codedeploy/deployments/${Id}?region=${region}"
```

Synthetic verification with `Id = d-TEST12345`, `region = eu-west-2`:

| Expression | Result |
|---|---|
| Old | `.../deployments/=eu-west-2` |
| New | `.../deployments/d-TEST12345?region=eu-west-2` |
| Expected | `.../deployments/d-TEST12345?region=eu-west-2` |
| Match | **PASS** |

The Lambda alias and CloudWatch alarm URLs were also braced for consistency. The
change is in the working tree and **not committed**, per the request.

---

## 4. Observer read-policy (applied by Codex)

**Status (2026-10-20):** Codex applied and verified the two observed read calls as
the inline policy `DemoScreenshotObservedReadGaps` on `FranklinWhyte`. OpenCode
did not modify IAM.

`DemoScreenshotReadOnly` is the observer's customer-managed read policy.

**Observed missing calls from the last capture:**

- `lambda:GetProvisionedConcurrencyConfig` — Lambda alias page.
- `codedeploy:ListDeploymentInstances` — CodeDeploy deployment page.

**Applied inline policy (record):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ObservedConsoleReadGaps",
      "Effect": "Allow",
      "Action": [
        "lambda:GetProvisionedConcurrencyConfig",
        "codedeploy:ListDeploymentInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

**Pending observation — do not add yet.** The Lambda-specific CodeDeploy target
view may also call `codedeploy:ListDeploymentTargets`,
`codedeploy:GetDeploymentTarget` or `codedeploy:BatchGetDeploymentTargets`.
Verify the exact AccessDenied action in the next observer session before adding
them.

**Do not add** `codebuild:ListProjects`. It appears in the generic “Go to
resource” widget; navigate directly to CodeDeploy instead of granting unrelated
CodeBuild access.

Attach to the observer user only, after review. Do not modify the policy as part
of this request.

---

## 5. Existing run — verified identifiers

From the raw artifacts, not from the screenshots:

| Item | Value | Source |
|---|---|---|
| Run ID | `20261020-0251` | `run-meta.txt`, directory |
| Healthy deployment | `d-8YABO1E6K` | `codedeploy-deployments.json` (status observed live; not in raw JSON) |
| Faulty deployment | `d-9PAMKTD6K` | `deployment.json` |
| Faulty status | `Stopped` | `deployment.json` |
| Faulty complete time | `2026-10-20T03:11:57+01:00` | `deployment.json` |
| Rollback deployment | `d-YGITAAD6K` | `deployment.json` `rollbackInfo` |
| Alias at capture | `FunctionVersion = 2`, `RoutingConfig = null` | `lambda-alias.json` |
| Versions at capture | 1, 2, 3 | `lambda-versions.json` |
| Alarm at capture | `OK` at `03:13:48` | `alarms.json` |
| Load | 3,601 requests: 3,479 × 200, 120 × 500, 2 × 429 | `load.json` |
| Post-rollback plan | “No changes…” | `post-rollback-plan.txt` |
| Teardown | 25 resources destroyed | `terraform-destroy.txt` |

The deployment list also contains earlier failed attempts (`d-V33TMKD6K`,
`d-HKG8I4E6K`, `d-EMSZC57W7`, `d-ZYVI5SD6K`). They are not the experiment; do not
label them as the healthy or faulty deployment.

The raw `alarms.json` was captured **after** recovery and shows `OK`, not `ALARM`.
Screenshot 04 is the only record of the `ALARM` state.

---

## 6. Recoverability audit

| View | Raw artifact | Can it be recovered without a new run? |
|---|---|---|
| Baseline alias v1 / API response | `baseline-load.json`; response was checked live, not saved | Text summary only; a valid console/response capture needs a new run |
| Healthy deployment v2 | `codedeploy-deployments.json` (ID only) | ID yes; **status is not artifact-backed**; live page needs a new run |
| Faulty canary v3 | `deployment.json`, `lambda-versions.json`, `load.json` | Rollback linkage and versions yes; live canary/weights page needs a new run |
| Alarm `ALARM` | `alarms.json` is `OK`; screenshot 04 | **No** — 04 is the only proof; a fresh live alarm page needs a new run |
| Automatic rollback | `deployment.json` rollback ID/message; alias v2 | Linkage yes; live CodeDeploy page needs a new run |
| Recovery | `lambda-alias.json` v2; `load.json` 200s | Text yes; live alias page needs a new run |
| No drift | `post-rollback-plan.txt` | **Yes** — a terminal/Notepad capture of the actual output can be produced now |
| Teardown | `teardown.txt`, `terraform-destroy.txt` | Text yes; needs commands, region, timestamp and exit status. A budget console capture is possible now |
| Budget exception | Budget still exists | **Yes** — can be captured now |
| IAM observer policies | Still exist | **Yes** — can be captured now, if needed |

Because the stack was destroyed, Lambda, CodeDeploy, API Gateway and log-group
console pages no longer exist. Historical console views cannot be recreated. Do not
fabricate or label reconstructed screens as live captures.

---

## 7. New-run capture checkpoints

If a fresh live capture is approved, use a **new run ID** (for example
`20261021-<HHMM>`) and label every file with it. Do not mix it with
`20261020-0251`.

| # | Checkpoint | Must show |
|---|---|---|
| 01 | Baseline | Lambda alias `live` → v1; API response `version=baseline`; timestamp |
| 02 | Healthy | CodeDeploy deployment Succeeded; target v2; alias at v2 |
| 03 | Faulty canary | Deployment InProgress; 10% canary; alias weights to v3; versions 1/2/3 |
| 04 | Alarm | Named alarm in `ALARM`; `Errors` metric; alias dimension; 2-of-2; UTC window |
| 05 | Rollback | Original deployment `Stopped`; rollback deployment ID; alias back at v2 |
| 06 | Recovery | Alias v2; healthy responses with timestamps; load summary |
| 07 | No drift | Actual `terraform plan` output, command and exit status |
| 08 | Cleanup | Service-by-service checks, region, timestamp, exit status, and the retained budget exception |

Before the run, confirm the observer session and read permissions. The run
requires user approval for spend; the budget remains active at USD 5/month.

---

## 8. Evidence handling

- Preserve raw PNGs untouched. They currently sit **untracked** in
  `docs/aws-lambda-safe-releases/`; do not commit them there. Move them to a
  gitignored raw folder or keep them local.
- They show the account number in the console header; several also show it in
  ARNs or error text. Redact all occurrences in publication copies.
- Publication copies belong under
  `public/evidence/aws-lambda-safe-releases/`, with a clear run label and a note
  on which capture is historical.
- Do not publish screenshots 01–03 or 05–07 as evidence of the successful run.
- Do not present screenshot 04 as proof of causality on its own; pair it with the
  deployment rollback artifact and the load summary.
- Do not fabricate, recreate or annotate a console screenshot as if it were live.

---

## 9. Approval gates and next actions

**Not authorised by this request:** OpenCode deployment, IAM change, credential
change, commit, publication.

**Status (2026-10-20):** the capture rerun is authorised up to USD 5, with
teardown after the run. OpenCode implemented and locally validated capture mode
(§10) but has not deployed anything. Codex owns browser capture and will run the
orchestrator.

1. **Codex:** run the capture-mode invocation in §10 and create each marker after
   the screenshot is saved.
2. **OpenCode:** capture mode implemented and locally validated (§10); URL fix
   done (uncommitted).
3. **Codex/user:** observer policy confirmed applied (§4).
4. If the run is executed: label it with the new run ID, capture all checkpoints,
   then run Gate 2 against the new evidence set.

Until the observer session and permissions are ready, no capture experiment
should start.

---

## 10. Headless capture mode (file checkpoints)

`run-live.ps1` now supports a file-checkpoint mode for Codex to orchestrate.
In this mode it does **not** open Windows Forms, Notepad or a browser. It writes
one JSON per stage and waits for a stage-specific `.continue` marker that Codex
creates after saving the screenshot.

### Exact invocation (Codex)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\koate\development\gcp-architect-blog\examples\aws-lambda-safe-releases\scripts\run-live.ps1" `
  -CaptureMode -ApproveSpend -DestroyAfter `
  -RunId 20261021-HHMM `
  -CaptureDir "C:\Users\koate\development\gcp-architect-blog\examples\aws-lambda-safe-releases\evidence\raw\20261021-HHMM\capture" `
  -MarkerTimeoutSeconds 1800
```

- `-ApproveSpend` is required in capture mode (no dialog). `-SkipApproval` also
  counts as approval.
- `-DestroyAfter` is the explicit teardown authorisation: after stage 09 the
  script runs `terraform destroy`, restores the tag-scoped budget
  (`aws_budgets_budget.demo`) and runs `verify-teardown.sh`. On failure it also
  attempts best-effort teardown.
- Without `-DestroyAfter`, capture mode retains resources (deterministic default).
- Use a new run ID; do not mix it with `20261020-0251`.
- `-CaptureDir` defaults to `evidence/raw/<runId>/capture`.
- Interactive defaults are unchanged when `-CaptureMode` is omitted.

### Marker layout

For each stage the script writes `<stage>.json` and waits for `<stage>.continue`.

| Stage ID | JSON | Marker | Screenshot | Capture required |
|---|---|---|---|---|
| `01-baseline` | `01-baseline.json` | `01-baseline.continue` | `01-baseline.png` | yes |
| `02-healthy` | `02-healthy.json` | `02-healthy.continue` | `02-healthy-candidate.png` | yes |
| `03-canary` | `03-canary.json` | `03-canary.continue` | `03-canary-routing.png` | yes |
| `04-alarm` | `04-alarm.json` | `04-alarm.continue` | `04-alarm.png` | yes |
| `05-rollback` | `05-rollback.json` | `05-rollback.continue` | `05-rollback.png` | yes |
| `06-recovery` | `06-recovery.json` | `06-recovery.continue` | `06-recovery.png` | yes |
| `07-no-drift` | `07-no-drift.json` | `07-no-drift.continue` | `07-no-drift.png` | yes |
| `08-evidence` | `08-evidence.json` | `08-evidence.continue` | — | no (ack only) |
| `09-cleanup` | `09-cleanup.json` | `09-cleanup.continue` | `08-cleanup.png` | yes |
| `09-retained` | `09-retained.json` | `09-retained.continue` | — | no (retain path) |

Rules:

- Create the marker **only after** that stage's screenshot is saved.
- The script deletes the marker when it continues, so a marker cannot be reused.
- Stale `*.continue` markers are cleared at startup.
- Each JSON contains `stageId`, `title`, `message`, `url`, `screenshotName`,
  `captureRequired`, `jsonPath`, `markerPath`, `emittedAtUtc` and a `context`
  object (deployment IDs, versions, plan text, teardown output, etc.).
- A per-stage timeout writes `failure.json`, exits **2**, and with
  `-DestroyAfter` attempts teardown. `-MarkerTimeoutSeconds` defaults to 1800.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (all stages continued; teardown succeeded if requested) |
| 1 | Aborted before the experiment (e.g. spend approval not granted) |
| 2 | Runtime failure or marker timeout (`failure.json` written) |

### Local, no-cloud test

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "C:\Users\koate\development\gcp-architect-blog\examples\aws-lambda-safe-releases\scripts\test-capture-checkpoints.ps1"
```

This runs `run-live.ps1 -CaptureMode -SelfTest`, creates the nine markers itself,
and asserts: 9 JSONs, all markers consumed, exit 0; plus a timeout case asserting
exit 2 and `failure.json`. It makes **no AWS, Terraform or bash calls**.

Validated 2026-10-20: **ALL CAPTURE-MODE LOCAL CHECKS PASSED**.

### Not performed

No deployment, AWS mutation, IAM change, credential change, commit or publication.
This section documents the mode; Codex runs it.
