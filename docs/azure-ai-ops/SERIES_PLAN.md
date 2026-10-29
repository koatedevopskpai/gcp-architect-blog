# Azure AI Ops — three-post series plan

Status: **draft series, unpublished**
Date: 2026-10-23
Source codebook: `C:\Users\koate\development\azure-ai-ops-lab\docs\PLAN.md`
Blog: `gcp-architect-blog`
Series key: `azure-ai-ops`
Cloud track: `azure`

## The editorial bet

Most AI platform writing starts with the architecture. This series starts with a
failure a reader can picture:

> An AI request succeeds. The worker crashes before it records the result. The
> queue delivers the task again. Can the application safely retry, and could
> that trigger another paid model call?

The useful contribution is not a new pattern. Microsoft documents the
transactional outbox; Temporal and others discuss AI workflow reliability. The
contribution is a small, reproducible Azure lab that shows the failure windows,
the code that closes some of them, and the ones that remain open.

**The thesis of the series:** preventing duplicate stored results does not
guarantee a single model invocation. Idempotency, ownership, the outbox and
provider-side idempotency solve different problems.

## Audience

Cloud engineers, developers, platform teams and SREs. A general IT reader should
be able to follow the first few paragraphs because the opening is a restaurant
ticket, not a queue API. The architecture arrives only after the problem is
clear.

## Evidence boundary

At the time of writing:

| Claim | Status |
|---|---|
| 49 local tests pass | Yes |
| Local end-to-end smoke test completes | Yes |
| Live Azure deployment | Pending |
| Real model calls and token usage | Pending |
| Cloud cost measurements | Pending |
| Recovery exercises against Azure | Pending |

These boundaries belong in the posts. They are not a disclaimer bolted onto the
end; they tell the reader what kind of evidence to expect. No post may imply that
a local test is a cloud result.

## The three posts

| # | Title | File | Job |
|---|---|---|---|
| 1 | **Why an AI Task Can Run Twice—and How I Tested Recovery** | `src/content/posts/sre-reliability/005-why-an-ai-task-can-run-twice.mdx` | The flagship failure story: crash windows, idempotency limits, ownership, outbox in brief |
| 2 | **Accepting work when the queue is unavailable: PostgreSQL, transactions and the outbox** | `src/content/posts/sre-reliability/006-accepting-work-when-queue-unavailable.mdx` | The lost-work window and the transactional outbox |
| 3 | **Operating an AI worker on Azure: shutdown, identity, deployment and cost** | `src/content/posts/sre-reliability/007-operating-ai-worker-on-azure.mdx` | The live operating checklist; publishes only after cloud checks |

All three are in `sre-reliability` so the series has one discoverable home. The
blog has no automatic series navigation, so forward links between unpublished
posts are deferred to avoid 404s.

## Post 1 — the duplicate task

**Reader:** an engineer who has used a queue but has not had to reason about
delivery semantics.

**Promise:** after this post, the reader can explain why a duplicate delivery is
not the same as a duplicate model call, and can name the guard for each window.

### Sections

1. **The everyday version** — a restaurant ticket, a dropped plate and a
   reprinted order. No architecture yet.
2. **The simple system** — client, API, PostgreSQL, queue, worker, model, result.
3. **The crash window** — the two distinct failures: after the result commit but
   before the acknowledgement, and after the model returns but before the result
   commit.
4. **What I tested** — inject the crash, let the message become visible again,
   assert the model call count. The post-testing section states plainly that the
   second window can repeat the call.
5. **The result is not the invocation** — a table of four duplicates: client
   retry, queue redelivery, concurrent workers, provider retry.
6. **Task ownership, plainly** — claim the task before calling the model; complete
   only if the worker still owns it. Ownership is concurrency control, not an
   exactly-once guarantee.
7. **Where the outbox fits** — the outbox makes acceptance atomic; it does not
   make the worker execution exactly once.
8. **Evidence and limits** — 49 local tests, local E2E, then the pending Azure
   checks.
9. **Companion repository** — the full files, not all 77 files in the post.

### Code excerpts

- The failure test: crash before result commit, redeliver, assert two model calls.
- The ownership guard: conditional claim and conditional completion.

### Publish gate

- [ ] Repository link exists.
- [ ] Test output for the 49 tests is linked.
- [ ] Local E2E output is linked.
- [ ] The post says local, not Azure.
- [ ] No claim of exactly-once execution.

## Post 2 — accepting work when the queue is unavailable

**Reader:** the same engineer, now asking what happens before the worker runs.

**Promise:** the reader can explain the commit-then-send gap and implement a
PostgreSQL outbox without pretending it is a distributed transaction.

### Sections

1. **Two writes, one gap** — task row and queue message; the three outcomes.
2. **Why sending first is not a fix** — the worker can receive a message before
   the row is visible.
