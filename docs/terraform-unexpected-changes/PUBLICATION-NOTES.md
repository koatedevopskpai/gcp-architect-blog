# Publication preparation — Terraform unexpected changes

Status: approved for commit on 8 November 2026; awaiting deployment.

Source: src/content/posts/platform-engineering-idp/025-terraform-unexpected-changes.mdx
Proposed URL: https://gcp-architect-blog.web.app/posts/platform-engineering-idp/025-terraform-unexpected-changes/

The article is engineering guidance with an illustrative scenario (proof tier 3).
No measured 150-resource incident, production Terraform experiment, or AWS change is claimed.

Final corrections: explicit CI handling of exit code 2; consistent British spelling.
The in-page visual adapts to its actual container width, including the contents sidebar.
The downloadable/share image is public/images/terraform-unexpected-changes/review-process.png.

Checks:
- npm run check:posts: 13 posts, 0 errors; 3 pre-existing warnings on other articles.
- npm run build: 69 pages, 7 Mermaid diagrams.
- npm run check:post -- terraform-unexpected-changes --render: 0 errors, 0 warnings.

Before deployment, update the backlog entry from planned to published, record publishedAs
and publishedOn, and refresh the scorecard. If deploying on another day, update publishDate.
The current draft:false setting includes the article in the local build for review.

Keep unrelated local evidence and review work out of the publication commit.
