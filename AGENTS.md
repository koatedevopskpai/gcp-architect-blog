# Blog authoring instructions

## Post visuals

For every new blog post, include a clear visual near the opening that helps the
reader understand the result or architecture. This is the user's default for
future posts, established on 28 October 2026.

- For measured experiments, use a result-led summary with the exact measurement
  boundary and evidence-backed figures. For conceptual posts, use an architecture
  or process illustration without invented measurements.
- Label designed graphics as illustrated summaries. Keep them distinct from real
  console captures and label synthetic lab results accurately.
- Keep text readable at mobile size. Verify desktop/mobile layout and light/dark
  presentation; avoid diagrams that shrink into long, unreadable strips.
- Include descriptive alt text, a short caption, responsive dimensions and a link
  to the full-size asset when the graphic contains detailed text.
- Store designed assets under public/images/<post-slug>/; captured operational
  evidence remains under public/evidence/<post-slug>/.
- Prepare a shareable image for the accompanying LinkedIn draft. Reuse the blog
  graphic where it remains readable in the feed.
- Build and inspect the rendered post before delivery.

## Asset location

The canonical blog workspace is `C:/Users/koate/development/gcp-architect-blog`.
Keep all final blog source, visual assets, review documents and LinkedIn material
inside this repository. Chat workspaces may hold temporary scratch files, but
copy deliverables back here before reporting completion.

- Site images: `public/images/<post-slug>/`.
- Publishable operational evidence: `public/evidence/<post-slug>/`.
- Review documents and QA captures: `docs/<post-slug>/review/`.
- LinkedIn drafts and editable share graphics: `docs/distribution/<post-slug>/`.
- Preserve differing local work; archive a published snapshot rather than
  overwriting it merely to match another checkout.
