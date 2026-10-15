# SLOs for Cloud Run — evidence

Captured from the live tier-1 run on **2026-10-15** (project
`gcp-architect-demo-2026`, service `slo-demo`), then destroyed. These are the
artifacts the post embeds/references.

## Screenshots (console)

| File | What it shows |
|---|---|
| `01-slo-overview.png` | Availability SLO — error budget cliff + recovery, the `−1,899.704%` headline (empty-denominator trap) |
| `02-alert-firing.png` | Fast-burn policy — burn rate crossing the **14.4×** threshold (firing) |
| `03-recovery.png` | Fast-burn incident detail — `Alert closed`, **duration 6m 45s** (auto-resolved) |
| `04-latency.png` | Cloud Run request latency **p50/p95/p99** during the burn |
| `05-dashboard.png` | Cloud Run metrics — request count (2xx/5xx), latency breakdown, instance count scaling |

## CLI artifacts

Written by `examples/slos-for-cloud-run/capture-evidence.{sh,ps1}`:

| File | Source |
|---|---|
| `service-url.txt` | `gcloud run services describe` |
| `health-check.txt` | `curl /health` |
| `service-describe.json` | full service config |
| `revisions.txt` | `gcloud run revisions list` |
| `alert-policies.json` | `gcloud monitoring policies list` |
| `load-run.txt` | baseline → burn → recovery totals |
| `cost-note.txt` | run-window cost (target < $1) |

## The burn (from `load-run.txt`)

| Phase | ok | 5xx | slow (≥1s) | total |
|---|---|---|---|---|
| baseline | 24,877 | 0 | 0 | 24,877 |
| burn | 2,027 | 2,020 | 2,027 | 4,047 |
| recovery | 24,826 | 0 | 6 | 24,826 |

Fast-burn incident: fired `2026-10-15T11:19:57Z`, auto-resolved ~7 min later.

## Redaction reminder

Check `service-describe.json` / `alert-policies.json` for anything to redact
(project number, channel addresses) before publishing.
