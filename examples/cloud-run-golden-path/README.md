# Cloud Run golden path — companion example

Companion code for the Blog 2 post *"Cloud Run golden path: Terraform + CI/CD +
SLOs."* Proof tier **1** (applied live, then destroyed).

## What it creates

- Artifact Registry repo (`cloud-run-images`)
- A least-privilege runtime service account (`hello-sa`)
- `google_cloud_run_v2_service` `hello` — scale-to-zero, CPU 1 / 256 Mi,
  **startup CPU boost**, TCP startup probe, public ingress
- Availability **and** latency **SLOs** + a multi-window multi-burn-rate alert
  (the Qiita-inspired pattern on `google_monitoring_service`/`google_monitoring_slo`)
- Burn alert wired to an email notification channel (`alert_email` var)

## Hardening included

- Artifact Registry is **labelled** (FinOps) and **vulnerability scanning** is on
  by default in supported regions.
- The runtime SA is granted **`roles/artifactregistry.reader`** so it can pull
  self-hosted images (no Editor anywhere).
- Tag **retention** (lifecycle) isn't exposed in the provider yet; set it with:

  ```bash
  gcloud artifacts repositories update cloud-run-images \
    --project=gcp-architect-demo-2026 --location=us-central1 \
    --cleanup-policy=examples/cloud-run-golden-path/lifecycle.yaml
  ```

  Use `keep last N digests` for a policy (sample: keep 20).
- Concurrency is a workload decision; set it at deploy time (e.g. `--concurrency 80`)
  rather than hard-coding it in the module.

## Usage

```bash
# Terraform for the project itself lives in infra/terraform/demo
gcloud config set project gcp-architect-demo-2026

terraform init
terraform apply -var="project_id=gcp-architect-demo-2026" \
  -var="alert_email=you@example.com"

curl -s $(terraform output -raw service_url)
```

Build and push your own image (instead of the default sample):

```bash
gcloud builds submit --tag us-central1-docker.pkg.dev/gcp-architect-demo-2026/cloud-run-images/hello:v1 .
terraform apply -var="project_id=gcp-architect-demo-2026" \
  -var="image=us-central1-docker.pkg.dev/gcp-architect-demo-2026/cloud-run-images/hello:v1"
```

## Teardown (same day, per the FinOps rule)

```bash
terraform destroy -var="project_id=gcp-architect-demo-2026"
```

## Cost

Cloud Run scale-to-zero: only billable while serving. A short demo run is well
under $1. The demo project has an £5 budget guardrail.

## CI

`.github/workflows/deploy.yml` shows the keyless build → push → deploy path —
the same Workload Identity Federation pattern the blog itself uses
(see `infra/terraform/hosting/ci.tf` and `.github/workflows/deploy.yml` at the
repo root). Provision a matching WIF pool/provider in the demo project to run it.