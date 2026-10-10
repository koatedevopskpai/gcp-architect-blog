# KOATE KPAI

**AI Implementation Engineer — Production LLM Systems (RAG · Agents · Evals)**
London / Remote · Contract · Immediate availability
[email] koatekpai@outlook.com · [GitHub] github.com/koatedevopskpai · [LinkedIn] linkedin.com/in/koatekpai · [Blog] gcp-architect-blog.web.app

---

## SUMMARY

AI engineer who ships **production LLM systems** — RAG, agents and evaluation
pipelines — with a **deterministic-first** approach: pure, testable logic for the
critical path, LLMs on top, evaluated continuously. I pair that with strong
cloud-platform engineering (Terraform, CI/CD, observability) so systems run
reliably, observably and inside budget.

I build in public with **run evidence**: live-deployed platforms, eval-gated
CI, and tier-1 proof (deploy → capture metrics → teardown). Comfortable owning a
problem end to end — retrieval quality, agent orchestration, evals, cost,
latency and security.

---

## CORE SKILLS

**AI / LLM:** RAG (hybrid retrieval, reranking, chunking, query decomposition) ·
Agentic workflows & tool use · **LLM evaluations** (golden sets, LLM-as-judge,
RAGAS-style, regression gates) · Prompt engineering · Guardrails & groundedness ·
Pydantic v2 structured outputs · Deterministic-first architecture

**Python:** async pipelines · typing · pytest · FastAPI · retry/backoff, circuit
breakers, fallbacks

**Cloud / Platform:** Google Cloud (Cloud Run, GKE, BigQuery, Vertex AI,
Artifact Registry, Workload Identity Federation) · AWS (EKS) · Azure (OpenAI,
AKS) · Terraform · Docker · CI/CD (Cloud Build, GitHub Actions) · Kubernetes/Helm

**Data:** PostgreSQL + pgvector · BigQuery · ETL pipelines · SQL

**AI-native delivery:** daily use of agentic coding tooling (Claude Code / Cursor
class) with review discipline

---

## SELECTED AI PROJECTS (public, run-evidenced)

**multi-agent-optimizer** — github.com/koatedevopskpai/multi-agent-optimizer
Deterministic-first scheduling optimizer: a unit-tested **CPM engine** (critical
path, float, cycle detection) with **Scheduler / Risk / Optimiser agents** under
an orchestrator; LLM enrichment optional, wrapped in retry/backoff, a **circuit
breaker** and **Pydantic-v2-validated** calls with deterministic fallback. CI
gate: 19 tests / ≥80% coverage + golden-case evals.

**agentic-rag-hybrid** — github.com/koatedevopskpai/agentic-rag-hybrid
Planner-executor RAG with **hybrid retrieval** (BM25 sparse + dense), **Reciprocal
Rank Fusion** and a **groundedness filter**. Deterministic (no LLM in the
retrieval path); **97% test coverage** + assertion-based retrieval eval gate.

**llm-evals-demo** — github.com/koatedevopskpai/llm-evals-demo
A CI quality bar for LLM/RAG apps: golden dataset, RAGAS faithfulness +
relevance, LLM-as-judge, and a **deploy-blocking eval gate** (≥0.90).

**LexiSum — regulatory-compliance RAG engine**
Production RAG + auditing system achieving **100% verbatim compliance across 100
contracts**; 5-dimension evaluation rubric benchmarked across OpenAI, Anthropic
and Gemini.

**ai-platform-proof** — github.com/koatedevopskpai/ai-platform-proof
Cross-language RAG platform (Python, TypeScript, .NET) on EKS with Terraform +
Helm and **CI evaluation gates** that fail builds on quality regression; FinOps
labels + enforced budget.

**cloud-run-ai-golden-path** — github.com/koatedevopskpai/cloud-run-ai-golden-path
Pydantic-validated FastAPI LLM endpoint packaged with Terraform (SLOs, 14.4×
burn-rate alert) and **keyless WIF CI** — the deployable pattern for AI on Cloud
Run.

---

## EXPERIENCE

**Galland Limited — Independent AI / Platform Engineer** · Mar 2026 – Present · Contract
- Designed and shipped production LLM systems — **RAG, agents, evals** — with a
  deterministic-first architecture and automated evaluation gates.
- Built and open-sourced the multi-agent optimizer, hybrid RAG and LLM-evals
  harness above (agents, retrieval, evals, resilience).
- Owned delivery end to end: Terraform-first infrastructure, keyless CI/CD
  (Workload Identity Federation), observability and FinOps.
- Created two live cloud platforms (`gcp-proof-platform`, `ai-platform-proof`)
  and a run-evidenced AI blog; porting flagship AI products to GCP/AWS.

**Hitachi Rail UK — Data Automation & Analytics Engineer** · Apr 2025 – Mar 2026
- Engineered Python/**Pydantic v2** data models and deterministic algorithms;
  automated ETL (Primavera P6 → Power BI) cutting manual reporting **60%**.
- Delivered real-time Earned-Value dashboards (cost/schedule variance within 5%).

**ARUP / Thames Water (AMP7/8) — Data Analytics Engineer** · Nov 2024 – Apr 2025
- SQL/Power BI pipelines consolidating **20+ delivery partners**; recovered
  **£120K** in unused licences; customer-service pipelines for **15M** customers
  (**+40%** SLA compliance).

**MWH Treatment / Thames Water (AMP7) — Data Automation Engineer** · Apr 2023 – Nov 2024
- Automated Primavera P6 reporting (Python, Power BI); flagged negative SPI trends.

**Galliford Try — Data & Reporting Engineer** · Mar 2022 – Apr 2023
- NEC4 Power BI dashboards and variance analysis for senior leadership.

**MWH Treatment / Thames Water (AMP6) — Data Automation Engineer** · May 2018 – Mar 2022
- Integrated Primavera P6 with Python/Power BI (CPI/SPI); resource-loaded schedules.

**Earlier engineering (2015–2018):** Lead Planner — EMICO/TfL Rail; Senior Project
Planner — TfL London Underground (4LM Power).

---

## EDUCATION & CERTIFICATIONS

- **MSc Construction Project Management** — University of Wolverhampton
- **BSc (Hons) Geology** — University of Nigeria, Nsukka
- **Google Cloud Certified — Professional Cloud Architect** (Kubernetes · Cloud Run · BigQuery · IAM/WIF)
- AWS Solutions Architect · Azure AZ-900
- PMP · PRINCE2 Practitioner · Lean Six Sigma · SAFe/Scrum Master

---

**Availability:** Immediate · Contract (via Galland Limited) · UK-based · Remote
