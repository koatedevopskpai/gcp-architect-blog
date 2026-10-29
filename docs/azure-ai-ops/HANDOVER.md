# Handover — Azure AI Ops post 1: "Why an AI Task Can Run Twice"

Last updated: 2026-10-29
Status: **Committed on `main`; `draft: true`; not deployed.**
Series: `azure-ai-ops` (post 1 of 3), category `sre-reliability`, cloud `azure`, proof tier 2
Article: `src/content/posts/sre-reliability/005-why-an-ai-task-can-run-twice.mdx`
Evidence: `public/evidence/why-an-ai-task-can-run-twice/`
Backlog topic: `022` (note: file prefix `005` is the series position, not the topic id)

This note lets a fresh Codex session continue without reconstructing context.

## 29 October 2026 — repository sync and tooling update

Supersedes the "untracked / not committed" statements below.

- The repository was synced to `origin/main` (`1e29591`) and the Azure package was
  committed in `8bdd1c3`. The working tree is clean.
- Authoring tooling now lives in the repository and applies to every post:
  `scripts/check-posts.mjs`, `scripts/evidence.py`, `docs/post-authoring.md`.
- `npm run check:posts` passes: 12 posts, 0 errors, 3 warnings (three evidence
  directory links have no `index.html`).
- The Azure manifest was re-frozen once to make the transcript portable:
  `test-results.txt` now uses LF, is 5,085 bytes, and hashes to
  `afe76d3461d1b74584d1312ebdd3a25442dc693c12faebcd03008b8f0784e45e`.
  Every other artifact hash is unchanged. `.gitattributes` now marks evidence as
  `-text` so Git never rewrites the published bytes.
- The post is still `draft: true`; the release runbook below still applies.
- Verification commands:
  `python scripts/evidence.py verify --slug why-an-ai-task-can-run-twice` and
  `npm run check:post -- why-an-ai-task-can-run-twice` (add `--render` after a
  non-draft build).

---

## 1. What happened in this session

The user asked for all related blog assets to be copied into
`C:\Users\koate\development\gcp-architect-blog` and for a completeness check
before publishing.

The article and evidence were **already staged** by an earlier pass (they were
untracked). This session:

1. Verified the staged article was byte-identical to the reviewed
   `outputs/Why-an-AI-Task-Can-Run-Twice.md`.
2. Verified all evidence hashes and the source archive.
3. Added the missing social assets (`ogImage` plus 1200x630 and 1200x504 PNGs).
4. Copied the review screenshots and JUnit XML into `docs/azure-ai-ops/review/`.
5. Built the site with the draft temporarily enabled, checked every internal and
   evidence link, then restored `draft: true` and rebuilt.
6. Reported publish-readiness. The user chose **"Hold for your review."**

Nothing was committed, pushed or deployed.

---

## 2. Current state

| Item | State |
|---|---|
| Article | Present, `draft: true`, `publishDate: 2026-10-25` |
| Frontmatter delta | `ogImage: "/og/005-why-an-ai-task-can-run-twice.png"` added this session |
| Evidence bundle | Present; hashes verified |
| Backlog topic 022 | `status: "planned"`; note still says "49 local tests" |
| Scorecard | Generated; not regenerated after this session |
| Git | Article, evidence, docs, example and OG PNGs are **untracked**; `scripts/gen-og.ps1` and `content-ops/*` are modified |
| `dist/` | Rebuilt with `draft: true` (59 pages); the article page is absent |
| Deploy | Not run. Push to `main` triggers `.github/workflows/deploy.yml` (Firebase) |

Do not treat the article as published. It is intentionally invisible to the
build, RSS, sitemap, category pages and cloud pages.

---

## 3. Evidence verification (completed 2026-10-28)

| Check | Result |
|---|---|
| Article vs reviewed output | Identical except the added `ogImage` line |
| `manifest.json` artifacts | 6/6 SHA-256 and byte counts match |
| Source ZIP internal `MANIFEST.sha256` | 76/76 files match; 0 missing; 0 mismatched |
| ZIP size / hash | 74,997 B / `228f01473d8683ea9e8a59def5c8d03649d80c60cf43b78a0dd2c8410a7ca8cc` |
| Test transcript | 50 collected: **47 passed, 3 skipped, 0 failed** |
| Both article tests | Present and pass; quoted block matches `tests/test_recovery.py` lines 117-138 |
| `Repository.finish` fence | Matches the SQL quoted in the article |
| Build (draft enabled) | 66 pages; 7 Mermaid diagrams rendered |
| Link check | 19 internal links + 3 evidence links resolve; 0 broken anchors |
| OG images | `public/og/005-why-an-ai-task-can-run-twice.png` (31,152 B), `-devto.png` (30,134 B) |

The 3 skips are environmental, not failures:

- Azurite visibility/receipt integration - emulator not configured
- Azurite visibility-expiry integration - emulator not configured
- POSIX SIGTERM process test - Windows

