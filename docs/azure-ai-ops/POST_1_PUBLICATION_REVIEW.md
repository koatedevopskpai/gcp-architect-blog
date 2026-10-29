# Publication preparation — Why an AI Task Can Run Twice

Stage: prepared and locally verified; draft remains true; not deployed.

- Replaced the obsolete pseudotest with the source test.
- Corrected ownership handling: defer active work; fence completion by token and expiry.
- Aligned architecture with implemented transactional outbox.
- Removed unsupported paid-inference, live recovery and current smoke claims.
- Supplied source ZIP, hashes, source excerpts and a public test transcript.
- Current test result: 47 passed, 3 skipped; both article failure tests passed.
- Broad lab defects remain disclosed in the download's PUBLICATION-NOTES.md.

Source snapshot: 23 October archive, verified against its 76-file manifest.
The lab's development directory contained only a plan; runnable source was found
in the prior Codex source deliverable. No source commit is claimed.

Publication assets are in public/evidence/why-an-ai-task-can-run-twice/.
The article stays draft until release. Update backlog status and series-plan
checkboxes only when their corresponding work is actually published/verified.

Build verification: npm run build passed with PLAYWRIGHT_BROWSERS_PATH pointing to the existing local browser cache. All 7 Mermaid diagrams rendered. Article preview checked at desktop and 390px mobile width; no document overflow, broken in-page anchors or missing linked evidence files. Original article restored to draft: true. Disposable PostgreSQL server stopped after tests.
