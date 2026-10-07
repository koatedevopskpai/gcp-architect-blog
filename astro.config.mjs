// @ts-check
import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";

// Update `site` to your Firebase Hosting URL (https://<site-id>.web.app) or custom domain.
export default defineConfig({
  site: "https://koate-gcp.web.app",
  integrations: [mdx(), sitemap()],
  markdown: {
    shikiConfig: {
      themes: { light: "github-light", dark: "github-dark" },
      wrap: false,
    },
  },
  redirects: {
    "/tracks": "/categories",
  },
});
