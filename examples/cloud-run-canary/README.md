# Companion example: Cloud Run canary (post 012)

**Status: scaffold only.** This example has not been applied to a GCP project and
produced no measured results. There are no screenshots, timings, or cost figures.
`terraform validate` is a syntax check, not a deployment.

Companion code for the post *"Cloud Run canary deployments: traffic splitting and
rollback"*. It shows the mechanism, not a live result.

## What it creates

- an Artifact Registry repository for the demo image;
- a least-privilege runtime service account with `roles/artifactregistry.reader`;
- a Cloud Run (v2) service with a startup probe and **1 vCPU / 512 MiB**;
- a service-level 5xx alert policy (a starting point, not a tuned production
  threshold);
- Terraform lifecycle rules that hand the image and traffic fields to the release
  pipeline after the first apply.

## Files

| File | Purpose |
|---|---|
| `main.tf` | Project services, Artifact Registry, runtime identity, Cloud Run service, alert |
| `app.py` | Stdlib-only demo app: `/healthz`, `/version`, `FAIL_MODE` switch |
| `Dockerfile` | Container image |
| `scripts/canary-release.sh` | Deploy dark, probe the tag, shift traffic, promote or roll back |
| `scripts/check-canary.sh` | Active probe of the tagged candidate (lab stand-in for revision metrics) |
| `scripts/load.sh` | Bounded concurrent load against a URL |

## Run order

```bash
# 1. Enable APIs and create the repository (image push needs it first)
terraform init
terraform apply -target="google_project_service.services" \
  -target="google_artifact_registry_repository.images" \
  -var="project_id=YOUR_PROJECT"

# 2. Build and push a base image
gcloud builds submit \
  --tag us-central1-docker.pkg.dev/YOUR_PROJECT/canary-images/canary-demo:base .

# 3. Create the service at 100% on the base image
terraform apply -var="project_id=YOUR_PROJECT" \
  -var="image=us-central1-docker.pkg.dev/YOUR_PROJECT/canary-images/canary-demo:base"

# 4. Release a candidate through the ladder
IMAGE=us-central1-docker.pkg.dev/YOUR_PROJECT/canary-images/canary-demo:candidate \
  SERVICE=canary-demo REGION=us-central1 \
  STEPS="1 10 50" BAKE_SECONDS=300 \
  CHECK_CMD="./scripts/check-canary.sh" \
  ./scripts/canary-release.sh
```

`canary-release.sh` captures the current revision **before** deploying, deploys
the candidate with `--no-traffic --tag canary`, probes the tag URL, then shifts
traffic by explicit revision names. Any failed check, Ctrl-C, or a non-zero
`CHECK_CMD` triggers `update-traffic` back to the previous revision.

## Expected observations (to be measured, not claimed)

- the candidate answers on its tag URL while production is untouched;
- `gcloud run services describe` shows the intended percentage split;
- a revision with `FAIL_MODE=1` fails the probe and never receives production
  traffic;
- rollback returns traffic to the previous revision without a new build.

None of the above is evidence until it is captured from a live run.

## Cost and teardown

Cloud Run scales to zero, but the Artifact Registry image, log ingestion, and
monitoring are billable. Set a budget alert before starting. Tear down the same
day:

```bash
terraform destroy -var="project_id=YOUR_PROJECT" \
  -var="image=us-central1-docker.pkg.dev/YOUR_PROJECT/canary-images/canary-demo:base"
```

No dollar figure is stated here. Measure it for the post.

## Known limits

- The traffic ladder is manually paced. A production canary should automate the
  stop decision from revision-scoped metrics, not a shell `sleep`.
- `check-canary.sh` probes the tag URL directly; it does not measure the share of
  organic production traffic reaching the candidate.
- The 5xx alert is service-scoped. It cannot distinguish a failing candidate from
  a failing baseline until the candidate carries enough traffic.
- No database, queue, migration, or session-affinity scenario is covered.