Article claims are limited to local code evidence. There is no Azure deployment,
paid inference, billing measurement or live-recovery claim.

---

## 4. Git state — be surgical

`git status --short` shows many unrelated in-flight changes (AWS Lambda work,
`run-live.ps1`, cloud-run-canary scaffold, `debug.log`, etc.). Do **not**
`git add -A` or `git add .`.

Relevant paths for this post:

```
src/content/posts/sre-reliability/005-why-an-ai-task-can-run-twice.mdx   (untracked)
public/evidence/why-an-ai-task-can-run-twice/                           (untracked)
public/og/005-why-an-ai-task-can-run-twice.png                          (untracked)
public/og/005-why-an-ai-task-can-run-twice-devto.png                    (untracked)
docs/azure-ai-ops/                                                      (untracked)
examples/why-an-ai-task-can-run-twice/                                  (untracked)
scripts/gen-og.ps1                                                      (modified)
content-ops/backlog.yaml                                                (modified, also has AWS edits)
content-ops/scorecard.md                                                (modified, also has AWS edits)
```

The two `content-ops` files already contain unrelated AWS publication edits.
Stage them only if those edits are intended to ship with this commit; otherwise
use `git add -p` and take only the topic-022 and scorecard hunks.

---

## 5. Release runbook (only after explicit user approval)

1. **Flip the article**

   ```powershell
   $p = "src\content\posts\sre-reliability\005-why-an-ai-task-can-run-twice.mdx"
   (Get-Content -LiteralPath $p -Raw) `
     -replace 'draft: true', 'draft: false' `
     -replace 'publishDate: 2026-10-25', 'publishDate: 2026-10-28' |
     Set-Content -LiteralPath $p -NoNewline
   ```

   Confirm the user still wants `2026-10-28`; the article body cites the
   25 October evidence run, which should stay.

2. **Update backlog topic 022** in `content-ops/backlog.yaml`. Match the shape
   used by topic 019:

   ```yaml
   - id: "022"
     title: "Why an AI Task Can Run Twice—and How I Tested Recovery"
     category: "sre-reliability"
     cloud: "azure"
     status: "published"
     publishedAs: "src/content/posts/sre-reliability/005-why-an-ai-task-can-run-twice.mdx"
     publishedOn: 2026-10-28
     proofTier: 2
     note: "Local code evidence: 47 passed, 3 skipped (50 collected). No Azure deployment, paid inference or billing claim."
   ```

3. **Regenerate the scorecard**

   ```powershell
   npm run score
   git diff content-ops/scorecard.md
   ```

4. **Update the internal review docs**

   - `docs/azure-ai-ops/POST_1_PUBLICATION_REVIEW.md`: change the stage line to
     published, with the release date.
   - `docs/azure-ai-ops/SERIES_PLAN.md`: update the post 1 publish gate. Tick
     every item that is true, record the accepted ZIP-instead-of-repo decision
     explicitly, and correct the stale "49 local tests" row to "47 passed, 3
     skipped (50 collected)". Do not tick the repository-link item as if a repo
     existed.

5. **Build and verify**

   ```powershell
   npm run build
   Test-Path dist\posts\sre-reliability\005-why-an-ai-task-can-run-twice\index.html
   Get-ChildItem dist\evidence\why-an-ai-task-can-run-twice
   ```

   With `draft: false` the build is 66 pages. With `draft: true` it is 59.

6. **Commit and push**

   ```powershell
   git add src/content/posts/sre-reliability/005-why-an-ai-task-can-run-twice.mdx `
           public/evidence/why-an-ai-task-can-run-twice `
           public/og/005-why-an-ai-task-can-run-twice.png `
           public/og/005-why-an-ai-task-can-run-twice-devto.png `
           docs/azure-ai-ops examples/why-an-ai-task-can-run-twice `
           scripts/gen-og.ps1
   git add -p content-ops/backlog.yaml content-ops/scorecard.md
   git commit -m "post: publish 005 Why an AI task can run twice (Azure AI ops 1)"
   git push origin main
   ```

   The push triggers Firebase Hosting deployment via GitHub Actions + Workload
   Identity Federation.

7. **Post-deploy checks**

   - `https://gcp-architect-blog.web.app/posts/sre-reliability/005-why-an-ai-task-can-run-twice/`
   - `/evidence/why-an-ai-task-can-run-twice/azure-ai-ops-lab-source.zip` downloads
   - `/og/005-why-an-ai-task-can-run-twice.png` returns 200
   - RSS and category page include the post

---

## 6. Open decisions

| # | Decision | Recommendation |
|---|---|---|
| 1 | **Source is a ZIP, not a `codeRepo`.** The series plan's post 1 gate says "repository link exists". | Accept the ZIP. The article is explicit that the source was an archive with no commit; do not invent a repo. |
| 2 | **Publish date.** Frontmatter says 2026-10-25; release would be 2026-10-28. | Set to the actual release date; keep the 25 October evidence sentence unchanged. |
| 3 | **Review of the `ogImage` delta.** The reviewed MDX gained one frontmatter line. | Low risk; social image only, body unchanged. |
| 4 | **Posts 2 and 3** (`006`, `007`) remain drafts with incomplete live evidence. | Out of scope for this release. |

