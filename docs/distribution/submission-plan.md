# Distribution & submission plan — GCP/AI content

Goal: turn published posts + the 4 pinned repos into **qualified inbound** —
without a phone, without X/Twitter, without Medium. Everything below is
**desktop-web friendly**; a couple of platforms need a free account first.

Rule: **value-first, link-second.** Most communities ban or downrank drive-by
links. Answer/contribute, and link only when it genuinely fits (or is allowed).

---

## 1. Channels (ranked, and what each is for)

| # | Channel | Audience | Account? | Desktop | Links OK? | Effort | Priority |
|---|---|---|---|---|---|---|---|
| 1 | **LinkedIn** (feed + Groups) | Recruiters, hiring managers, GCP/DevOps peers | yes | ✅ best on laptop | yes (inline) | low | **P0** |
| 2 | **Dev.to** | DevOps/cloud devs, SEO | free | ✅ Markdown + API | yes (canonical) | low | **P0** |
| 3 | **Hashnode** | same, good SEO | free | ✅ | yes (canonical) | low | **P0** |
| 4 | **Google Cloud Community** (googlecloudcommunity.com) | GCP practitioners | free | ✅ | context-dependent | med | **P1** |
| 5 | **Reddit** r/googlecloud, r/devops, r/kubernetes, r/aws, r/Terraform | broad, critical | free | ✅ (web) | strict; comment-first | med | **P1** |
| 6 | **Hacker News** | senior eng, high reach | free | ✅ | submit URL; no self-promo spam | low | **P1** |
| 7 | **Cloud/DevOps Slack** (Kubernetes, DevOps'ish, GCP communities) | insiders | invite-ish | ✅ | only where channel allows | med | **P2** |
| 8 | **GitHub** — Awesome GCP/Terraform lists (PR) + repo Discussions | builders | yes | ✅ | yes (by design) | med | **P2** |
| 9 | **Lobsters** | senior, invite-only | invite | ✅ | yes | low | **P2** |
| 10 | **Stack Overflow** | search demand | free | ✅ | answer-first, link as ref | med | **P2** |
| 11 | **Quora / DZone / InfoQ** | long-tail SEO | free | ✅ | yes | low | **P3** |
| 12 | **Dev newsletters** (e.g. Console.dev, DevOps'ish) | curators | email | ✅ | pitch only | low | **P3** |

**Not using:** X/Twitter, Medium, phone-only apps (per your constraints).
**Later (optional):** online meetups, podcast/CFP pitch.

---

## 2. Cross-posting without SEO damage

- Own blog is **canonical** (`https://gcp-architect-blog.web.app/...`).
- On Dev.to + Hashnode set the **canonical_url** to the blog post (they support it).
  This avoids duplicate-content penalties and keeps link equity on your domain.
- Slight rewrite on each platform (change the opening line) so it's not a
  verbatim mirror — better engagement, less spammy.

---

## 3. Timeline (14 days from first publish; D0 = post day)

| Day | Action | Where | Time |
|---|---|---|---|
| **D0** | Publish post already live; post **LinkedIn Variant A**; add repo to Featured | LinkedIn | 20 min |
| **D1** | Cross-post article (canonical) — two platforms, different opening lines | Dev.to + Hashnode | 45 min |
| **D2** | Post a **question/answer** thread (not a link) + 5 genuine comments | Google Cloud Community | 30 min |
| **D3** | Comment-first on r/googlecloud (build karma); post only if rules allow | Reddit | 30 min |
| **D4** | Submit to **Hacker News** ~14:00–16:00 UK; stay in the thread 2h | HN | 15 min + monitor |
| **D5** | Share in **2 Slack channels** where self-promo is allowed | Slack | 20 min |
| **D6–7** | Reply to every comment; **LinkedIn Variant C** as a follow-up | LinkedIn | 20 min |
| **D8** | PR the repo into 1–2 **Awesome lists** | GitHub | 20 min |
| **D9** | Answer 2 relevant **Stack Overflow** questions, reference the post | SO | 30 min |
| **D10** | Reshare best-performing post with a one-line update | LinkedIn | 10 min |
| **D11–14** | 15 min/day: comment on others' GCP/DevOps posts | LinkedIn/Reddit | 15 min/day |

**Cadence after this:** 1 deep post/week; same D0→D6 loop per post; keep the
15 min/day engagement habit (that's what compounds).

---

## 4. Etiquette & anti-spam (non-negotiable)

- **Read each community's rules first** (many subs ban links entirely — comment
  instead, put the link in your profile).
- **Reddit**: contribute before you ever post a link; if a sub requires karma or
  flair, earn it. Never post the same link to >2 subs the same day.
- **HN**: plain submission, understated title; no "please upvote". Be present;
  HN rewards substance and punishes marketing tone.
- **LinkedIn**: link inline (per your drafts); reply to comments in the first 2h.
- **One platform per day** (stagger) — simultaneous cross-posting reads as spam.
- Disclose authorship ("I wrote…"); never astroturf.

---

## 5. Account setup (desktop, do once)

- [ ] LinkedIn (have) — set Featured + About
- [ ] Dev.to account
- [ ] Hashnode account
- [ ] Google Cloud Community account
- [ ] Reddit account + join the 5 subs (start commenting)
- [ ] Hacker News account
- [ ] Join 2 Slack communities (Kubernetes, DevOps'ish)
- [ ] (optional) Lobsters invite, Stack Overflow

---

## 6. What to track (weekly → `docs/metrics.md`)

Per channel: impressions/views, clicks to the blog, comments, inbound DMs,
followers, and GitHub stars/clones. Judge **quality of inbound**, not vanity.

Link target bank (reuse in every post):
`https://gcp-architect-blog.web.app/posts/security-iam/001-workload-identity-federation-github-to-gcp/`
