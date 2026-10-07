# Firebase Hosting setup

The blog is deployed to Firebase Hosting on a dedicated GCP project (Blaze plan
with a tight budget — the free tier covers a static blog).

## Topology

| Piece | Value |
|---|---|
| GCP project | `gcp-architect-blog` |
| Firebase Hosting default site | `gcp-architect-blog` — `https://gcp-architect-blog.web.app` |
| Budget | £2/month, alerts at 80% / 100% |
| State backend | `gs://gcp-proof-platform-tfstate/blog-hosting` |

## What Terraform manages vs one-time CLI steps

| Piece | How |
|---|---|
| Project + billing + APIs | `infra/terraform/hosting` (project, `org_id`, services) |
| Budget (£2, 80/100%) | **`gcloud billing budgets create`** — not Terraform |
| Add Firebase to the project | **`firebase projects:addfirebase`** — not Terraform |
| Hosting content | `scripts\blog-deploy.ps1` → `firebase deploy` |

Why not Terraform for the last three: with a personal **user** ADC, the quotas
for `billingbudgets` / Firebase aren't satisfied in the Google provider (known
limitation). If you later run Terraform/CI with a **service account**, these can
be moved back into IaC.

## 1. Provision the project (Terraform)

```powershell
cd infra/terraform/hosting
Copy-Item terraform.tfvars.example terraform.tfvars   # fill org_id + billing_account_id
gcloud auth application-default login --account=koatekpai@outlook.com   # once
terraform init
terraform apply
```

## 2. Accept the Firebase Terms of Service (once, browser)

Required before Firebase can be added (403 otherwise):

1. Open `https://console.firebase.google.com/`
2. Sign in as **koatekpai@outlook.com**
3. Accept the Firebase Terms of Service when prompted
4. Do **not** create a project there (already created via Terraform)

## 3. Add Firebase + create the budget

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "$env:APPDATA\gcloud\application_default_credentials.json"

npx firebase-tools projects:addfirebase gcp-architect-blog

gcloud billing budgets create \
  --billing-account=01FBBE-ACD618-CFA5D6 \
  --display-name="gcp-architect-blog monthly budget" \
  --budget-amount=2 \
  --filter-projects=projects/495127995935 \
  --threshold-rule=percent=0.8 \
  --threshold-rule=percent=1.0
```

## 4. Point the site at the real URL

`site` in `astro.config.mjs`, the sitemap in `public/robots.txt`, and the fallback
in `src/pages/rss.xml.ts` must equal `terraform output -raw default_url`
(`https://gcp-architect-blog.web.app`).

## 5. Deploy

```powershell
scripts\blog-deploy.ps1
```

The default Hosting site is provisioned automatically on first deploy.

## 6. Custom domain (later)

Add in the Firebase console (or a `google_firebase_hosting_custom_domain`
resource) — managed SSL is free.

## Cost

Firebase Hosting free tier: 10 GB storage + ~10 GB/month transfer, free SSL,
global CDN. A static blog stays inside it. The £2 budget is a guardrail, not an
expected spend.