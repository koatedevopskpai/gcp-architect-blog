# Replication note — 17 November 2026

This bundle contains two historical receipts and one curated excerpt from a later replication. They are
different kinds of evidence and are kept in separate files.

## What was added after the correction

A preregistered replication ran the same six-case evaluation twice against a fresh build, with the
judge's raw responses retained. Both runs scored the verbatim retention answer **0.3333**.

The trace shows why: the judge split the answer into three statements, marked
“Customer data must be deleted.” and “Customer data must be deleted after contract termination.”
unsupported (verdict 0), and “Customer data must be deleted within 30 days.” supported (verdict 1).
Faithfulness is 1/3 in both runs.

`replication-trace-2026-11-17.json` holds those statements, verdicts, reasons, run identifiers, the
paid seal hash and the documented deviations. It is a curated excerpt, not the sealed artifact.

## What the replication does not do

- It does **not** recover the historical trace. The historical receipts never contained statement-level
  output, and no cache or log survives.
- It does **not** explain the historical 0.3333 vs 0.6667 difference. Different build, different
  apparatus.
- It is **informed**, not blind: the published numbers were known before the runs.
- It makes no claim about unsupported answers, so no threshold or error-rate conclusion follows.

## Deviations that limit comparability

1. Every provider path went through a local metering proxy that held the credential.
2. The proxy injected `max_tokens=16384` into 120 judge calls (60 per run). The other 12 chat calls were service generation and carried their own limit. The largest completion across all 132 chat calls was 203 tokens (203 in run A, 201 in run B); every call finished with `stop`. The injected judge bound differs from the historical request.
3. Historical receipts record the judge alias `gpt-4o-mini`; the new runs requested and reported `gpt-4o-mini-2024-07-18`. The earlier alias resolution is not established by this comparison.
4. Computed cost uses the listed rate table with a 2× multiplier. It is not an invoice; no provider
   invoice was consulted.

## Seals

| Phase | Manifest | SHA-256 |
|---|---|---|
| Historical receipts (source repository) | `artifacts/experiments/` (git-ignored) | `b2bb3928…` and `7868294b…` per file |
| Replication, paid phase | `ragas/PAID-SEAL.json` | `9080857e8888c0561b6fe38e056207addd43142b8fc0f77d14d265b945ad7caa` |

The replication's combined report and the full sealed output are not published here. They are held by
the author; this note records what was used and what was left out.
