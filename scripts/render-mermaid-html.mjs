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

// xychart-beta emits washed-out pastel bar fills and white SVG text by default.
// Remap them to a high-contrast palette (deterministic, applies to all diagrams).
const PALETTE = {
  "#FFF4DD": "#2563EB", // blue
  "#FFA07A": "#EF4444", // red
  "#FFD8B1": "#F59E0B", // amber
  "#ECEFF1": "#10B981", // emerald
  "#FFD2FF": "#8B5CF6", // violet
  "#A5E6D1": "#0EA5E9", // sky
  "#FF8695": "#EC4899", // pink
  "#55C7F3": "#22C55E", // green
};

function fixContrast(svg) {
  let out = svg;
  for (const [from, to] of Object.entries(PALETTE)) {
    out = out.split(from).join(to);
  }
  out = out.split('fill="#ffffff"').join('fill="#0f172a"');
  out = out.split('stroke="#ffffff"').join('stroke="#94a3b8"');
  return out;
}

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
      const raw = await page.evaluate(
        async ({ src, id }) => {
          const { svg } = await window.mermaid.render(id, src);
          return svg;
        },
        { src: code, id: `mm-${idCounter++}` },
      );
      const svg = fixContrast(raw);
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