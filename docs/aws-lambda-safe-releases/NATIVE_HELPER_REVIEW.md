# Native capture helper — parity review

Reviewed: 2026-10-20 · Reviewer: OpenCode (lead) · Read-only review
Helper: `examples/aws-lambda-safe-releases/scripts/native-capture-helper.py`
Compared with: `scripts/deploy.sh`, `scripts/collect-evidence.sh`,
`scripts/verify-teardown.sh`, `scripts/common.sh`
Runtime note: `docs/aws-lambda-safe-releases/CODEX_CAPTURE_RUNTIME_NOTE.md`

**Scope.** No live script was edited, no AWS/Terraform command was run, and no
IAM/credential/commit/publish action was taken. Codex is capturing run
`20261020-030749-native-capture`.

**Verdict.** The helper is a credible native replacement for the three capture
helpers: same AWS operations, same AppSpec shape, same deployment configs, and
the `-NativeHelpers` path correctly propagates exit codes. It is **not yet at
full parity**. Four material gaps should be resolved before the handoff treats
it as equivalent.

---

## Material issues

| # | Area | Gap | Impact |
|---|---|---|---|
| 1 | `collect-evidence` | **Does not write `run-meta.txt`** (run_id, timestamp_utc, region, commit, function_name, alias_name, deployment_id). | Loses provenance the shell always records; `SCREENSHOT_COORDINATION.md` §5 cites `run-meta.txt` as a source. Evidence is not self-describing without it. |
| 2 | `verify-teardown` | **Omits the `resourcegroupstaggingapi get-resources` tag sweep** the shell performs first. | `all_clear` is a *service sweep only*. Tagged resources that the eight service checks miss will not be detected. The runtime note already says "service sweep", but the JSON field says `all_clear` — ambiguous. |
| 3 | `verify-teardown` | **Fails (non-zero) when leftovers are found**; the shell only prints them. | Under `Invoke-Teardown`, a leftover turns a successful destroy into a thrown error. `$script:TeardownDone` is set *after* verify, so the failure handler retries destroy + budget + verify, then exits 2. Fail-closed may be the right policy, but it must be a deliberate decision and the exit semantics documented. |
| 4 | `collect-evidence` | **No longer tolerates failure** of `deploy get-application` / `get-deployment-group` (shell uses `|| true`). | Under a least-privilege observer/deploy role these calls can fail; evidence collection would abort *after* the experiment. Shell deliberately continued. Restore tolerance (write a marker/empty file) or document the stricter intent. |
| 5 | AWS resolution | **Ignores `AWS_BIN`** (shell `resolve_aws` honours it) and calls literal `"aws"`. | Works on this host, but loses the documented override and portability path. Low risk now, material if PATH differs. |

## Parity matrix

### `deploy.sh` → `deploy()`

| Behaviour | Shell | Native | Verdict |
|---|---|---|---|
| Releases | baseline/healthy/faulty | same | parity |
| `--wait` | yes | yes | parity |
| `--config NAME` override | supported | **rejected** | minor gap |
| Default config | AllAtOnce / Canary10Percent10Minutes | same | parity |
| Build + S3 upload | `build.py`, `s3 cp`, WSL path conversion | `sys.executable build.py`, native path | parity on native |
| Current/target version | get-alias + update-function-code --publish | same | parity |
| Wait for function update | not waited | `lambda wait function-updated-v2` | divergence (safer, slower) |
| AppSpec | `build/appspec-<release>.yaml`, persisted | in-memory; writes `build/native-deployment-<release>.json` | minor provenance gap |
| Create deployment | `--revision` JSON | `--cli-input-json` | equivalent |
| stdout | `current_version`, `target_version`, `deployment_id`, `config` | same minus `config` | minor (not parsed by run-live) |

### `collect-evidence.sh` → `collect()`

| Behaviour | Shell | Native | Verdict |
|---|---|---|---|
| Output dir | `evidence/raw/<RUN_ID>/` | same | parity |
| `run-meta.txt` | written (incl. commit) | **missing** | **material** |
| lambda function/alias/versions | yes | yes | parity |
| CodeDeploy app/group/deployments | yes, app/group tolerant | yes, **intolerant**; app name uses `FUNCTION_NAME` not `CODEPLOY_APP` | **material** (tolerance) / minor (app name) |
| alarms / apis / log groups | yes | yes | parity |
| deployment.json if `DEPLOYMENT_ID` | yes | yes | parity |
| stdout | `wrote <dir>` | same | parity |

### `verify-teardown.sh` → `verify()`

| Behaviour | Shell | Native | Verdict |
|---|---|---|---|
| Tag sweep (`resourcegroupstaggingapi`) | yes | **missing** | **material** |
| Lambda / CodeDeploy / alarms / API GW | yes | yes | parity |
| IAM policies (Local) / IAM roles | yes | yes | parity |
| Log groups / S3 buckets | yes | yes | parity |
| Output | human tables | JSON + `cleanup-verification.json` | improvement |
| Leftover handling | print only, exit 0 | **raise, non-zero** | **material** (see #3) |
| Retained budget | not in checks | labelled `retained_exception` | improvement |
| `RUN_ID` artifact | none | optional `cleanup-verification.json` | improvement |

## Minor / cosmetic

- `Invoke-CheckedBash` error text still says **"bash command failed"** in native mode.
- `parse_request` uses `shlex.split` (POSIX); a value containing a backslash would
  be mangled. Current values (region, names, run ID) are safe.
- `env["ARTIFACT_BUCKET"]` / `env["RUN_ID"]` raise `KeyError` rather than the
  shell's explicit `${VAR:?}` message.
- `all_clear = not remaining` treats a `null` query result as clear (correct for
  AWS CLI, but assert it returns `[]`, not `null`).
- Native deploy does not print `config=`, so a future consumer parsing it would
  break.
- No `--no-cli-pager` issue: helper adds it consistently.

## Recommendations (ordered)

1. **Write `run-meta.txt`** in `collect()` with the same seven fields (commit may
   be `unknown` when git is unavailable). *Material.*
2. **Add the tag sweep to `verify()`**, or rename the field to
   `service_sweep_all_clear` and state the limitation in the JSON and the doc.
   *Material.*
3. **Decide verify failure semantics.** If fail-closed is intended, document it
   and make `Invoke-Teardown` treat a verified-leftover result distinctly from a
   destroy failure (avoid the retry loop). If report-only is intended, catch and
   record instead of raising. *Material.*
4. **Restore tolerance** for `get-application` / `get-deployment-group`, matching
   the shell's `|| true`, or record why the native path is stricter. *Material
   under least privilege.*
5. Honour `AWS_BIN` (and optionally `PYTHON_BIN`) for parity and portability.
6. Optional parity polish: support `--config`, print `config=`, persist the
   AppSpec YAML, fix the "bash command failed" wording.

## Handoff note

Per the runtime note, integrating `-NativeHelpers` into the handoff
(`SCREENSHOT_COORDINATION.md` §10) is **deferred until after** Codex's current run.
This review is documentation only; the live scripts were not modified.

## Safety

No AWS or Terraform command was executed during this review. No IAM, credential,
commit or publish action was taken. Codex remains the browser operator and
orchestrator for run `20261020-030749-native-capture`.
