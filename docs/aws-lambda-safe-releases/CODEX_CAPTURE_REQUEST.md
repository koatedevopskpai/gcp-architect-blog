# Codex capture coordination request to OpenCode

20 October 2026. User explicitly asks Codex and OpenCode to work together on screenshots. OpenCode remains lead; Codex owns browser capture.

Read CODEX_SCREENSHOT_REVIEW.md and STATUS.md first. Existing run: 20261020-0251. Reuse valid existing artifacts; do not describe capture failures as experiment failures. Baseline v1 -> healthy v2 -> faulty v3, rollback target v2. Default outcome remains teardown, keeping/reinstating the budget.

## Lead preparation requested
1. Fix CodeDeploy URL interpolation in run-live.ps1 using ${Id}?region=${region} and braced region. Verify generated navigation with synthetic IDs.
2. Prepare narrow additions to the observer read policy for actual missing API calls. Do not apply IAM changes without reviewed authorisation. Do not add unrelated CodeBuild access merely to quiet generic Go to resource widgets.
3. Audit existing raw deployment, alarm, alias, load, no-drift and cleanup artifacts. State which historical console views can be recovered and which require a new live capture.
4. Write SCREENSHOT_COORDINATION.md with readiness, exact deployment IDs, navigable views, run IDs and capture checkpoints. Historical IDs in current STATUS: healthy d-8YABO1E6K, faulty d-9PAMKTD6K, rollback d-YGITAAD6K. Verify against artifacts; region eu-west-2. Do not expose account/email in shareable docs.
5. No automatic rerun, IAM change, credential change, commit or publication from this request. Wait until the observer session and read permissions are ready before a new capture experiment. Label any new run separately.

## Codex availability/blockers
The user has FranklinWhyte signed into Edge. Edge is not currently available to Codex browser tools; Chrome is connected, but requires a separate user sign-in. Need Edge connection or user login in the already-open Chrome AWS tab before console capture.

Direct OpenCode continuation from this Codex environment was attempted using the installed CLI and existing session ses_ec12b77a3ffebq6Kejrq4LVVY4. Run command fails with EPERM on entering the repository, even after read/runtime path permissions; no message delivery or OpenCode execution is claimed. This file is a shared handoff, not a live response from OpenCode.

## Capture outputs
01 actual baseline alias/version and response; 02 healthy deployment success; 03 faulty canary weights/versions; 04 alarm; 05 linked automatic rollback and v2 target; 06 healthy recovery; 07 actual Terraform plan output; 08 contextual service cleanup verification and budget exception. Preserve raw originals and redact publication copies, including account IDs in header and ARNs. Do not fabricate or label reconstructed screens as live historical captures.
