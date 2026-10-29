# Publication snapshot — 25 October 2026

This is the unchanged 23 October reference source, supplied to reproduce the
article's local failure tests. It is not a production deployment recommendation.
Python 3.14 and a disposable PostgreSQL database are required.

The recovery tests use real PostgreSQL and a MemoryQueue policy double. Their
redeliver() method does not simulate real broker timing. The model is a local
stub. No Azure deployment, paid inference or measured cloud cost is demonstrated.

A subsequent review identified unresolved defects outside the narrow claim:
readiness requires exactly schema revision 0001; reconciliation can amplify
notifications; invalid publisher envelopes lack a permanent-failure path; release
sequencing, probe/smoke timeouts and RBAC propagation need further work.
Graceful shutdown can also create duplicate notifications. Passing the suite does
not close these findings. Do not treat the Azure release files as validated.

The included docs/VALIDATION.md records historical authoring checks. Consult the
blog's adjacent test-results.txt and manifest.json for this publication's run.
MANIFEST.sha256 verifies the original 76 files; this note is added separately.

Download: ../../public/evidence/why-an-ai-task-can-run-twice/azure-ai-ops-lab-source.zip

Run the two tests named in the article after following the bundle README.