---

## 7. Invariants and gotchas

- **Python 3.14 is required.** `src/worker/worker.py` line 48 uses
  `except ValidationError, ValueError:` (PEP 758, valid from 3.14). It is not a
  syntax error and must not be "fixed" by someone running 3.13.
- **The evidence is frozen.** Do not re-run `finalize_evidence.py` casually: it
  rewrites `manifest.json` (new `recorded_at_utc`) and hashes **every** file under
  the evidence directory. A stray `__pycache__` would enter the manifest. One was
  created during verification and deleted; keep the directory clean.
- **Do not add files to the evidence directory** (for example the JUnit XML)
  without regenerating the manifest. The JUnit copy lives in `docs/azure-ai-ops/review/`
  for that reason.
- **`public/` is copied into `dist/` wholesale.** Anything left there ships.
- **A green build does not prove the article page exists.** Drafts are filtered
  from routes, RSS and sitemap. Verify `dist` explicitly, or flip the draft and
  rebuild.
- **`gen-og.ps1` regenerates every OG image.** Re-running it on this machine is
  byte-stable for the existing files (verified). New entries belong at the end.
- **Test counts:** 50 collected = 47 passed + 3 skipped. The "49 tests" figure in
  older docs and the backlog note is stale.
- **Do not publish without explicit approval.** The user asked to hold for review
  on 2026-10-28.

---

## 8. Reproduce or regenerate

Original runnable source (23 October archive):

```
C:\Users\koate\Documents\Codex\2026-10-23\i-w\outputs\Azure-AI-Ops-Lab-Revised-Source\azure-ai-ops-lab
```

Preparation and verification tooling (one-off, outside the repo):

```
C:\Users\koate\Documents\Codex\2026-10-25\lo\work\
  prepare_post.py        # builds the ZIP, evidence excerpts and article
  finalize_evidence.py   # writes manifest.json, transcript and review note
  check_preview.mjs      # Playwright preview + link/asset checks
  publication-tests.xml  # JUnit source for the 47/3 result
  test-results.txt       # raw pytest transcript
  build-results.txt      # draft-enabled build log
  aiops-pg\              # disposable PostgreSQL data dir (server stopped)
```

Published originals of the reviewed outputs remain in:

```
C:\Users\koate\Documents\Codex\2026-10-25\lo\outputs\
  Why-an-AI-Task-Can-Run-Twice.md
  AI-worker-test-results.txt
  AI-worker-post-preview.png
  AI-worker-post-mobile.png
  Publication-review.md
```

To rerun the suite, use a disposable database whose name ends in `_test`:

```powershell
$env:TEST_DATABASE_URL = "postgresql://.../aiops_test"
$env:MIGRATION_DATABASE_URL = $env:TEST_DATABASE_URL
python -m alembic upgrade head
python -m pytest -v tests/test_recovery.py::test_post_commit_ack_failure_skips_second_ai tests/test_recovery.py::test_provider_response_before_commit_can_repeat
```

---

## 9. File map

| Path | Purpose |
|---|---|
| `src/content/posts/sre-reliability/005-why-an-ai-task-can-run-twice.mdx` | Article |
| `public/evidence/why-an-ai-task-can-run-twice/` | ZIP, manifest, transcript, code excerpts |
| `public/og/005-why-an-ai-task-can-run-twice*.png` | Social cards |
| `scripts/gen-og.ps1` | OG generator, including the post 1 entries |
| `docs/azure-ai-ops/SERIES_PLAN.md` | Three-post series plan and gates |
| `docs/azure-ai-ops/POST_1_PUBLICATION_REVIEW.md` | Publication preparation note |
| `docs/azure-ai-ops/review/` | Desktop/mobile screenshots and JUnit XML |
| `examples/why-an-ai-task-can-run-twice/README.md` | Companion download note |
| `content-ops/backlog.yaml` | Topic 022 |
| `content-ops/scorecard.md` | Generated ranking |

---

## 10. First commands for a fresh session

```powershell
cd C:\Users\koate\development\gcp-architect-blog
git status --short
git log --oneline -3
Select-String -LiteralPath src\content\posts\sre-reliability\005-why-an-ai-task-can-run-twice.mdx -Pattern '^draft:|^publishDate:|^ogImage:'
Get-ChildItem public\evidence\why-an-ai-task-can-run-twice -Recurse -File
Test-Path dist\posts\sre-reliability\005-why-an-ai-task-can-run-twice\index.html
```

Expected: `draft: true`, `publishDate: 2026-10-25`, the OG image line present,
seven evidence files, and `False` for the `dist` page.
