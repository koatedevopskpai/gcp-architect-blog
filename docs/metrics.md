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

## 3. Runtime metrics (gcp-proof-platform)

### 2026-10-09 — stack restored, metric run

| Metric | Value |
|---|---|
| VM | `gcp-proof-platform-dev-app`, **e2-small**, `us-central1-a`, RUNNING |
| External IP | 136.80.4.30 |
| Gateway health | **60/60 success** — `http://136.80.4.30:3002/health` → 200 |
| Health latency | avg **157 ms**, p95 **175 ms**, min 139 ms, max 390 ms |
| Downstream services | `rag-api` ok, `dotnet-ingest` ok (from gateway `/health`) |
| Uptime check | `gateway health` (STATIC_IP_CHECKERS, `/health:3002`) active |
| Time to serve | ~255 s from VM start (repo clone + docker compose build) |

### 2026-10-09 — CI fixed + eval pipeline run

| Build metric | Value |
|---|---|
| Cloud Build (latest) | **SUCCESS**, **6m40s**, tag `manual-1009` |
| Pipeline | now builds + Trivy-scans **5 images** (added `eval-to-bq`) |
| Cloud Run job `eval-to-bq` | execution `eval-to-bq-v2cjz` → **SUCCESS** (1 ok / 0 fail) |
| BigQuery `ai_platform.eval_reports` | **4 rows loaded**, last `2026-10-09` |

Fixes applied (platform repo `20e6a83`): cloudbuild builds `eval-to-bq`
(repo-root context) and pushes both `:<tag>` and `:latest`; the `mlops/bigquery`
Dockerfile upgrades base packages; `.trivyignore` records accepted base-image
perl CVEs (documented).

**Remaining (minor):** WIF pool drift (`google_iam_workload_identity_pool.github`
exists in GCP, not in state → 409) and the Terraform *budget* resource hits the
user-ADC quota-project error (manage budgets via `gcloud`, as done for the blog).

Cost note: VM accrues ~$12–14/mo (~$0.017/hr); budgets still read £0 (billing
lags ~a day).

> **✅ TORN DOWN 2026-10-10:** `terraform destroy` removed **29 resources**
> (VM, static IP, subnetwork, VPC, service accounts). VM confirmed gone; cost
> back to ~$0/month.
>
> **24h window result:** gateway stayed **HTTP 200** throughout; **1** `eval-to-bq`
> execution (`eval-to-bq-v2cjz`, success); BigQuery `eval_reports` = **4 rows**
> (last 2026-10-09); spend **£0**. Lesson: the **scheduler** resource wasn't
> applied, so there was no automated overnight run — apply it for daily runs.

### Prior baseline (2026-10-09, before restore)
Stack was down: 0 instances, no `eval-to-bq` job, no BigQuery dataset,
Cloud Build 1/8 success, £0 spend.

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