// Post-build step: render ```mermaid fenced blocks to inline SVG using a real
// headless browser (Playwright + Chromium) so text metrics are accurate and the
// diagrams are actually visible. Runs after `astro build`.
import { readdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { chromium } from "playwright";
import { JSDOM } from "jsdom";

const DIST = "dist";
const MERMAID_UMD = "node_modules/mermaid/dist/mermaid.min.js";

const browser = await chromium.launch();
const page = await browser.newPage();
await page.setContent("<!DOCTYPE html><html><body></body></html>");
await page.addScriptTag({ path: MERMAID_UMD });
await page.evaluate(() => {
  window.mermaid.initialize({
    startOnLoad: false,
    theme: "base",
    themeVariables: {
      primaryColor: "#1e293b",
      primaryTextColor: "#ffffff",
      primaryBorderColor: "#0f172a",
      secondaryColor: "#334155",
      tertiaryColor: "#f1f5f9",
      lineColor: "#475569",
      textColor: "#0f172a",
      mainBkg: "#1e293b",
      nodeBorder: "#0f172a",
      edgeLabelBackground: "#ffffff",
      clusterBkg: "#f1f5f9",
      clusterBorder: "#cbd5e1",
      fontFamily: "Segoe UI, UI Sans-Serif, sans-serif",
    },
  });
});

const htmlFiles = [];
(function walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith(".html")) htmlFiles.push(full);
  }
})(DIST);

const PRE_RE = /<pre[^>]*data-language="mermaid"[^>]*>[\s\S]*?<\/pre>/g;
let rendered = 0;
let failed = 0;
let idCounter = 0;

for (const file of htmlFiles) {
  let html = readFileSync(file, "utf8");
  const blocks = html.match(PRE_RE);
  if (!blocks) continue;

  for (const block of blocks) {
    const code = new JSDOM(block).window.document.querySelector("code")?.textContent ?? "";
    try {
      const svg = await page.evaluate(
        async ({ src, id }) => {
          const { svg } = await window.mermaid.render(id, src);
          return svg;
        },
        { src: code, id: `mm-${idCounter++}` },
      );
      html = html.replace(block, `<div class="mermaid">${svg}</div>`);
      rendered++;
    } catch (err) {
      failed++;
      console.warn(`  skip mermaid in ${file.split(/[\\/]/).slice(1).join("/")}: ${String(err.message).split("\n")[0]}`);
    }
  }
  writeFileSync(file, html, "utf8");
}

await browser.close();
console.log(`Rendered ${rendered} mermaid diagram(s) to inline SVG (${failed} skipped).`);