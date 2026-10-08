# Tier-1 screenshot runbook

Reusable workflow for capturing console screenshots for any **proof-tier 1**
post. The demo for each post lives in `examples/<slug>/` and runs in the shared
demo project `gcp-architect-demo-2026`.

## Workflow

1. **Provision** the demo:
   ```powershell
   cd examples/<slug>
   terraform apply -var="project_id=gcp-architect-demo-2026" -var="alert_email=you@example.com"
   ```
2. **Seed traffic** so charts/SLOs have real data (a dormant service shows
   nothing). ~300 requests against the service URL is usually enough.
3. **Wait 3–5 minutes** for Cloud Monitoring aggregation so SLO + latency charts
   fill in.
4. Open the console (signed in as the account that owns the project) and capture
   the views below.
5. **Drop PNG/WebP files** into `public/evidence/<slug>/` and reference them in
   the post with `![](/evidence/<slug>/<file>)`.

## The four screenshots to capture

| # | View | Console URL (replace `<PROJECT>`/`<SERVICE>`) |
|---|---|---|
| 1 | Cloud Run service — Metrics | `https://console.cloud.google.com/run/detail/us-central1/<SERVICE>/metrics?project=gcp-architect-demo-2026` |
| 2 | Cloud Run service — Deployments/revisions | `https://console.cloud.google.com/run/detail/us-central1/<SERVICE>/revisions?project=gcp-architect-demo-2026` |
| 3 | Monitoring — SLOs | `https://console.cloud.google.com/monitoring/slos?project=gcp-architect-demo-2026` (select the `<service>-slo` service) |
| 4 | Monitoring — Alert policies | `https://console.cloud.google.com/monitoring/alerting/policies?project=gcp-architect-demo-2026` |

## Naming convention

`01-service-metrics.png`, `02-revisions.png`, `03-slo.png`, `04-alert-policy.png`
(prefix with the post slug if multiple posts share the folder).

## Teardown (FinOps rule)

Capture first, then destroy same day:

```powershell
terraform destroy -var="project_id=gcp-architect-demo-2026"
```