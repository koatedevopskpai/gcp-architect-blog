# LinkedIn profile review & rewrite — Koate Kpai

## Positioning decision: GCP primary, AI as the applied differentiator

You don't have to choose between AI and GCP — and you shouldn't defer one. The strongest,
most defensible position is the **bridge**:

> **Cloud Platform / DevOps Engineer (GCP) who runs production AI systems on GCP.**

### Why bridge, not "GCP now, AI later"

- **Legibility.** "GCP platform engineer" matches your CV, blog, and repos — recruiters can
  find and filter you *today*. "AI & Data Engineering Consultant … Azure, OpenAI" doesn't
  surface you for GCP roles, and doesn't prove AI depth either.
- **Differentiation.** "Runs AI on GCP" (RAG, agents, evals, Vertex AI, BigQuery) is rarer
  and higher-leverage than either alone. Many people do AI; many do GCP; fewer do both in
  production.
- **No rebrand cost.** Deferring AI means rebuilding your profile and audience later. The
  bridge compounds both now.
- **Your blog already supports it.** Pillar D (Data & MLOps) gives AI a natural home inside
  a GCP-architecture brand — no need to split your identity.

### Transition roadmap (the AI weight grows over time)

| Phase | Headline/About emphasis | Blog focus |
|---|---|---|
| **Now–3 months** | GCP platform-led; AI as "production LLM/RAG systems" | GCP-first: WIF, Cloud Run golden path, SLOs |
| **3–6 months** | Add "AI Platform on GCP" to Featured | 2–3 pillar-D posts: RAG + pgvector, Vertex AI pipelines, eval gates in CI |
| **6–12 months** | Elevate to "AI Platform Engineer (GCP)" | AI-on-GCP reference architectures |

**The rule: never drop a lane, just change its weight.** Every GCP post you publish now is
audience the AI positioning inherits later.

---

## Do these six things right now (in order)

| # | Action | Why it matters |
|---|---|---|
| 1 | Rewrite the **headline** | Your 220-char search ad. Currently hides GCP entirely. |
| 2 | Add an **About** section | "up to 3.9× more profile views." You have none. |
| 3 | Turn on **Open to Work** + add job preferences | You have no job preferences set — you're invisible to the recruiter filter. |
| 4 | Fill **Skills** (GCP-first) | "50% of hirers use skills data." Yours are empty. |
| 5 | Add **Education** + a **custom URL** + banner | Completeness signals; `li.com/in/koatekpai` is more shareable than a random ID. |
| 6 | **Feature** your blog + the two repos | Proof of work, one click from your profile. |

---

## 1. Headline — pick one (220-char limit)

**Option A — final (recommended)**
```
GCP Platform Engineer & Cloud Architect — Terraform · Cloud Run · GKE · IAM · SRE · FinOps | I also run production AI systems on GCP (RAG, agents, evals, Vertex AI)
```

**Option B — GCP-first**
```
GCP Platform/DevOps Engineer — Terraform, Cloud Run, GKE, keyless CI/CD, SLOs, FinOps. I turn prototypes into production platforms that stay inside a real budget.
```

**Option C — short & punchy**
```
Platform Engineer (GCP) · Terraform · Kubernetes · SRE | I ship production-grade platforms — and the AI systems on top.
```

---

## 2. About — copy-paste (1300 chars)

```
Most GCP and AI projects don't fail because of the model.
They fail because the platform isn't production-ready: no CI/CD, no observability,
keys in secrets, unpredictable cost, no SLOs, no identity boundaries.

I fix the platform so the product can ship.

I'm a Cloud Platform & DevOps Engineer focused on Google Cloud, with a bias for production reality over demos:

• Platform: Terraform, Cloud Run, GKE Autopilot, Artifact Registry, Workload Identity Federation, VPC design
• Delivery: Cloud Build & GitHub Actions, keyless CI/CD, SBOM + image scanning, policy-as-code gates
• Reliability: SLOs, multi-window burn-rate alerting, dashboards, incident runbooks
• Data & AI: BigQuery, Vertex AI, RAG, agents, evals — Python, TypeScript, C#
• FinOps: labelled by default, hard budgets, right-sizing, cost guardrails

I build in public. Every pattern I write ships with working Terraform and real evidence — not slideware.

Selected work:
• gcp-proof-platform — production-grade GCP reference platform (Compute Engine, Cloud Run, GKE Autopilot, BigQuery, Cloud Build, Workload Identity Federation) built to a hard $20/month budget
• ai-platform-proof — the AWS companion
• LexiSum, Agentic RAG, Multi-Agent Optimizer — production LLM systems with evaluation gates

Currently consulting as an AI/Data Engineer at Galland Limited and writing deep, code-first GCP architecture notes.

Open to platform/DevOps and cloud engineering roles and contracts.

Blog: https://gcp-architect-blog.web.app · GitHub: https://github.com/koatedevopskpai/gcp-architect-blog
```

