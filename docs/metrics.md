# Metrics — GCP/Platform + AI repos

Baseline captured **2026-10-09**. Revisit **2026-11-07** (≈4 weeks) and track
weekly in the sheets below. Repos: the 4 pinned ones —
`gcp-proof-platform`, `multi-agent-optimizer`, `agentic-rag-hybrid`,
`cloud-run-ai-golden-path`.

## 1. Repo / public metrics (GitHub API)

| Repo | Stars | Forks | Watch | OpenIss | Size(KB) | Lang | Created | Pushed | Views(7d) | Clones(7d) |
|---|---|---|---|---|---|---|---|---|---|---|
| gcp-proof-platform | 0 | 0 | 0 | 0 | 72 | Python | 2026-09-29 | 2026-09-30 | 2 / 1 | **117 / 69** |
| multi-agent-optimizer | 0 | 0 | 0 | 0 | 18 | Python | 2026-10-08 | 2026-10-08 | 0 / 0 | 0 / 0 |
| agentic-rag-hybrid | 0 | 0 | 0 | 0 | 0 | Python | 2026-10-09 | 2026-10-09 | 0 / 0 | 0 / 0 |
| cloud-run-ai-golden-path | 0 | 0 | 0 | 0 | 7 | HCL | 2026-10-08 | 2026-10-08 | 0 / 0 | 0 / 0 |

`Views`/`Clones` format: count / unique. Three repos are fresh — zero is the
expected baseline; `gcp-proof-platform` already shows 117 clones (shared
earlier) — keep it as the flagship signal.

## 2. Engineering metrics (local run)

| Repo | Tests | Coverage | Statements | LOC | Eval gate |
|---|---|---|---|---|---|
| multi-agent-optimizer | 19 | 86% | 305 | 752 (11 files) | 2/2 golden ✓ |
| agentic-rag-hybrid | 6 | 97% | 158 | 305 (9 files) | 5/5 golden ✓ |
| cloud-run-ai-golden-path | 3 | 89% | 54 | 111 (5 files) | - |
| gcp-proof-platform | run in Cloud Build (py/node/dotnet) | - | - | py 613 · ts 106 · cs 223 · tf 686 | eval-gate ≥0.80 in CI ✓ |

## 3. Runtime metrics (gcp-proof-platform) — 2026-10-09 baseline

**Current state: the always-on stack is DOWN.** Findings from GCP:

| Item | Observed | Implication |
|---|---|---|
| Compute VM | **0 instances** | Stack was torn down (`down.ps1`); VM absent → no SLO/uptime load |
| Cloud Run job (`eval-to-bq`) | **0 jobs/executions** in us-central1 | Pipeline not deployed right now |
| BigQuery `ai_platform.eval_reports` | **dataset not found** | Table/dataset missing (or never created) |
| Cloud Build | 8 builds (1 **SUCCESS** 2026-09-30, 7 **FAILURE**) | Last successful build 2026-09-30; pipeline failing since |
| Budgets (billing account) | all `currentSpend = 0` (incl. `t-*` £20, blog £2, demo £5) | **£0 actual spend this period** while the stack is down |
| Uptime / availability SLO | no uptime check data | SLO is dormant with the VM down |

**To make runtime metrics real:** run `scripts\up.ps1` on the platform, re-run
`gcloud run jobs execute eval-to-bq`, then capture: SLO/error budget (99%/30d),
uptime success ratio, BigQuery rows loaded, Cloud Build pass rate, and cost vs
the £15/$20 budget. Until then, "£0 spend / no load" is the honest number —
and Cloud Build's last FAILURE is the thing to fix first.

## 4. Outcome metrics (weekly, manual)

| Week | LinkedIn search appearances | Profile views | Posts | Followers | Inbound msgs | GitHub stars | Clones(wk) |
|---|---|---|---|---|---|---|---|
| 2026-W41 | 4 | 0 | 0 | 0 | - | 0 | 117 |
| 2026-W42 | | | | | | | |

## 5. Suggestions (based on the baseline)

1. **Publish the 4 pins now** (browser) to put the flagship repos on the profile landing.
2. **Drive traffic with Blog 3** (AI/multicloud post citing `agentic-rag-hybrid` +
   `cloud-run-ai-golden-path`) — repos currently have 0 views because nothing
   points at them yet.
3. **Add a coverage wall in CI** (threshold per repo) — we already compute it; make
   it a gate (e.g., ≥80%).
4. **Add GitHub badges** (CI status, coverage, eval gate) to each README — cheap,
   visible quality signals.
5. Keep `gcp-proof-platform` the anchor; 117 clones shows the shared link worked.
6. Re-check traffic only after 2–4 weeks of real distribution — repo views need a
   traffic source.