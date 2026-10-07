# Blog 2 pre-draft — Cloud Run golden path (Tier 1, live run)

> Status: **pre-draft checklist**. Target: `platform-engineering-idp` pillar A,
> id `002`, title **"Cloud Run golden path: Terraform + CI/CD + SLOs."**
> Queue position: next after Blog 1 (WIF). Proof tier **1** (live run + evidence).

---

## 1. Prerequisites & decisions (settle before writing)

- [ ] **Decision: where the tier-1 demo runs.**
  Options:
  - **A (recommended):** create the shared demo project `gcp-architect-demo`
    (Terraform under `koatekpai-org`, your billing account, own £ budget,
    `default_labels`) — this is the long-planned "shared demo project" and Blog 2
    is its first tenant.
  - B: temporarily run in `gcp-architect-blog` with labels + teardown (mixes
    hosting and throwaway; not preferred).
- [ ] Region `us-central1`; every resource prefixed `blog2-*` + labels.
- [ ] Target cost of the live run: **< $1**; destroy same day.

## 2. Companion example: `examples/cloud-run-golden-path/`

- [ ] `main.tf`:
  - Cloud Run **service** (nginx/hello container) — min instances 0, `container_concurrency`,
    per-revision env, `startup-cpu-boost`.
  - Dedicated **runtime service account** (least privilege, no default Editor).
  - Artifact Registry repo for the image.
  - IAM: `run.invoker` public endpoints or IAP note.
  - **SLO**: `google_monitoring_service` (basic_service `CLOUD_RUN`, service_name+location)
    + availability **and** latency SLOs (the Qiita pattern) + `select_slo_burn_rate`
    alert policy.
- [ ] CI/CD: GitHub Actions **and** Cloud Build configs that build → push to AR →
  `gcloud run deploy` (keyless, reusing the WIF pattern from Blog 1).
- [ ] `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, `README.md`.

## 3. Post outline (Qiita-style)

1. **Overview** — why a "golden path": one blessed way to ship a service with
   deploy, SLOs, cost, and security included.
2. **The problem this solves** — Cloud Run is easy to *deploy*; hard to *operate*
   (no keys, no dashboard, no alert). Pain table (like Blog 1).
3. **Architecture** — Mermaid: repo → CI → AR → Cloud Run → Monitoring/SLO.
4. **Prerequisites** — project, billing, ADC/CI, gcloud.
5. **Steps** — service + SA → push image → deploy → traffic; **SLO + burn alert**
   (Terraform); **CI/CD** wiring; **canary/gradual rollout** (`--traffic` /
   revision split).
6. **Extras** — min instances/cold start, concurrency tuning, `startup-cpu-boost`,
   per-revision env + secrets, VPC egress note.
7. **SLO / Security / FinOps notes** — cost of the run, least-privilege SA,
   availability vs latency.
8. **Reproduce** — commands + link to `examples/cloud-run-golden-path`.
9. **Well-Architected mapping** — Reliability + Operational Excellence pillars.
10. **References** — Cloud Run docs, the Qiita SLO article, our own WIF post (for CI).

## 4. Tier-1 evidence to capture (drop into `public/evidence/cloud-run-golden-path/`)

- [ ] `terraform plan/apply` output (redacted)
- [ ] Deployment log output
- [ ] Live URL + `/health` HTTP 200 screenshot
- [ ] Cloud Run metrics: request count, p95/p99 latency, instance count
- [ ] SLO dashboard screenshot + an alert-policy screenshot
- [ ] Canary/traffic-split screenshot (two revisions, 90/10)
- [ ] **Cost line** for the run period (billing/cost export; must be < $1)
- [ ] Tear-down confirmation (`terraform destroy`)

## 5. Verification gates before publish

- [ ] `npm run build` passes with the new post
- [ ] Screenshots/metrics actually present (no "trust me" claims)
- [ ] Cost recorded
- [ ] Companion example applies cleanly from a fresh clone (or noted caveats)
- [ ] `codeRepo` / `demoUrl` frontmatter filled with real URLs
- [ ] Proof tier **1** shown (`T1 · live run`)

## 6. Known risk areas

- [ ] SLO needs **traffic**; seed with a small load generator (e.g. Cloud Scheduler
  hitting `/health`, or `hey`) for a short window before capturing.
- [ ] Cold-start variability in latency SLO — capture a warm run, note it.
- [ ] Org policy `iam.disableServiceAccountKeyCreation` — CI must stay keyless
  (reuse Blog 1 WIF).
- [ ] Egress/connector cost — stick to public egress, no VPC connector, to stay
  < $1.
- [ ] Demo project not yet created — provision it first (see §1).

## 7. Definitions of done

- [ ] Post published live at `gcp-architect-blog.web.app`
- [ ] Companion example in repo, applied for real
- [ ] Evidence directory populated
- [ ] Keyless CI (GitHub Actions or Cloud Build) shown working
- [ ] Cost + teardown documented

## 8. References to weave in

- Google Cloud Run docs / Cloud Run overview
- Qiita: *GCP Cloud RunのSLO monitoringをterraformで作成* (the post that inspired this blog)
- Google Cloud Well-Architected Framework — Reliability & Operational Excellence
- This repo's Blog 1 WIF post (CI auth)
- Cloud Run `gcloud run services update-traffic` / revisions docs

_Owner: Koate · favours: 1 post/week · est. effort: moderate (outline 0.5h, build 2h, write 2h, evidence 1h)_