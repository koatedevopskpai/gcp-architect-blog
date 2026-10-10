// @ts-check
import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";

// Update `site` to your Firebase Hosting URL (https://<site-id>.web.app) or custom domain.
export default defineConfig({
  site: "https://gcp-architect-blog.web.app",
  integrations: [mdx(), sitemap()],
  markdown: {
    shikiConfig: {
      themes: { light: "github-light", dark: "github-dark" },
      wrap: false,
    },
  },
  redirects: {
    "/tracks": "/categories",
    // Single entry (no trailing-slash twin): Astro treats both forms as the
    // same route, and Firebase Hosting's trailingSlash setting serves either.
    "/posts/data-mlops/002-retrieval-mode-benchmark-three-modes-tied": "/posts/data-mlops/002-retrieval-mode-benchmark-four-modes",
  },
});
