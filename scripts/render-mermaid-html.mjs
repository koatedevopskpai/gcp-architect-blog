// Post-build step: render ```mermaid fenced blocks to inline SVG.
// Runs after `astro build` so diagrams are part of the static HTML (no client JS).
import { readFileSync, readdirSync, writeFileSync } from "fs";
import { join } from "path";
import { JSDOM } from "jsdom";

const DIST = "dist";

// --- jsdom plumbing (mermaid needs a DOM to render SVG) ---
const dom = new JSDOM("<!DOCTYPE html><html><body></body></html>", { pretendToBeVisual: true });
const setGlobal = (name, value) => {
  try {
    globalThis[name] = value;
  } catch {
    Object.defineProperty(globalThis, name, { value, configurable: true, writable: true });
  }
};
setGlobal("window", dom.window);
setGlobal("document", dom.window.document);
if (!("navigator" in globalThis)) {
  Object.defineProperty(globalThis, "navigator", { value: dom.window.navigator, configurable: true });
}
setGlobal("SVGElement", dom.window.SVGElement);
setGlobal("Element", dom.window.Element);
setGlobal("HTMLElement", dom.window.HTMLElement);
setGlobal("DOMParser", dom.window.DOMParser);
setGlobal("getComputedStyle", dom.window.getComputedStyle.bind(dom.window));
setGlobal("CSSStyleSheet", dom.window.CSSStyleSheet);

const geom = () => ({ x: 0, y: 0, width: 0, height: 0, left: 0, top: 0, right: 0, bottom: 0 });
for (const m of [
  "getBBox", "getScreenCTM", "createSVGPoint", "getComputedTextLength", "getTotalLength", "getPointAtLength",
]) {
  if (dom.window.SVGElement && typeof dom.window.SVGElement.prototype[m] !== "function") {
    Object.defineProperty(dom.window.SVGElement.prototype, m, { value: geom, configurable: true });
  }
}

const mermaid = (await import("mermaid")).default;
await mermaid.initialize({ startOnLoad: false, theme: "neutral" });

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

for (const file of htmlFiles) {
  let html = readFileSync(file, "utf8");
  const blocks = html.match(PRE_RE);
  if (!blocks) continue;

  let index = 0;
  for (const block of blocks) {
    const code = new JSDOM(block).window.document.querySelector("code")?.textContent ?? "";
    const id = `mm-${index++}`;
    try {
      const { svg } = await mermaid.render(id, code);
      html = html.replace(block, `<div class="mermaid">${svg}</div>`);
      rendered++;
    } catch (err) {
      // Some diagrams (e.g. sequence) need real text metrics jsdom can't provide.
      // Leave the block as highlighted source so the page still renders.
      failed++;
      console.warn(`  skip mermaid in ${file.split(/[\\/]/).slice(1).join("/")}: ${String(err.message).split("\n")[0]}`);
    }
  }
  writeFileSync(file, html, "utf8");
}

console.log(`Rendered ${rendered} mermaid diagram(s) to inline SVG (${failed} skipped).`);