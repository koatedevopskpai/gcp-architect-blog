# Post authoring workflow

Every post is a package: the article, optional evidence, a social card, and review
captures. This workflow applies to every post in `src/content/posts/`, existing
and future.

## 1. Scaffold

```bash
npm run new:post -- <category> <id> "<title>"
```

The script creates `src/content/posts/<category>/<id>-<slug>.mdx`, refuses a
duplicate numeric prefix in that category, and leaves `draft: true`.

## 2. Write the article

Required frontmatter is validated by the content schema and by
`npm run check:posts`:

- `title` max 120 characters.
- `description` 80-200 characters.
- `category` must be one of the seven pillars.
- `cloud` is `aws`, `gcp`, `azure` or `multi`; omit it for GCP.
- `publishDate`, `impact`, `demand`, `confidence`, `effort`, `proofTier`.
- `ogImage` is optional but recommended: `/og/<id>-<slug>.png`.
- `draft: true` until the publication review is complete.

Use `public/images/<slug>/` for designed diagrams and
`public/evidence/<slug>/` for captured operational output. Review captures belong
in `docs/<slug>/review/`.

## 3. Build an evidence bundle

Put the runnable source outside `public/` (a lab checkout) and let the toolkit
verify and package it. If the source has a `MANIFEST.sha256`, every listed file is
checked before it enters the ZIP.

```bash
python scripts/evidence.py bundle \
  --slug my-post \
  --source ../my-lab \
  --notes docs/my-post/PUBLICATION-NOTES.md \
  --excerpts src/app.py,tests/test_app.py
```

This writes `public/evidence/<slug>/<source-name>-source.zip` and copies the
named excerpts. Do not hand-edit files after this point.

## 4. Record the run

Keep the post-specific run metadata in `content-ops/evidence/<slug>.json`:

```json
{
  "slug": "my-post",
  "run_id": "20261029-local-publication",
  "recorded_at_utc": "2026-10-29T10:00:00+00:00",
  "source_snapshot": "29 October 2026 reference bundle",
  "source_commit": null,
  "source_commit_note": "Source supplied as an archive; SHA-256 identifies it.",
  "result": { "passed": 12, "skipped": 0, "failed": 0, "errors": 0 },
  "skips": [],
  "claims": {
    "claim_name": "tests/test_app.py::test_the_claim"
  },
  "limits": ["No cloud deployment", "No paid inference"]
}
```

- `claims` maps a short claim name to `path::test_name`. The verifier checks that
  the test exists in the public excerpt.
- `limits` is published in the manifest so the claim boundary travels with the
  evidence.
- `result` is optional when `--junit` is supplied; JUnit counts win.

Then normalise the transcript and write the manifest in one pass:

```bash
python scripts/evidence.py finalize \
  --slug my-post \
  --config content-ops/evidence/my-post.json \
  --junit work/publication-tests.xml \
  --raw work/test-results.txt \
  --command "python -m pytest -v --junitxml=publication-tests.xml"
```

This writes `test-results.txt` and `manifest.json` and verifies both. Use
`transcript` or `manifest` separately when only one side changed.

## 5. Verify

```bash
python scripts/evidence.py verify --slug my-post
```

Verification checks every artifact hash and byte count, rejects unlisted files in
the evidence directory, and checks that each claim test exists in the excerpt.
Exit code 1 means the manifest and the published files disagree.

## 6. Check every post

```bash
npm run check:posts
```

Static checks, suitable for CI:

- frontmatter limits and valid category/cloud/date fields
- every `/evidence`, `/images`, `/og` and `/favicon` reference
- internal `/posts/...` routes
- same-post and cross-post anchors
- evidence manifests: hashes, sizes, listed-vs-actual files, claim tests

One post:

```bash
npm run check:post -- my-post
```

Rendered checks (after `npm run build`, with the post not draft):

```bash
npm run check:post -- my-post --render
```

This serves `dist/`, checks broken anchors/images and horizontal overflow at
1440px and 390px, and writes screenshots to `docs/<slug>/review/`.

## 7. Publish

1. Set `draft: false` and the real `publishDate`.
2. Update `content-ops/backlog.yaml` to `status: "published"` with `publishedAs`
   and `publishedOn`.
3. Run `npm run score` and review the scorecard diff.
4. Run `npm run check:posts`, `npm run build` and the rendered check.
5. Commit on a branch, open a pull request for a Firebase preview deploy, then
   merge to `main`.

## Rules

- **Evidence is byte-exact.** `manifest.json` hashes the published files. Never
  add, remove or rewrite a file in `public/evidence/<slug>/` after publishing.
  `.gitattributes` marks evidence as `-text` so Git does not convert line endings.
- **The tools write LF.** `evidence.py` uses `newline="\n"` for text output, so a
  fresh bundle is identical on Windows and Linux.
- **No local paths in public evidence.** The transcript command redacts the repo
  root and the user profile by default. Review the output before committing.
- **Drafts stay out of the build.** `draft: true` removes the post from routes,
  RSS and the sitemap. A green build does not prove the page renders; use
  `--render`.
- **One claim, one test.** If a claim cannot be tied to a named test or a captured
  artifact, remove the claim or label it as an estimate.