3. **The outbox in plain terms** — a to-do list written in the same transaction.
4. **The transaction** — task and outbox row in one commit; idempotency
   constraint still decides duplicate requests.
5. **The relay** — `FOR UPDATE SKIP LOCKED`, claim, commit, send, mark. Do not
   hold a database transaction across the network call.
6. **The duplicate the outbox creates** — at-least-once relay, so the worker's
   terminal check remains necessary.
7. **What PostgreSQL gives you** — transactions, unique constraints, row locks,
   `SKIP LOCKED`; not a transaction with Storage Queue.
8. **Evidence and limits** — local tests, local E2E; live queue outage and relay
   pending.
9. **The next check** — link to post 3 when it is published.

### Code excerpts

- API transaction writing task and outbox row.
- Relay claim query and the send/mark loop.

### Publish gate

- [ ] Local transaction tests are linked.
- [ ] The post distinguishes acceptance durability from execution exactly-once.
- [ ] The live queue-outage exercise is either completed or explicitly pending.
- [ ] The outbox relay's duplicate-delivery behaviour is stated.

## Post 3 — operating the worker on Azure

**Reader:** someone deciding whether the lab is operable, not just testable.

**Promise:** a concrete checklist for shutdown, identity, deployment, monitoring
and cost, with no invented cloud numbers.

### Sections

1. **What local tests cannot prove** — SIGTERM timing, RBAC propagation, real
   queue visibility, real model latency and cost.
2. **Shutdown** — SIGTERM, grace period, nack with visibility zero, the five
   checks that make the shutdown test real.
3. **Identity** — user-assigned identities and the minimum role table; Key Vault
   references, no secret values.
4. **Deployment** — migration Job, revisions, readiness, traffic shift, rollback
   by traffic, not redeploy.
5. **Monitoring** — queue depth, oldest message age, outbox lag, retries, DLQ,
   model latency, tokens per task, trace parentage.
6. **Cost** — the components to measure and the fact that the actual figures are
   pending. No estimate presented as measured.
7. **The publish gate** — the checkboxes that must be true before this post goes
   live.
8. **What this does not prove** — no production scale, multi-region or GPU claim.

### Code excerpt

- The worker revision's `terminationGracePeriodSeconds` and the identity/secret
  reference shape.
- Optionally, one trace or KQL query once the live data exists.

### Publish gate

- [ ] Successful deploy run from CI.
- [ ] Failed required check blocking a PR.
- [ ] Key Vault reference resolved through managed identity.
- [ ] Migration Job success and a failed migration stopping the release.
- [ ] Bad revision rolled back by traffic shift.
- [ ] Live SIGTERM releasing an in-flight message.
- [ ] Real model call through the worker.
- [ ] Trace showing API and worker spans for one task.
- [ ] Live recovery exercise recorded.
- [ ] Measured cost table, not estimates.

Do not publish this post before the cloud checks. The draft is intentionally
honest about being a checklist, not a result.

## Metadata

| Post | `category` | `cloud` | `series` | `seriesOrder` | `proofTier` |
|---|---|---|---|---|---|
| 1 | `sre-reliability` | `azure` | `azure-ai-ops` | 1 | 2 |
| 2 | `sre-reliability` | `azure` | `azure-ai-ops` | 2 | 2 |
| 3 | `sre-reliability` | `azure` | `azure-ai-ops` | 3 | 2 |

`proofTier: 2` reflects local/code evidence. Move each post to tier 1 only when
the live evidence exists.

## Cross-links

Published posts that are safe to link now:

- Cloud Run golden path: `/posts/platform-engineering-idp/002-cloud-run-golden-path/`
- AWS Lambda safe releases: `/posts/platform-engineering-idp/019-aws-lambda-safe-releases/`
- SLOs for Cloud Run: `/posts/sre-reliability/004-slos-for-cloud-run/`

Forward links inside the series are deferred until both posts are live. The
drafts use “next in the series” notes instead.

## Publication order

1. Publish post 1 when the repository and local evidence links exist. The post
   explicitly says Azure is pending.
2. Publish post 2 after the outbox code and local transaction tests are linked.
   The live queue-outage exercise can remain pending if the post says so.
3. Publish post 3 only after the Azure checks and cost measurements are complete.

Do not wait for all three before contacting the hiring manager. Post 1 plus the
repository is the useful artefact; the remaining posts strengthen the story.

## What not to publish

- Day rate, IR35, recruiter questions or hiring-manager outreach.
- The Elixir slice unless BEAM is confirmed central to the role.
- “Production-grade”, “production-scale” or “exactly-once” claims.
- Any cloud cost presented as measured before it is measured.
- Any result that exists only in the plan. The plan is not evidence.
- All 77 files of the codebook. The posts guide one problem each; the repository
  holds the complete implementation.
