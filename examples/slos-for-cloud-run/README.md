# slos-for-cloud-run

Companion code for the Blog 4 post *"SLOs for Cloud Run: latency, availability,
multi-window alerts."* Proof tier **1** (applied live, a burn induced on purpose,
then destroyed).

This is the **operating** counterpart to Blog 2's
[`cloud-run-golden-path`](../cloud-run-golden-path) — that post *created* an SLO;
this one shows what it takes to *run* one: the burn-rate math, the multi-window
alert table, and a real incident you can watch fire and resolve.

## What it creates

- A **fault-injecting** Cloud Run service (`slo-demo`):
  - `GET /work?fail=1` → HTTP 500 (availability burn)
  - `GET /work?latency_ms=1500` → slow 200 (latency burn)
  - `GET /health` → 200 (synthetic probe)
  - plus a baseline `FAIL_RATE` env knob
- The APIs it needs (`run`, `artifactregistry`, `monitoring`, `logging`, `iam`,
  `cloudbuild`) enabled on the project — so the example stands alone.
- A monitored service (`google_monitoring_service`, basic `CLOUD_RUN`).
- **Availability** SLO (99.9% / 30d) and **latency** SLO (99% under 1s / 30d).
- **Three-tier multi-window multi-burn-rate alerting** (the Google SRE workbook
  table), each policy ANDing a short and a long window:

  | Tier | Burn | Windows | Route |
  |---|---|---|---|
  | Fast | 14.4× | 5m **and** 1h | page |
  | Medium | 6× | 30m **and** 6h | page |
  | Slow | 1× | 6h **and** 24h | ticket |

- Two notification channels (page vs ticket email) and a **dashboard**
  (request rate, 5xx error rate, latency p50/p95/p99, instance count).

---

## Prerequisites

