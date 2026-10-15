# Blog 4 pre-draft — SLOs for Cloud Run (Tier 1, live run)

> Status: **pre-draft checklist**. Target: `sre-reliability` pillar B, id `004`,
> title **"SLOs for Cloud Run: latency, availability, multi-window alerts."**
> Queue position: next after Blog 3 (production RAG). Proof tier **1** (live run
> + evidence). Series: `cloud-run-golden-path`, `seriesOrder: 2` — continues
> Blog 2, which *deployed* SLOs; this post goes deep on *operating* them.

Backlog source: `content-ops/backlog.yaml` id `003` (score **41.67**, the top
unpublished, non-org-gated topic).

---

## 1. Prerequisites & decisions (settle before writing)

- [ ] **Decision: where the tier-1 demo runs.**
  - **A (recommended):** reuse the shared demo project `gcp-architect-demo-2026`
    (the golden-path project from Blog 2) — everything is `blog4-*`-prefixed with
    `default_labels`, so it's attributable and tear-down-able.
  - B: a fresh throwaway project — cleaner isolation, extra bootstrap toil.
- [ ] Region `us-central1`.
- [ ] **Decision: how the SLO gets traffic.** SLOs are meaningless without
  requests. Options:
  - **A (recommended):** a short `hey`/`vegeta` load burst against a *togglable*
    failure endpoint (below) so we can capture a real **burn** — not just a green
    dashboard.
  - B: Cloud Scheduler hitting `/health` — cheap but only proves "up", never
    "burning".
- [ ] **Decision: the failure lever.** To show burn-rate alerting actually
  firing, the demo service needs a way to fail on demand (e.g. `GET /fail?code=500`
  or `?sleep=2s`). This is the differentiator vs Blog 2 — see §2.
- [ ] Target cost of the live run: **< $1**; destroy same day.

## 2. Angle — what makes this post different from Blog 2

Blog 2 *created* an availability + latency SLO and a single 14.4× burn alert.
This post is the **operating manual**:

- **The burn-rate math** — why multi-window multi-burn-rate beats a single
  threshold, with the Google SRE workbook table (14.4× fast / 6× medium / 1× slow).
- **A real burn** — induce failures on purpose and capture the alert firing, the
  incident, and the recovery. Evidence, not a screenshot of a healthy SLO.
- **Alert hygiene** — page vs ticket tiers, `duration`/`combiner` semantics, and
  the "why is this alert noisy" checklist.
- **Error budget policy** — what the team *does* when the budget is spent
  (freeze, roll back, prioritise reliability).

## 3. Companion example: `examples/slos-for-cloud-run/`

- [ ] `main.tf`:
  - **APIs enabled** (`google_project_service`: run, artifactregistry,
    monitoring, logging, iam, cloudbuild) so the example stands alone.
  - Cloud Run **service** (hello/nginx image) with a **fault-injection
    endpoint** (env-driven, e.g. `FAIL_RATE`, `LATENCY_MS`) — min 0 / max 5,
    CPU boost, dedicated runtime SA.
  - **Two-phase deploy** — `-target=google_artifact_registry_repository.images`
    first, push the image, then full apply.
  - `google_monitoring_service` (basic_service `CLOUD_RUN`).
  - **Availability SLO** (99.9% / 30d) and **latency SLO** (99% under 1s / 30d)
    (protobuf duration: whole seconds — sub-second thresholds are rejected).
  - **Three-tier multi-window multi-burn-rate alerting** (the SRE workbook set):
    - fast burn — 14.4× over **5m** AND **1h** → **page**
    - medium burn — 6× over **30m** AND **6h** → **page**
    - slow burn — 1× over **6h** AND **24h** → **ticket**
  - Notification channels: email page + (optional) Slack; a "ticket" channel.
  - A **dashboard** (`google_monitoring_dashboard`) with request rate, 5xx error
    rate, p50/p95/p99 latency, and instance count (SLO burn lives on the
    Monitoring → SLOs page).
- [ ] `loadgen/`:
  - `loadgen.sh` — `hey`/`vegeta` burst driver with a `FAIL_RATE` ramp.
  - Optional `cloud-scheduler.tf` for a background trickle.
- [ ] `capture-evidence.sh` / `capture-evidence.ps1` — drives the burn and writes
  the CLI evidence into `public/evidence/slos-for-cloud-run/` (`service-url.txt`,
  `health-check.txt`, `service-describe.json`, `revisions.txt`,
  `alert-policies.json`, `load-run.txt`, `cost-note.txt`), then points at the
  screenshot drop zone.
- [ ] `public/evidence/slos-for-cloud-run/SCREENSHOTS.md` — console-only
  screenshots (SLO burn, fast-burn **firing**, recovery, latency, dashboard).
