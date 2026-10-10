# AI contract job plan — 2-week sprint (London / remote, outside IR35)

Goal: land an **AI engineering contract** within ~2 weeks. Target: **remote
outside-IR35** (limited company — Galland Limited). Hybrid London is acceptable
as a fallback (you're London-based).

---

## 1. Market read (2026)

- **Titles that map to you:** AI Engineer · GenAI / LLM Engineer · Applied AI
  Engineer · Agentic AI Engineer · **Forward Deployed (AI) Engineer** · AI
  Platform / MLOps Engineer · RAG / Retrieval Engineer.
- **Day rates (outside IR35, from live UK boards):** AI/GenAI Engineer
  **£550–£650**, Senior Applied AI **£700–£900**, Forward Deployed **£500–£600**.
- **Demand signals:** RAG appears in ~12% of *AI Engineer* postings; most common
  companion skills: Python, prompt engineering, vector DBs, LangChain, LLMs.
- **Reality on remote + outside IR35:** *both at once* is rarer. Many AI roles
  are **hybrid (London 1–2 days) and/or inside IR35**. Remote outside-IR35 AI
  roles do exist (e.g. “AI Engineer | RAG, agentic, Python, AWS/GCP | Remote |
  £600/day”, “AI Engineer | RAG, Neo4j | Remote | £850/day”). Strategy: chase the
  remote ones hard, and treat “1–2 days London + outside” as acceptable.

## 2. What the market asks for vs what you have

| Requirement (from real listings) | You |
|---|---|
| Strong Python (async, typing, testing) | ✅ products + typed code |
| RAG + **hybrid retrieval**, reranking, chunking, query decomposition | ✅ `agentic-rag-hybrid` (BM25 + dense + RRF + groundedness) |
| Multi-agent / agentic workflows, tool use, structured outputs | ✅ `multi-agent-optimizer` (agents + Orchestrator + Pydantic v2) |
| **Evals / LLM-as-judge / observability / regression gates** | ✅ `llm-evals-demo`, eval gates across repos |
| Pydantic / LangChain / LangGraph / Semantic Kernel | ✅ Pydantic v2; ⚠️ you built custom, not LangGraph — worth a small LangGraph sample |
| Cloud (AWS/GCP/Azure), Docker, CI/CD, Kubernetes | ✅ GCP/AWS/Azure IaC, Cloud Run, CI/CD; ⚠️ K8s light |
| “Ships with AI coding tools (Cursor/Claude Code)” | ✅ you work agentically — say so explicitly |
| Production/enterprise + regulated domain (fintech) | ⚠️ gap: no named client AI-in-prod. Mitigate with live proof (blog tier-1 + repos) |

**Net:** you are a *strong technical match*; the gaps are **commercial framing**
and a **CV that leads with AI**, not skills.

## 3. Positioning (locked earlier)
> **AI Implementation / AI Platform Engineer — production LLM systems: RAG, agents, evals. Deterministic-first, platform-engineered (GCP/AWS).**

## 4. Where to apply (desktop)

**Aggregators (best signal for outside IR35):**
- **outsideir35.org.uk** — filter: Remote + Generative AI/LLM/RAG + £550+
- **ir35jobs.co.uk**, **ir35uk.com**, **contractoruk.com/jobs** (Outside + Remote filters)
- **Jobserve**, **Reed**, **CV-Library**, **Totaljobs**, **Indeed** — search “AI Engineer contract outside IR35 remote”

**AI-specialist recruiters (message these directly):**
- Harnham · Stott and May · Opus Recruitment · Randstad Technologies · Experis ·
  VIQU · Oscar Associates · IO Associates · CPS Group · Understanding Recruitment

**Search strings (save as alerts):** `AI Engineer`, `GenAI Engineer`,
`LLM Engineer`, `Applied AI`, `Forward Deployed Engineer`, `RAG`, `Agentic AI`,
`AI Platform`, `MLOps` — with `outside IR35` + `remote`.

## 5. 14-day action plan

| Day | Action |
|---|---|
| **1** | Finalise **AI-forward CV** (2 pp) + LinkedIn (already drafted). Freeze both. |
| **1** | Register + set alerts on: outsideir35.org.uk, ir35jobs, contractoruk, Jobserve. |
| **2** | Apply to **5 roles** (outside IR35 first). Tailor top line per role. |
| **2** | Email **6 AI recruiters** (Harnham, Stott and May, Opus, Randstad, Experis, VIQU) with CV + one-liner + availability. |
| **3** | **Publish Blog 3** (RAG on GCP) → newest live AI proof; add to CV/LinkedIn. |
| **3** | LinkedIn: connect with 15 AI/GenAI hiring managers in London; short note. |
| **4** | Apply to 5 more; follow up Day-2 recruiters (2-line bump). |
| **5** | Outreach: 5 AI-first consultancies/startups hiring contractors (direct). |
| **6** | Deploy the Article distribution (see submission-plan) — LinkedIn post Variant A. |
| **7** | Rest + review funnel; fix whatever isn’t converting (CV/title/rate). |
| **8** | Apply to 5 more; 5 recruiter follow-ups; 1 intro call target. |
| **9** | Add a small **LangGraph** sample to `multi-agent-optimizer` (closes the framework gap). |
| **10** | Apply to 5 more; ping every quiet recruiter; ask 2 for feedback. |
| **11** | Interviews prep: 3 STAR stories (RAG quality, eval gate saved a regression, cost/latency win). |
| **12** | Apply/convert; negotiate rate; ask for **outside-IR35 SDS** up front. |
| **13** | Follow-ups; broaden to 1–2-days-London hybrid (outside IR35) if remote is thin. |
| **14** | Review metrics; double down on the highest-yield channel. |

**Target pace:** ~5 applications/day (≈40–50 total) + 6–10 recruiter touchpoints.

## 6. Contracting logistics (outside IR35)

- **Vehicle:** contract **inside your limited company** (Galland Limited); get a
  contract review + **IR35 SDS** from the client/agency before signing.
- **Insurance:** Professional Indemnity + Public Liability (agencies ask).
- **Accountant** already in place (you file via Galland) — keep records per contract.
- **Rate:** open at **£650/day**, floor **£550** for remote outside IR35.
- **Small print that matters:** substitution clause, no MoO, control — preserve
  outside-IR35 posture (don’t work like a permie).

## 7. Tracker (weekly → `docs/metrics.md`)

| Week | Applications | Recruiter contacts | Screens | Interviews | Rate offered |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |

## 8. Highest-leverage moves (if you only do 3 things)
1. **AI-forward CV + recruiter blitz** (agencies place most outside-IR35 contracts).
2. **Ship Blog 3 (RAG on GCP)** — a live, tier-1 AI asset that proves “production”.
3. **Lead with evals + deterministic-first** — it's the differentiator every
   listing we found is asking for.