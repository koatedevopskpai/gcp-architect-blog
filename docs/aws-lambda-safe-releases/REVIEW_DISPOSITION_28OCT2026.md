# Review disposition — 28 October 2026

External review comments on the published draft of *AWS Lambda safe releases:
testing an automatic rollback* (`019-aws-lambda-safe-releases.mdx`).

Context: the article was built and deployed to Firebase Hosting on 28 October
before this review. It has **not** been committed or pushed to GitHub. This
document records which comments were applied, which were not, and why.

Supersedes the article hash in `PUBLICATION_REVIEW_22OCT2026.md`; the evidence
hashes in `public/evidence/aws-lambda-safe-releases/manifest.json` are unchanged.

## Applied

| Comment | Disposition |
|---|---|
| The 122 `unknown` responses weaken the evidence | Clarified that `unknown` is not a third outcome: it is exactly the 120 HTTP 500 plus two HTTP 429 responses, none of which carry the version marker. The article still does **not** claim an observed routing share. |
| The 429s are waved away | Added a labelled hypothesis: a fixed 10 req/s should be below default API Gateway throttling, so a transient load-tool/concurrency limit or a brief Lambda concurrency ceiling is more likely. Kept as a hypothesis, not a finding. |
| The separate capture run is confusing | Renamed the section **"Illustration, not evidence: the console capture"** and added an explicit "this section is optional" line. The image remains because it is the only visual of the configured split. |
| The Cloud Run comparison is thin | Added a **Policy owner** row and a direct point: AWS packages the stop-and-roll-back decision into CodeDeploy; Cloud Run exposes traffic primitives and leaves the policy to the operator. |
| It reads like an evidence report; add a fast summary | Added a one-paragraph **TL;DR** callout after the opening: what ran and happened, what it proves, what it does not. The body keeps the evidence because that is the blog's contract. |
| The intro says "sent 10% of traffic", which the body later disclaims | Changed to "configured a deliberate 10% canary"; the architecture diagram now says "configured 90/10". |

## Not applied

| Comment | Reason |
|---|---|
| Omit the separate-run screenshot entirely | It is the only console view of the configured split, and the post now labels it as optional illustration. Cutting it would remove the visual without adding evidence. |
| Reconcile the 429 root cause | The evidence pack has aggregate status counts only; no per-request timestamps or throttle logs were captured. Inventing a cause would be worse than the stated hypothesis. |
| Prove the observed canary share | Not possible from the saved load file. The deployment record proves the configured split; the 500s and rollback prove the failure path. The claim boundary stays explicit. |
| Cut caveats to make it read faster | Rejected as a goal. The caveats are the evidence product for a tier-1 claim. The new summary gives a fast path without deleting the audit trail. |

## Second review round (same day)

The reviewer accepted the evidence fixes and asked for three narrative changes.

| Comment | Disposition |
|---|---|
| The TL;DR is still not a fast single paragraph | Replaced the four-part callout with a **one-paragraph TL;DR** directly after the opening. |
| The opening block packs experiment, result, caveat and link together | Split into three short paragraphs: what I did, what the run recorded, what it does and does not prove. |
| The 122 = 120 + 2 arithmetic should be visual | Added a compact equation block under the evidence bullets: `3,479 + 120 + 2 = 3,601` and `120 + 2 = 122 unknown`. |

Not changed: overall density. The post remains an evidence-first write-up; the
TL;DR and split opening give a fast path without removing the audit trail.

## Third review round — standalone review copy

The user supplied `docs/AWS-Lambda-Safe-Releases-Revised.html`, a standalone
"final review copy" dated 28 October. Its new factual claims were checked against
the saved evidence before adoption:

| Claim | Check |
|---|---|
| Faulty deployment 02:09:16.585 → rollback succeeded 02:11:59.561 UTC | Matches `deployment.json` and `codedeploy-group.json`; 2 m 42.976 s, rounded to 2 m 43 s |
| Rollback deployment `d-YGITAAD6K` succeeded | Matches `codedeploy-group.json` `lastSuccessfulDeployment` |
| Alarm: `Sum`, 60 s, 2 of 2 datapoints, threshold 1, missing data non-breaching | Matches `alarms.json` |
| API Gateway route limit 20 req/s, burst 50 | Matches `infra/main.tf` |
| Load tool records local exceptions as status 0 | Matches `scripts/load.py` |
| 122 `unknown` = 120 HTTP 500 + 2 HTTP 429 | Matches `load.json` counts |
| Test command path exists | Matches `tests/test_handler.py` (4 tests pass) |

Adopted: three-paragraph opening, Mermaid request-flow figure, version table,
alarm-configuration table, alarm-to-rollback HCL section, controller timeline,
status table, evidence-backed 429 explanation, reproduce prerequisites, and the
evidence-scope section moved to the end.

Changed while adopting: absolute production links converted to site-relative
links; the standalone HTML/CSS figure replaced with a Mermaid diagram; the
review-copy banner/footer removed.

Not adopted: the separate TL;DR callout was dropped because the new three-paragraph
opening now performs that job. If a boxed summary is preferred, it can be added
back without changing the body.

## Remaining open work

- Recorded walkthrough video (currently a script, not a recording).
- Native-helper parity follow-up (`NATIVE_HELPER_REVIEW.md`).
- Full unattended automation freeze was not claimed and is still open.

## Article hash after review edits

SHA-256 `src/content/posts/platform-engineering-idp/019-aws-lambda-safe-releases.mdx`:

`B32DE63E141552712EE77E74F3A98534F4FA63554B7C6245D19B33AC2E6B6D9E`
