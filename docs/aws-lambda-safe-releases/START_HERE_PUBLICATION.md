# Publication pack — 22 October 2026

This folder contains the AWS Lambda safe-release publication assets. The Astro article is built locally and included in the next site build (`draft: false`); it has not been deployed or posted to LinkedIn.

## Files to use

- Article: `src/content/posts/platform-engineering-idp/019-aws-lambda-safe-releases.mdx`
- LinkedIn text: `docs/aws-lambda-safe-releases/LINKEDIN_POST.txt`
- Public evidence and two inspected console screenshots: `public/evidence/aws-lambda-safe-releases/`
- Recording script: `docs/aws-lambda-safe-releases/WALKTHROUGH_90_SECONDS.md`
- Automated checks: `PUBLICATION_CHECKS.json`
- Source/raw evidence: `examples/aws-lambda-safe-releases/evidence/raw/` — private, never upload.

## The story to use consistently

I built a synthetic AWS Lambda release lab. A healthy version was released to 100%, then a faulty version received a configured 10% canary. CodeDeploy recorded ALARM_ACTIVE and linked an automatic rollback; the saved alias returned to the previous healthy version and Terraform reported no changes. The six-minute primary load recorded 3,601 requests: 3,479 HTTP 200, 120 HTTP 500 and two HTTP 429. This was a resumed live experiment, not a production deployment or a fully unattended automation validation.

Primary run: `20261020-0251`, versions 1/2/3; rollback target 2.
Separate screenshot run: `20261020-030749-native-capture`, versions 5/6/7. Only healthy/canary views captured. Timed out at the alarm checkpoint; failure cleanup completed. Do not describe these images as a complete rollback sequence.

## Claim-to-artifact map

| Claim | Evidence under public/evidence/aws-lambda-safe-releases |
|---|---|
| 3,601 requests, 3,479/120/2 HTTP outcomes | 20261020-0251/load.json |
| Faulty deployment stopped because an alarm was active; automatic rollback linked | 20261020-0251/deployment.json |
| Previous healthy alias version 2 restored, weights absent | 20261020-0251/lambda-alias.json |
| Alarm configuration and later OK state | 20261020-0251/alarms.json and codedeploy-group.json |
| No post-rollback Terraform changes | 20261020-0251/post-rollback-plan.txt |
| Configured 90/10 weights, in the distinct capture run | 20261020-030749-native-capture/03-canary-alias.png |
| Fresh empty service inventory plus tag sweep; only budget in state | cleanup-20261022.json |
| Copied text provenance and screenshot hashes | manifest.json |

Do not derive an observed canary share or an exact outage duration from the HTTP aggregates. The two 429s have no isolated root-cause record. The run metadata names a pre-fix source commit; fixes were made during the resumed experiment, so it is not a byte-for-byte frozen execution of that commit. Current code is a reproduction recipe, not proof of an uninterrupted automated run. Native-helper parity issues remain a separate implementation follow-up (`NATIVE_HELPER_REVIEW.md`).

## Publishing order

1. Review the local article at http://127.0.0.1:8767/posts/platform-engineering-idp/019-aws-lambda-safe-releases/ while the preview server is running.
2. Resolve blocking findings in the publication review. Rebuild after any source/evidence change.
3. In the repository, run `$env:PLAYWRIGHT_BROWSERS_PATH='C:\Users\koate\AppData\Local\ms-playwright'; npm run build`. The environment setting uses the existing browser installation; nothing new needs installing.
4. Deploy the existing Firebase Hosting site with `firebase deploy --only hosting --project gcp-architect-blog` when you choose to publish. This uploads the entire current `dist`, not only this article, so review the build before deploying.
5. Check the live article and evidence links. Then paste `LINKEDIN_POST.txt` into LinkedIn and optionally attach the canary image with the separate-run caption. The URL in the text is the intended final URL and will not exist until deployment.
6. Record the 90-second walkthrough later if desired. Text and image publication can proceed without it. A script is not a recorded video.

No publishing, Git push or additional deployment was performed in this preparation session. Existing unrelated working-tree changes were preserved. The old raw screenshot files in this docs folder are not the publication set.
