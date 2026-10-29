#!/usr/bin/env node
/**
 * Post checker for gcp-architect-blog.
 *
 * Static checks (default):
 *   - frontmatter fields and date/description limits
 *   - absolute and relative asset references
 *   - internal post routes
 *   - same-post and cross-post anchors
 *   - evidence manifests: hashes, sizes, listed-vs-actual files, claim tests
 *
 * Rendered checks (--render, requires `npm run build`):
 *   - broken in-page anchors and images in the built page
 *   - horizontal overflow at 1440px and 390px
 *   - screenshots into docs/<slug>/review/
 *
 * Usage:
 *   node scripts/check-posts.mjs
 *   node scripts/check-posts.mjs --slug why-an-ai-task-can-run-twice
 *   node scripts/check-posts.mjs --slug 005 --render
 *   node scripts/check-posts.mjs --all --strict --json
 */
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import yaml from "js-yaml";

const ROOT = process.cwd();
const POSTS_DIR = path.join(ROOT, "src", "content", "posts");
const PUBLIC_DIR = path.join(ROOT, "public");
const DIST_DIR = path.join(ROOT, "dist");
const CATEGORY_KEYS = [
  "platform-engineering-idp",
  "sre-reliability",
  "security-iam",
  "data-mlops",
  "multicloud-enterprise",
  "finops",
  "architecture-leadership",
];
const CLOUD_KEYS = ["aws", "gcp", "azure", "multi"];

const opts = { slug: null, render: false, json: false, strict: false };
const cli = process.argv.slice(2);
for (let i = 0; i < cli.length; i += 1) {
  const arg = cli[i];
  if (arg === "--slug") opts.slug = cli[(i += 1)];
  else if (arg === "--render") opts.render = true;
  else if (arg === "--json") opts.json = true;
  else if (arg === "--strict") opts.strict = true;
  else if (arg === "--help" || arg === "-h") {
    console.log("Usage: node scripts/check-posts.mjs [--slug <text>] [--render] [--strict] [--json]");
    process.exit(0);
  } else {
    console.error(`Unknown argument: ${arg}`);
    process.exit(2);
  }
}

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.isFile()) out.push(full);
  }
  return out;
}

function rel(file) {
  return path.relative(ROOT, file).split(path.sep).join("/");
}

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function caseSensitivePath(base, relative) {
  const parts = relative.split("/").filter((part) => part && part !== ".");
  let current = base;
  for (const part of parts) {
    if (part === "..") {
      current = path.dirname(current);
      continue;
    }
    if (!fs.existsSync(current)) return null;
    const exact = fs.readdirSync(current).find((entry) => entry === part);
    if (!exact) return null;
    current = path.join(current, exact);
  }
  return current;
}

function stripFenced(text) {
  const lines = text.split(/\r?\n/);
  const out = [];
  let fence = null;
  for (const line of lines) {
    const match = /^\s*(`{3,}|~{3,})/.exec(line);
    if (match) {
      const marker = match[1][0];
      if (!fence) fence = marker;
      else if (marker === fence) fence = null;
      out.push("");
      continue;
    }
    out.push(fence ? "" : line);
  }
  return out.join("\n");
}

function stripInlineCode(text) {
  return text.replace(/`[^`\n]*`/g, " ");
}

function slugify(value) {
  return value
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, "")
    .trim()
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-");
}

function headingSlugs(body) {
  const lines = stripFenced(body).split(/\r?\n/);
  const seen = new Map();
  const slugs = [];
  for (const line of lines) {
    const match = /^(#{2,6})\s+(.+?)\s*#*\s*$/.exec(line);
    if (!match) continue;
    const text = match[2]
      .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
      .replace(/<[^>]+>/g, "")
      .replace(/[*_~]/g, "")
      .trim();
    const base = slugify(text);
    if (!base) continue;
    const count = seen.get(base) ?? 0;
    seen.set(base, count + 1);
    slugs.push(count ? `${base}-${count}` : base);
  }
  return slugs;
}

function extractLinks(body) {
  const text = stripInlineCode(stripFenced(body));
  const links = new Set();
  for (const match of text.matchAll(/\]\(\s*([^)\s]+)(?:\s+["'][^"']*["'])?\s*\)/g)) {
    links.add(match[1]);
  }
  for (const match of text.matchAll(/\b(?:href|src)\s*=\s*["']([^"']+)["']/g)) {
    links.add(match[1]);
  }
  return [...links];
}