---

## 3. Experience — AI Data Engineer Consultant, Galland Limited

Rewrite the role to lead with platform + delivery, not just "AI". Suggested shape
(fill in real numbers):

```
AI Data Engineer Consultant · Galland Limited (Contract)
Mar 2026 – Present · Greater London (Remote)

• Design and ship production LLM/RAG pipelines in Python with deterministic-first
  architecture and automated evaluation gates.
• Own delivery end to end: containerisation, infrastructure-as-code, CI/CD, and
  environment promotion.
• Implement secure, keyless CI/CD using Workload Identity Federation (GitHub → GCP).
• Build Terraform-first GCP infrastructure: Cloud Run, GKE Autopilot, Artifact
  Registry, and IAM boundaries.
• Instrument systems with structured logging, metrics, SLOs, and evals.
• Apply least-privilege IAM, cost controls, and zero-trust identity.
• Stack: Python, Terraform, Docker, CI/CD, GCP/Azure, BigQuery/Postgres, LLM APIs.
```

Add a second entry for **Galland Limited** as the consulting company if it's your own
entity, or list notable projects as separate "Projects" entries.

---

## 4. Skills — add these (GCP-first, tools hirers search)

**Cloud & platform:** Google Cloud Platform (GCP), Compute Engine, Cloud Run, Google Kubernetes Engine (GKE / GKE Autopilot), Cloud Storage, Cloud SQL, BigQuery, Vertex AI
**IaC & delivery:** Terraform, Docker, Kubernetes, CI/CD, GitHub Actions, Cloud Build, Artifact Registry, Helm
**Reliability & ops:** Site Reliability Engineering (SRE), Observability, Monitoring & Alerting, SLOs, Incident Response, FinOps / Cloud Cost Optimization
**Security & identity:** Identity and Access Management (IAM), Workload Identity Federation, Cloud KMS, VPC, Zero Trust, Organization Policies
**Languages:** Python, TypeScript, C#/.NET, SQL
**Other clouds:** AWS, Microsoft Azure
**AI/Data:** LLM, RAG, Agents, MLOps, Data Engineering, Prompt Engineering, Evaluation (Evals)

Order them GCP-first. Ask 2–3 colleagues to endorse the top 3.

---

## 5. Featured section — add these links

1. Blog post: *Workload Identity Federation from GitHub Actions to GCP*
2. Blog: home / pillars
3. GitHub: `gcp-proof-platform`
4. GitHub: `gcp-architect-blog`
Each as a "Link" card with a one-line description.

---

## 6. First post

Use `docs/distribution/wif-linkedin.md` (recommended variant). Practical sequence:

1. Post the WIF article on your blog.
2. Publish the LinkedIn post with the link inline.
3. For the first two weeks, spend 15 min/day leaving substantive comments on
   GCP/DevOps posts — that's how you get discovered with 0 followers.
4. Reshare at 24–48h with a one-line addition.

---

## Profile hygiene checklist

- [ ] Headline rewritten (GCP-first)
- [ ] About added
- [ ] Open to Work + job preferences set
- [ ] Education added
- [ ] 25+ skills added, top 3 endorsed
- [ ] Custom URL claimed (`/in/koatekpai`)
- [ ] Banner image (branded: "GCP architecture, proven in production")
- [ ] Featured: blog + 2 repos
- [ ] Contact info + "services" section (if consulting)
- [ ] Location kept: Isleworth / Greater London
