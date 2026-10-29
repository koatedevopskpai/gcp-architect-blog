# AWS screenshot review - 20 October 2026

Reviewed eight PNGs in C:\Users\koate\development\gcp-architect-blog\docs\aws-lambda-safe-releases. This is a screenshot/evidence review, not a verdict on the underlying live experiment.

| File | Verdict | Finding and replacement target |
|---|---|---|
| 01-baseline.png | Replace | Lambda alias general-configuration page shows AccessDenied for lambda:GetProvisionedConcurrencyConfig. No target version or successful baseline response is visible. Capture alias live -> actual baseline version plus API response/version marker. |
| 02-healthy-candidate.png | Replace | InvalidDeploymentIdException; deployment ID displayed as =eu-west-2. No successful deployment/version shown. Capture actual healthy deployment Succeeded, target v2 and alias routing. |
| 03-canary-routing.png | Replace | Actual deployment URL but page blocked by codedeploy:ListDeploymentInstances denial. No canary weights/version targets visible. Capture actual v2/v3 split and deployment in progress, or supporting exact run artifacts labelled as such. |
| 04-alarm.png | Keep as raw; redact and improve presentation if possible | Correct named alarm, In alarm, Errors metric, alias dimension, 2-of-2 rule and visible UTC last-update time. Narrow the graph window to the incident to improve readability; capture history separately if available. Does not alone prove CodeDeploy caused rollback. No actions shown is not proof of broken configuration: CodeDeploy can monitor the alarm state. |
| 05-rollback.png | Replace | Same CodeDeploy read-permission failure. No rollback status, reason, linked deployment or restored target. Capture original deployment and automatic rollback linkage; restored target is healthy v2, not baseline v1. |
| 06-recovery.png | Replace | Lambda permission error again; does not show v2 routing or successful responses. Capture restored alias and timestamped healthy version responses. |
| 07-no-drift.png | Replace | Lambda console page cannot establish Terraform drift. Capture actual post-rollback-plan.txt or command output with no-change result, run context and command/exit status. |
| 08-teardown.png | Supplement or replace | Text file shows section headings with no resources listed; consistent with empty matches but lacks commands, region, timestamp, error/exit status and context. Empty output must not be treated as independently verified complete cleanup. Capture a verified service-by-service cleanup summary and the retained budget exception. |

## Confirmed orchestration bug

examples/aws-lambda-safe-releases/scripts/run-live.ps1 line 187 uses:
https://$region.console.aws.amazon.com/codesuite/codedeploy/deployments/$Id?region=$region

Local PowerShell reproduction with a synthetic deployment ID produced /deployments/=eu-west-2, matching screenshot 02. Bracing the interpolation produced the correct synthetic URL:
https://${region}.console.aws.amazon.com/codesuite/codedeploy/deployments/${Id}?region=${region}

No script edited during this review. OpenCode should fix and verify generated navigation links before another live run.

## Observer permissions and capture routing

Visible missing calls: lambda:GetProvisionedConcurrencyConfig and codedeploy:ListDeploymentInstances. Investigate whether the Lambda-specific CodeDeploy target view also requires ListDeploymentTargets/GetDeploymentTarget/BatchGetDeploymentTargets, using actual observed denial/API behaviour rather than speculative grants. codebuild:ListProjects denial appears in the generic Go to resource widget; navigate directly to CodeDeploy and do not grant unrelated CodeBuild access just to hide the widget error. Prepare narrowly scoped read-only changes and review before applying.

## Publication

Screenshots 01-07 show the account number in the top-right console header; several also expose it in ARNs/error text. Redact all occurrences before publication according to the project brief. Preserve original raw captures; create separately labelled publication copies. No image edited, redacted or fabricated in this review.

## Before paying for a rerun

Raw run folder exists: examples/aws-lambda-safe-releases/evidence/raw/20261020-0251. It contains deployment/alarm/alias/load artifacts, post-rollback-plan.txt, teardown.txt and run-log.txt, among other files. Contents were not audited in this screenshot review. Have the lead inspect those artifacts first: historical deployment pages and the plan/cleanup captures may be recoverable without replaying the entire experiment. If a fresh live canary capture is required, use a new run ID and do not mix runs without explicit labels.

Next owner: OpenCode for URL/observer-policy proposal and evidence audit; Codex or user for corrected screenshots. Do not publish current set as a successful full rollback narrative.
