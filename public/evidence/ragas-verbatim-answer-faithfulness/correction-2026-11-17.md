# Correction and evidence note — 17 November 2026

**Status:** published with the article as a correction record. The receipts in this directory are
verbatim copies of the local run artefacts; their bytes and hashes are unchanged.

## What the two surviving receipts show

| Run | Label | Retention-answer faithfulness | Six-sample mean | Tokens | Duration |
|---|---|---|---:|---:|---:|
| `ragas-20261117T005412Z` | `judge-gpt4o-mini` | **0.3333** | 0.8889 | 45,091 | 86.5 s |
| `ragas-20261117T020133Z` | `langchain-check` | **0.6667** | 0.9444 | 45,043 | 107.4 s |

For the retention case the recorded question, answer, ordered contexts, reference and dataset hash
(`23c93e94…`) are identical between the two runs.

Context precision, context recall and answer correctness match across all six samples. Answer relevancy
also changes for the retention case, from 0.8259 to 0.7891.

## What was corrected

An earlier version of this article claimed the faithfulness result repeated identically across two
runs. That claim is not supported by the surviving pair and could not be checked against the pair it
was originally written from: the runner names its output `ragas-<label>.json`, and a later execution
using the same label replaced the earlier receipt. Filesystem creation times show that path was written
twice within about three minutes.

The earlier claim was written at 00:56 UTC, before the second surviving run existed. It has never been
verifiable from the files that remain.

## What is not retained

Neither receipt contains extracted statements, per-statement support verdicts or raw judge responses.
There is no RAGAS cache entry for these runs, no container survives (they ran with `--rm`), and the
token ledger records usage figures without prompt or completion text.

The failing stage is therefore unknown. Extraction, support checking, result integration and other
steps in the scoring pipeline all remain candidates.

## Unresolved environment difference

The evaluator image was rebuilt between the two surviving runs. RAGAS was pinned (`ragas==0.4.4`); the
LangChain transport that formats judge prompts was not, and the earlier image is no longer present
locally. Prompt token totals differ by one token and completion totals by 47, which suggests the
prompts were materially similar, but request payloads were never stored.

## What this note does not do

It does not re-run the judge, reconstruct claims from a rounded score, or assert a cause. A score of
0.3333 is consistent with several different claim counts and several different failure modes; the
number is not a trace.