- A GCP project with billing — this runbook uses `gcp-architect-demo-2026`.
- `gcloud` authenticated, Terraform >= 1.5.
- A load driver: the **PowerShell** capture script is self-contained (built-in
  runspace load generator). The **bash** script needs [`hey`](https://github.com/rakyll/hey).
- A real alert email you can open (alerts deliver to `ops@example.com`
  otherwise).

**Quota-project mismatch?** If `terraform apply` fails with *"project … does not
match quota project …"*, your Application Default Credentials are pinned
elsewhere. Fix once:

```bash
gcloud auth application-default set-quota-project gcp-architect-demo-2026
```

The provider also sets `user_project_override` + `billing_project`, so it works
per-run regardless.

---

## Deploy (5 steps)

### 1. Configure

```bash
cd examples/slos-for-cloud-run
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: set `page_email` and `ticket_email` to inboxes you can
open, and confirm `project_id`.

### 2. Init

```bash
terraform init
```

### 3. Apply phase 1 — create the image registry

The service can't start until its image exists, and the image lives in a
registry this config creates. So create just the registry first:

```bash
terraform apply -target="google_artifact_registry_repository.images"
```

(This also enables the project APIs on first run.)

### 4. Build and push the fault-injecting image

```bash
gcloud builds submit \
  --tag us-central1-docker.pkg.dev/gcp-architect-demo-2026/slo-images/slo-demo:latest .
```

Cloud Build needs permission to push. If this fails on a fresh project, grant
the builder role once and retry:

```bash
gcloud projects add-iam-policy-binding gcp-architect-demo-2026 \
  --member="serviceAccount:$(gcloud projects describe gcp-architect-demo-2026 --format='value(projectNumber)')@cloudbuild.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.builder"
```

### 5. Apply the rest

```bash
terraform apply
curl -s "$(terraform output -raw service_url)/health"     # -> ok
```

Deploys the service, SLOs, the three burn-rate policies, the notification
channels, and the dashboard.

> **Verify your email channels.** Google emails each notification channel to
> confirm it; until you confirm, alerts may not be delivered. Check
> Monitoring → Alerting → Notification channels.

---

## Capture the screenshots

Everything below is what the post's evidence section expects. Total capture time
is ~15 minutes; **do the burn first, screenshots while it's fresh**.

### 1. Run the burn

One command drives baseline → burn → recovery and writes the CLI evidence:

```bash
./capture-evidence.sh                       # bash / Git Bash
./capture-evidence.ps1                      # Windows PowerShell
```

(Want to drive it by hand? `./loadgen/loadgen.sh "$(terraform output -raw service_url)" 50 180s`.)

While the burn phase runs, watch **Monitoring → SLOs** and your page inbox.

### 2. Take these screenshots

| # | File | Where | What to show |
|---|---|---|---|
| 1 | `01-slo-overview.png` | [Monitoring → SLOs](https://console.cloud.google.com/monitoring/slos?project=gcp-architect-demo-2026) | Both SLOs (`slo-demo-availability`, `slo-demo-latency`) with burn/error-budget |
| 2 | `02-fast-burn-firing.png` | [Monitoring → Alerting → Incidents](https://console.cloud.google.com/monitoring/alerting/incidents?project=gcp-architect-demo-2026) | The **14.4× fast-burn** incident, **firing**, with its start timestamp |
| 3 | `03-recovery.png` | same Incidents page | The same incident **resolved**; burn back toward 0 |
| 4 | `04-latency.png` | [Cloud Run → Metrics](https://console.cloud.google.com/run/detail/us-central1/slo-demo/metrics?project=gcp-architect-demo-2026) | Request latencies p50/p95/p99 during the `latency_ms` experiment |
| 5 | `05-dashboard.png` | [Monitoring → Dashboards](https://console.cloud.google.com/monitoring/dashboards?project=gcp-architect-demo-2026) | The `SLO demo (slo-demo)` dashboard |
| 6 | `06-cost.png` | [Billing → Reports](https://console.cloud.google.com/billing?project=gcp-architect-demo-2026) | The run window's charge (optional) |

Drop the files into
[`public/evidence/slos-for-cloud-run/`](../../public/evidence/slos-for-cloud-run/).
The console URLs, capture notes, and redaction reminders also live in that
directory's [`SCREENSHOTS.md`](../../public/evidence/slos-for-cloud-run/SCREENSHOTS.md).

### Capture tips

- **Hold the burn for several minutes.** A 5m-window page can't fire on a 30s
  spike by design; keep the failing load running until the incident appears.
- **Timestamp the fire.** The incident start time is the evidence; a chart with
  no timestamp proves nothing.
- **Capture the resolve, not just the fire.** Screenshot `03` a few minutes
  after you stop the burning load.
- **Metrics lag ~1–2 min.** If a chart looks empty, wait and re-shoot.

---

## Teardown (same day)

```bash
terraform destroy
```

Removes the service, SLOs, alerts, dashboard, registry contents, and runtime SA.
APIs stay enabled (`disable_on_destroy = false`).

---

## Cost

Cloud Run scales to zero and the burn is a short client-side burst, so there is
**no always-on compute (no VM)** — a full deploy → burn → capture → destroy
cycle is well under $1. The demo project has an £5 budget guardrail.

---

## Notes / caveats

- **Latency threshold is whole seconds.** The SLO `threshold` is a protobuf
  duration; `"1s"` is accepted, `"500ms"`/`"800ms"` are rejected. For sub-second
  precision, build a custom SLI from a log-based metric.
- **`duration` on burn-rate conditions stays `0s`.** The window lives inside
  `select_slo_burn_rate`; a non-zero `duration` changes when the alert fires.
- **Lookback windows cap at 24h.** `select_slo_burn_rate` rejects `3d` (and
  `72h`) with *"Durations longer than 24h are not supported"*, so the slow tier's
  long window is `24h`, not the textbook 3 days.
- **Combiners:** each policy uses `combiner = "AND"` so a short window alone
  can't page. Getting this wrong is the #1 cause of noisy SLO alerts.
- **Thresholds assume a 30-day SLO window.** Change the window and the burn
  multiples move with it.
- **SLO burn is a Monitoring page, not a dashboard tile.** The dashboard covers
  request/error/latency/instance; the SLO burn is captured from Monitoring → SLOs.
- Org policy `iam.disableServiceAccountKeyCreation` is in force — keep any
  automation keyless (reuse the Blog 1 WIF pattern).
