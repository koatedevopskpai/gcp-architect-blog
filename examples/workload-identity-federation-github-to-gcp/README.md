# Workload Identity Federation: GitHub Actions → GCP

Keyless authentication from GitHub Actions to GCP. No service account keys.

Companion code for the post:
`src/content/posts/security-iam/001-workload-identity-federation-github-to-gcp.mdx`

## What it creates

- A Workload Identity Pool + GitHub OIDC provider (trust locked to one repo via
  an `attribute_condition`).
- A least-privilege service account impersonated by the workflow.
- An IAM binding (`roles/iam.workloadIdentityUser`) on the repository principal.

## Usage

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

terraform init
terraform apply -var="project_id=YOUR_PROJECT_ID" -var="github_repo=OWNER/REPO"

# Values for the GitHub Actions auth step:
terraform output -json auth_snippet
```

Then copy `.github/workflows/deploy.yml` into your application repository and
substitute the two auth values from `auth_snippet`.

## Cost

Free. Workload Identity Federation, IAM, and the STS token exchange carry no
charge.

## Teardown

```bash
terraform destroy -var="project_id=YOUR_PROJECT_ID" -var="github_repo=OWNER/REPO"
```
