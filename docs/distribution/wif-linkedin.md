# LinkedIn post — Workload Identity Federation: GitHub Actions → GCP

Link target:
`https://gcp-architect-blog.web.app/posts/security-iam/001-workload-identity-federation-github-to-gcp/`

---

## Recommended post

Your GitHub Actions workflow is authenticating to GCP with a service account key.

That key:
→ never expires
→ can't be traced to a person
→ works from anywhere on the internet
→ is sitting in a GitHub Secret right now

If it leaks, every resource that account can reach is exposed.

Workload Identity Federation removes all of it.

I wired it end to end with Terraform:

• Workload identity pool + GitHub OIDC provider
• Attribute condition that locks trust to one repo
• Least-privilege service account — and a separate runtime SA
• Keyless workflow (no secret anywhere, ever)
• Failure-mode table for every real error
• Revocation playbook for when something goes wrong
• "What changes at scale" — pools per environment, environment-pinned conditions

Proof tier 2: the Terraform applies for real, the workflow authenticates for real.

Read it here: https://gcp-architect-blog.web.app/posts/security-iam/001-workload-identity-federation-github-to-gcp/

#GCP #Security #IAM #DevSecOps #Terraform

---

## Variant B — "stop doing X" angle (best for X/Twitter cross-post)

Stop storing GCP service account keys in GitHub Secrets.

There's a better way, GA for years:

→ GitHub mints a short-lived OIDC token per workflow run
→ GCP STS validates it against your workload identity pool
→ You get short-lived Google credentials
→ No key. Nothing to rotate. Nothing to leak.

Full Terraform, failure modes, audit queries, and a revocation playbook:

https://gcp-architect-blog.web.app/posts/security-iam/001-workload-identity-federation-github-to-gcp/

#GCP #CloudSecurity #DevOps #GitHubActions

---

## Variant C — audit angle (senior audience)

"How do you audit CI access to GCP?"

If the answer is "we have a service account key and we know which teams have it",
you have a finding waiting to happen.

WIF changes the answer to:

→ repo, branch, workflow, and actor captured on every call
→ queryable in Cloud Audit Logs by OIDC subject
→ revocable by deleting one IAM binding

Full production pattern — Terraform, failure modes, audit query, revocation
playbook, Well-Architected mapping: https://gcp-architect-blog.web.app/posts/security-iam/001-workload-identity-federation-github-to-gcp/

#GCP #Security #SRE #CloudArchitecture

---

## Posting notes

- The first ~140 characters decide whether anyone taps "see more" — all three
  variants front-load the hook.
- Put the link inline; the "link in the first comment" trick now reduces reach.
- Best windows: Tue–Thu, 07:00–09:00 or 12:00–13:00 in your audience's timezone.
- End with a genuine question. For the recommended post:
  *"Curious — how many teams are still running SA keys in CI? Honest answers, no
  judgement; we've all inherited them."*
- Reply to every comment in the first 2 hours (early engagement is weighted).
- Reshare at 24–48h with a one-line addition, e.g. *"Several people asked about
  GitLab — same pattern, different OIDC issuer."*