function parsePost(file) {
  const text = fs.readFileSync(file, "utf8");
  const front = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(text);
  if (!front) return { file, error: "missing YAML frontmatter" };
  let data;
  try {
    data = yaml.load(front[1]) ?? {};
  } catch (error) {
    return { file, error: `invalid frontmatter: ${error.message}` };
  }
  const id = path.relative(POSTS_DIR, file).replace(/\\/g, "/").replace(/\.(md|mdx)$/i, "");
  const slug = path.basename(file).replace(/\.(md|mdx)$/i, "").replace(/^\d+-/, "");
  return {
    file,
    rel: rel(file),
    id,
    slug,
    data,
    body: text.slice(front[0].length),
    headings: headingSlugs(text.slice(front[0].length)),
    links: extractLinks(text.slice(front[0].length)),
  };
}

function validDate(value) {
  if (value instanceof Date) return !Number.isNaN(value.getTime());
  if (typeof value === "string") return !Number.isNaN(Date.parse(value));
  return false;
}

function checkFrontmatter(post) {
  const issues = [];
  const { data } = post;
  const add = (level, message) => issues.push({ level, message });
  if (typeof data.title !== "string" || !data.title.trim()) add("error", "title is required");
  else if (data.title.length > 120) add("error", `title is ${data.title.length} chars (max 120)`);
  if (typeof data.description !== "string" || !data.description.trim()) add("error", "description is required");
  else if (data.description.length < 80 || data.description.length > 200) {
    add("error", `description is ${data.description.length} chars (must be 80-200)`);
  }
  if (!CATEGORY_KEYS.includes(data.category)) add("error", `unknown category: ${data.category}`);
  if (data.cloud !== undefined && !CLOUD_KEYS.includes(data.cloud)) add("error", `unknown cloud: ${data.cloud}`);
  if (!validDate(data.publishDate)) add("error", "publishDate is missing or invalid");
  if (data.draft !== undefined && typeof data.draft !== "boolean") add("error", "draft must be a boolean");
  for (const key of ["impact", "demand", "confidence", "effort"]) {
    if (!Number.isInteger(data[key]) || data[key] < 1 || data[key] > 5) {
      add("error", `${key} must be an integer 1-5`);
    }
  }
  if (![1, 2, 3].includes(data.proofTier)) add("error", "proofTier must be 1, 2 or 3");
  if (data.ogImage !== undefined) {
    if (typeof data.ogImage !== "string" || !data.ogImage.startsWith("/")) {
      add("error", "ogImage must be an absolute site path");
    } else {
      const target = caseSensitivePath(PUBLIC_DIR, data.ogImage.replace(/^\//, ""));
      if (!target) add("error", `ogImage does not exist: ${data.ogImage}`);
    }
  }
  return issues;
}

function checkAsset(link) {
  const clean = decodeURIComponent(link.split("#")[0].split("?")[0]);
  const target = caseSensitivePath(PUBLIC_DIR, clean.replace(/^\//, ""));
  if (clean.endsWith("/")) {
    if (target && caseSensitivePath(target, "index.html")) return { ok: true };
    if (target && fs.statSync(target).isDirectory()) {
      return { warn: `directory link has no index.html: ${link}` };
    }
    return { error: `missing directory: ${link}` };
  }
  if (target && fs.statSync(target).isFile()) return { ok: true };
  return { error: `missing asset: ${link}` };
}

function checkEvidenceManifest(evidenceSlug) {
  const dir = path.join(PUBLIC_DIR, "evidence", evidenceSlug);
  const manifestPath = path.join(dir, "manifest.json");
  const issues = [];
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  } catch (error) {
    return [{ level: "error", message: `cannot read manifest: ${error.message}` }];
  }

  if (Array.isArray(manifest.artifacts)) {
    const listed = new Set();
    for (const artifact of manifest.artifacts) {
      if (!artifact || typeof artifact.path !== "string") {
        issues.push({ level: "error", message: "manifest artifact without a path" });
        continue;
      }
      listed.add(artifact.path);
      const file = path.join(dir, artifact.path);
      if (!fs.existsSync(file)) {
        issues.push({ level: "error", message: `manifest artifact missing: ${artifact.path}` });
        continue;
      }
      if (artifact.bytes !== undefined && fs.statSync(file).size !== artifact.bytes) {
        issues.push({ level: "error", message: `artifact size mismatch: ${artifact.path}` });
      }
      if (artifact.sha256 && sha256(file) !== artifact.sha256.toLowerCase()) {
        issues.push({ level: "error", message: `artifact hash mismatch: ${artifact.path}` });
      }
    }
    const actual = walk(dir)
      .filter((file) => path.basename(file) !== "manifest.json")
      .map((file) => path.relative(dir, file).split(path.sep).join("/"));
    for (const file of actual) {
      if (!listed.has(file)) issues.push({ level: "error", message: `unlisted evidence file: ${file}` });
    }
  }

  if (Array.isArray(manifest.files)) {
    for (const entry of manifest.files) {
      const file = path.join(dir, entry.file ?? "");
      if (!entry.file || !fs.existsSync(file)) {
        issues.push({ level: "error", message: `manifest file missing: ${entry.file}` });
        continue;
      }
      if (entry.publication_sha256 && sha256(file) !== entry.publication_sha256.toLowerCase()) {
        issues.push({ level: "error", message: `published hash mismatch: ${entry.file}` });
      }
    }
  }

  if (manifest.claims && typeof manifest.claims === "object") {
    for (const [name, target] of Object.entries(manifest.claims)) {
      if (typeof target !== "string") continue;
      const [filePart, testPart] = target.split("::");
      if (!testPart) continue;
      const excerpt = path.join(dir, filePart);
      if (!fs.existsSync(excerpt)) {
        issues.push({
          level: "info",
          message: `claim "${name}" points outside the public excerpts: ${filePart}`,
        });
        continue;
      }
      const text = fs.readFileSync(excerpt, "utf8");
      if (!new RegExp(`(?:async\\s+)?def\\s+${testPart}\\s*\\(`).test(text)) {
        issues.push({ level: "error", message: `claim "${name}" test not found in ${filePart}: ${testPart}` });
      }
    }
  }

  if (manifest.result && (manifest.result.failed > 0 || manifest.result.errors > 0)) {
    issues.push({
      level: "warn",
      message: `manifest reports failed=${manifest.result.failed} errors=${manifest.result.errors}`,
    });
  }
  return issues;
}

async function renderChecks(results) {
  if (!fs.existsSync(DIST_DIR)) {
    for (const result of results) {
      result.issues.push({ level: "error", message: "render: dist/ not found; run npm run build" });
    }
    return;
  }
  const { chromium } = await import("playwright");
  const { createServer } = await import("node:http");
  const distRoot = path.resolve(DIST_DIR);
  const types = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".json": "application/json",
    ".zip": "application/zip",
    ".txt": "text/plain; charset=utf-8",
    ".xml": "application/xml",
    ".woff2": "font/woff2",
  };
  const server = createServer((req, res) => {
    let pathname;
    try {
      pathname = decodeURIComponent(req.url.split("?")[0]);
    } catch {
      res.writeHead(400).end();
      return;
    }
    let file = path.resolve(distRoot, "." + pathname);
    if (!file.startsWith(distRoot)) {
      res.writeHead(403).end();
      return;
    }
    if (pathname.endsWith("/")) file = path.join(file, "index.html");
    if (!fs.existsSync(file) && fs.existsSync(`${file}.html`)) file = `${file}.html`;
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
      res.writeHead(404).end();
      return;
    }
    res.setHeader("Content-Type", types[path.extname(file).toLowerCase()] ?? "application/octet-stream");
    res.end(fs.readFileSync(file));
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();
  try {
    for (const result of results) {
      const { post } = result;
      if (!post.id || post.data?.draft) continue;
      const file = path.join(distRoot, "posts", ...post.id.split("/"), "index.html");
      if (!fs.existsSync(file)) {
        result.issues.push({ level: "warn", message: "render: no built page; build with draft: false first" });
        continue;
      }
      const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
      const failed = [];
      page.on("response", (response) => {
        if (response.status() >= 400) failed.push(`${response.status()} ${response.url()}`);
      });
      await page.goto(`${base}/posts/${post.id}/`, { waitUntil: "networkidle" });
      const rendered = await page.evaluate(() => ({
        brokenAnchors: [...document.querySelectorAll('a[href^="#"]')]
          .filter((anchor) => {
            const id = decodeURIComponent(anchor.hash.slice(1));
            return id && !document.getElementById(id);
          })
          .map((anchor) => anchor.hash),
        brokenImages: [...document.images]
          .filter((image) => image.complete && image.naturalWidth === 0)
          .map((image) => image.getAttribute("src")),
        overflow: document.documentElement.scrollWidth > window.innerWidth + 1,
      }));
      for (const anchor of rendered.brokenAnchors) {
        result.issues.push({ level: "error", message: `render: broken anchor ${anchor}` });
      }
      for (const image of rendered.brokenImages) {
        result.issues.push({ level: "error", message: `render: broken image ${image}` });
      }
      for (const response of failed) {
        result.issues.push({ level: "error", message: `render: ${response}` });
      }
      if (rendered.overflow) {
        result.issues.push({ level: "error", message: "render: horizontal overflow at 1440px" });
      }
      const reviewDir = path.join(ROOT, "docs", post.slug, "review");
      fs.mkdirSync(reviewDir, { recursive: true });
      await page.screenshot({ path: path.join(reviewDir, `${post.slug}-desktop.png`), fullPage: true });
      await page.setViewportSize({ width: 390, height: 844 });
      const mobile = await page.evaluate(() => ({
        overflow: document.documentElement.scrollWidth > window.innerWidth + 1,
      }));
      if (mobile.overflow) {
        result.issues.push({ level: "error", message: "render: horizontal overflow at 390px" });
      }
      await page.screenshot({ path: path.join(reviewDir, `${post.slug}-mobile.png`), fullPage: true });
      await page.close();
    }
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
}

async function main() {
  const allFiles = walk(POSTS_DIR).filter((file) => /\.(md|mdx)$/i.test(file));
  const posts = allFiles.map(parsePost);
  const valid = posts.filter((post) => !post.error);
  const routeMap = new Map(valid.map((post) => [`/posts/${post.id}/`, post]));
  const categoryRoutes = new Set(valid.map((post) => `/categories/${post.data.category}/`));
  const cloudRoutes = new Set(valid.map((post) => `/clouds/${post.data.cloud ?? "gcp"}/`));
  const tagRoutes = new Set(valid.flatMap((post) => (post.data.tags ?? []).map((tag) => `/tags/${tag}/`)));
  const staticRoutes = new Set([
    "/",
    "/about/",
    "/categories/",
    "/clouds/",
    "/tags/",
    "/404.html",
    "/rss.xml",
    "/sitemap-index.xml",
    "/sitemap-0.xml",
  ]);
  const manifestCache = new Map();

  const selected = valid.filter((post) => {
    if (!opts.slug) return true;
    const needle = opts.slug.toLowerCase();
    return post.id.toLowerCase().includes(needle) || post.slug.toLowerCase().includes(needle);
  });

  if (selected.length === 0) {
    console.error(`No posts matched "${opts.slug}"`);
    process.exit(2);
  }

  const results = [];
  for (const post of posts) {
    if (post.error) {
      results.push({ post, issues: [{ level: "error", message: post.error }] });
      continue;
    }
    if (!selected.includes(post)) continue;
    const issues = checkFrontmatter(post);
    const evidence = new Set();

    for (const link of post.links) {
      if (!link || link.startsWith("#") || /^(?:https?:|mailto:|tel:|data:|javascript:)/i.test(link)) continue;
      const [rawPath, rawHash] = link.split("#");
      const clean = decodeURIComponent(rawPath.split("?")[0]);
      const hash = rawHash ? decodeURIComponent(rawHash) : "";

      if (clean.startsWith("/evidence/") || clean.startsWith("/images/") || clean.startsWith("/og/") || clean.startsWith("/favicon")) {
        const asset = checkAsset(clean);
        if (asset.error) issues.push({ level: "error", message: asset.error });
        if (asset.warn) issues.push({ level: "warn", message: asset.warn });
        const manifest = /^\/evidence\/([^/]+)\/manifest\.json$/.exec(clean);
        if (manifest) evidence.add(manifest[1]);
      } else if (clean.startsWith("/posts/")) {
        const route = clean.endsWith("/") ? clean : `${clean}/`;
        const target = routeMap.get(route);
        if (!target) {
          issues.push({ level: "error", message: `internal post link does not exist: ${link}` });
        } else if (hash && !target.headings.includes(hash)) {
          issues.push({ level: "error", message: `anchor #${hash} not found in ${target.id}` });
        }
      } else if (clean.startsWith("/")) {
        const route = clean === "/" ? "/" : clean.endsWith("/") ? clean : `${clean}/`;
        if (
          staticRoutes.has(route) ||
          categoryRoutes.has(route) ||
          cloudRoutes.has(route) ||
          tagRoutes.has(route)
        ) {
          // Known generated route.
        } else if (route === "/tracks/") {
          // Generated by the site.
        } else {
          issues.push({ level: "warn", message: `unrecognised internal route: ${link}` });
        }
      } else if (
        clean.startsWith("./") ||
        clean.startsWith("../") ||
        /\.(?:png|jpe?g|gif|webp|svg|zip|json|txt|pdf|csv)$/i.test(clean)
      ) {
        const candidates = [
          path.resolve(path.dirname(post.file), clean),
          path.resolve(ROOT, clean),
        ];
        if (!candidates.some((candidate) => fs.existsSync(candidate))) {
          issues.push({ level: "error", message: `relative asset not found: ${link}` });
        }
      }

      if (hash && (!clean || clean === post.rel || clean === `/posts/${post.id}/`)) {
        if (!post.headings.includes(hash)) {
          issues.push({ level: "error", message: `same-page anchor #${hash} not found` });
        }
      }
    }

    for (const evidenceSlug of evidence) {
      if (!manifestCache.has(evidenceSlug)) {
        manifestCache.set(evidenceSlug, checkEvidenceManifest(evidenceSlug));
      }
      for (const issue of manifestCache.get(evidenceSlug)) {
        issues.push({ ...issue, message: `[${evidenceSlug}] ${issue.message}` });
      }
    }

    results.push({ post, issues });
  }

  if (opts.render) await renderChecks(results);

  const errors = results.flatMap((result) => result.issues.filter((issue) => issue.level === "error"));
  const warnings = results.flatMap((result) => result.issues.filter((issue) => issue.level === "warn"));

  if (opts.json) {
    console.log(JSON.stringify({ results, summary: { posts: results.length, errors: errors.length, warnings: warnings.length } }, null, 2));
  } else {
    for (const { post, issues } of results) {
      const state = post.data?.draft ? "draft" : "live";
      console.log(`\n${post.id ?? rel(post.file)} [${state}]`);
      const counts = [
        `${post.links?.length ?? 0} links`,
        `${post.headings?.length ?? 0} anchors`,
      ].join(" · ");
      console.log(`  ${counts}`);
      for (const issue of issues) {
        const mark = issue.level === "error" ? "ERROR" : issue.level === "warn" ? "WARN " : "INFO ";
        console.log(`  ${mark} ${issue.message}`);
      }
      if (issues.length === 0) console.log("  OK");
    }
    console.log(`\nChecked ${results.length} post(s): ${errors.length} error(s), ${warnings.length} warning(s).`);
  }

  if (errors.length > 0 || (opts.strict && warnings.length > 0)) process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