- [ ] `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, `README.md`
  (mirror the golden-path example's shape).

## 4. Post outline (Qiita-style)

1. **Overview** — an SLO is not a dashboard; it's a contract with an error budget
   and a policy for spending it.
2. **The problem this solves** — "green dashboard, unhappy users": uptime checks
   pass while the *user experience* degrades. Pain table.
3. **Architecture** — Mermaid: client → Cloud Run → Cloud Monitoring (SLI → SLO
   → burn-rate → notification), loadgen + fault injection to the side.
4. **Prerequisites** — project, billing, gcloud, `hey`, a real alert email.
5. **Steps**
   - Define the SLIs (availability + latency) — what's counted, what's excluded.
   - Create the service + SLOs (Terraform).
   - **Multi-window multi-burn-rate alerting** — the table, the window pairs, the
     `combiner`/`duration` gotchas.
   - **Induce a burn** — flip `FAIL_RATE`, watch the fast-burn alert fire, watch
     it resolve; capture it.
   - **Error-budget policy** — what to do when the budget is gone.
6. **Extras** — ticket vs page routing, burn-rate math derivation, custom SLI via
   logs/metrics, SLO for a job (non-request).
7. **SLO / Security / FinOps notes** — cost of the run, why no VM was needed,
   alert-noise trade-offs.
8. **Reproduce** — commands + link to `examples/slos-for-cloud-run`.
9. **Well-Architected mapping** — Reliability + Operational Excellence.
10. **References** — Google SRE Workbook ch. 5 (Alerting on SLOs), Cloud
    Monitoring SLO docs, Blog 2 (golden path), the Qiita SLO article.

## 5. Tier-1 evidence to capture (drop into `public/evidence/slos-for-cloud-run/`)

- [ ] `terraform plan/apply` output (redacted)
- [ ] Live URL + `/health` HTTP 200 screenshot
- [ ] SLO overview: availability + latency SLO burn (Cloud Monitoring)
- [ ] **Fast-burn alert firing** screenshot (with the incident window timestamped)
- [ ] **Recovery** screenshot (alert auto-resolves; error budget recovers)
- [ ] Latency metrics: p50/p95/p99 during the `LATENCY_MS` experiment
- [ ] Dashboard screenshot (request rate, latency, burn)
- [ ] **Cost line** for the run period (billing/cost export; must be < $1)
- [ ] Tear-down confirmation (`terraform destroy`)

## 6. Verification gates before publish

- [ ] `npm run build` passes with the new post
- [ ] Screenshots/metrics actually present (no "trust me" claims)
- [ ] The alert **actually fired** in the captured window (not just configured)
- [ ] Cost recorded; VM-free (no always-on compute)
- [ ] Companion example applies cleanly from a fresh clone (or noted caveats)
- [ ] `codeRepo` frontmatter filled with the real URL
- [ ] Proof tier **1** shown (`T1 · live run`)

## 7. Known risk areas

- [ ] **Alert latency:** notification delivery lag means the "firing" screenshot
  must be timestamped; a 5m window needs a sustained burn, not a 30s blip.
- [ ] **Metrics ingestion lag** on `select_slo_burn_rate` can hide a short burn —
  hold the failure state for several minutes before declaring it captured.
- [ ] **`duration` traps:** a non-zero `duration` on a burn-rate condition
  changes when it fires (and Google's own guidance differs from the textbook);
  document the exact choice made.
- [ ] **Combiners:** fast/medium/slow policies need to combine the two window
  conditions correctly (`AND`), or you get false pages on one window alone.
- [ ] Cost: stay VM-free; induce burn with a short Cloud Run burst, not a
  persistent load generator.
- [ ] Reuse the Blog 2 keyless CI pattern if any CI is shown — no keys (org
  policy `iam.disableServiceAccountKeyCreation`).

## 8. Definitions of done

- [ ] Post published live at `gcp-architect-blog.web.app`
- [ ] Companion example in repo, applied for real, **with an induced burn**
- [ ] Evidence directory populated (firing + recovery shots included)
- [ ] Cost + teardown documented
- [ ] Series link to/from Blog 2 present

## 9. References to weave in

- Google SRE Workbook — *Alerting on SLOs* (multi-window multi-burn-rate table)
- Cloud Monitoring — SLOs, `select_slo_burn_rate`, service monitoring
- This repo's Blog 2 (`002-cloud-run-golden-path`) — the deployment it operates on
- Qiita: *GCP Cloud RunのSLO monitoringをterraformで作成* (the post that inspired this blog)
- Google Cloud Well-Architected Framework — Reliability & Operational Excellence

_Owner: Koate · favours: 1 post/week · est. effort: moderate (outline 0.5h, build 2h, write 2h, evidence 1.5h)_
