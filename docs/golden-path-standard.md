# Cloud Run Golden Path — Platform Standard (v2)

_Adoptable architecture standard for teams deploying Cloud Run. The working
implementation is `examples/cloud-run-golden-path/`; the companion write-up is
Blog 2 (`002-cloud-run-golden-path`)._

**Status:** draft standard · **Owner:** Platform Engineering · **Scope:** all
Cloud Run services · **Applies to:** `gcp-architect-demo-2026` and, with label
changes, any project.

## Purpose

One blessed way to ship a Cloud Run service: Terraform-only provisioning, a
dedicated runtime identity, keyless CI/CD, SLOs with burn-rate alerting, and
FinOps defaults baked in. Deviation requires an explicit platform-engineering
approval.

## Non-negotiables (this org)

- **Dedicated runtime SA per service** — never the default compute SA, never
  `Editor`, no wildcard bindings.
- **No service-account keys anywhere** — the org policy
  `iam.disableServiceAccountKeyCreation` enforces this; use WIF.
- **Alert on error budgets**, not just on "is it down".
- **Terraform is the source of truth** — no console clicker-deploying.
- **Defer org-gated patterns** (Binary Authorization, VPC Service Controls, org
  policies) to Phase 1B per the blog's backlog policy — they are not part of the
  service-default path yet.

## Golden defaults (opinionated — tune by workload)

| Setting | Default | Rationale |
|---|---|---|
| CPU | 1 | Predictable autoscaling |
| Memory | 512Mi | Minimum with always-allocated CPU |
| Concurrency | set at deploy (`--concurrency 80`) | Workload decision |
| Timeout | 30s | Bound stuck requests |
| Execution env | gen2 | Faster and more secure |
| Autoscaling | min 0 / max 5 | Scale-to-zero with a cost cap |
| Startup | CPU boost + TCP probe | Fast cold starts |
| Identity | dedicated runtime SA | Least privilege |
| Registry | labels + scanning + tag retention | FinOps + supply chain |

## Module boundary

Teams consume a shared module; they do not write Cloud Run Terraform from
scratch:

```
modules/cloud_run_service/
  identity.tf        # runtime SA + artifactregistry.reader
  artifact_registry.tf
  service.tf         # v2 service, probes, timeout, exec env
  ingress.tf         # public (demo) vs IAP/PSC (prod)
  slo.tf             # availability + latency SLOs
  alerts.tf          # multi-window burn-rate + notification channel
  outputs.tf
```

The POC lives at `examples/cloud-run-golden-path/` (single-file for readability);
the shareable module is a follow-up.

## CI/CD (keyless)

GitHub Actions → OIDC → Workload Identity Federation → Cloud Build → Artifact
Registry → Cloud Run. No secrets. See `.github/workflows/deploy.yml` in the
example and the repo-root workflow that deploys this blog itself.

## SLOs & alerting

- Availability 99% / 30d and latency (95% under 1s) / 30d.
- Multi-window burn-rate alert: 5m and 1h windows at 14.4×.
- Notification channel: email (default `ops@example.com`, set `alert_email`),
  Slack for production services.

## Observability baseline

Structured JSON logs, `request_count` + `request_latencies` in a per-service
dashboard, Cloud Trace at ~10% sampling. (Per-service dashboards are a follow-up
to this pass.)

## Security posture

- Dedicated runtime SA (reader-only on the registry, secret accessor where
  needed).
- Secrets via Secret Manager per revision — never baked into images.
- Public ingress only for demos; production uses IAP or Private Service Connect
  or Cloud Armor (each a separate follow-up post, per backlog §Networking).
- Org-gated: Binary Authorization and VPC-SC are **deferred** per backlog policy.

## FinOps

- Labels on every resource (`finops_owner`, `env`, `workload`).
- Scale-to-zero by default; max-instances cap; memory right-sized.
- Per-project + per-billing-account budgets, alerting at 80%/100%.
- Throwaway resources destroyed the same day.

## Reproduce

```bash
cd examples/cloud-run-golden-path
terraform init && terraform apply \
  -var="project_id=gcp-architect-demo-2026" -var="alert_email=you@example.com"
curl -s $(terraform output -raw service_url)
terraform destroy -var="project_id=gcp-architect-demo-2026"
```

## Backlog mapping (what's explicitly NOT here yet)

IAP, PSC, Cloud Armor, VPC egress (#30, #57–61), custom SLIs and SLO→BigQuery
(#89–97), cosign/SLSA + promotion pipelines (#109, #113), Binary Auth / VPC-SC /
org policies (Phase 1B), per-service dashboards (#94), runbooks & change
management (#188).