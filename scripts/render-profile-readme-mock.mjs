import { readFileSync, writeFileSync } from "node:fs";
import { marked } from "marked";

const mdPath = "C:/Users/koate/development/azure-ai-portfolio/blog/profile-readme-draft.md";
const outPath = "C:/Users/koate/development/azure-ai-portfolio/blog/profile-readme-mock.html";

const md = readFileSync(mdPath, "utf8");
const body = marked.parse(md, { gfm: true, breaks: true });

const page = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Koate Kpai — GitHub profile mock</title>
<style>
  :root {
    --bg: #0d1117;
    --card: #ffffff;
    --border: #d0d7de;
    --muted: #57606a;
    --link: #0969da;
    --code-bg: #f6f8fa;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: linear-gradient(180deg, #0d1117 0px, #0d1117 260px, #f6f8fa 260px);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji";
    color: #1f2328;
    font-size: 14px;
    line-height: 1.6;
  }
  .container { max-width: 1024px; margin: 0 auto; padding: 0 16px 48px; }

  /* --- profile header --- */
  .header {
    position: relative;
    padding: 48px 0 24px;
    color: #e6edf3;
    min-height: 240px;
  }
  .avatar-row { display: flex; gap: 24px; align-items: flex-start; }
  .avatar {
    width: 148px; height: 148px; border-radius: 50%;
    background: linear-gradient(135deg, #2da44e, #0969da, #8250df);
    color: #fff; font-size: 56px; font-weight: 700;
    display: flex; align-items: center; justify-content: center;
    border: 3px solid #0d1117;
    flex-shrink: 0;
  }
  .avatar-caption { text-align: center; margin-top: 6px; font-size: 12px; color: #8b949e; }
  .hdr-right { padding-top: 30px; }
  .hdr-name { font-size: 26px; font-weight: 600; margin: 0; color: #fff; }
  .hdr-handle { font-size: 18px; color: #8b949e; font-weight: 300; margin: 2px 0 8px; }
  .hdr-bio { font-size: 16px; color: #e6edf3; font-weight: 400; margin: 4px 0; }
  .hdr-follow { display: inline-flex; gap: 6px; align-items: center; }
  .btn-follow {
    background: #f6f8fa; color: #0d1117; border: 1px solid #d0d7de;
    border-radius: 6px; padding: 5px 16px; font-weight: 600; font-size: 14px; cursor: pointer;
  }
  .btn-outline {
    background: #21262d; color: #f0f6fc; border: 1px solid #3d444d;
    border-radius: 6px; padding: 5px 16px; font-size: 14px; font-weight: 500;
  }
  .stats { margin-top: 14px; display: flex; gap: 22px; font-size: 13px; color: #8b949e; }
  .stats b { color: #f0f6fc; }

  /* --- main grid --- */
  .grid { display: flex; gap: 24px; margin-top: 20px; }
  .sidebar { width: 296px; flex-shrink: 0; }
  .sidebar .card { background: var(--card); border: 1px solid var(--border); border-radius: 6px; padding: 16px; }
  .sidebar h3 { font-size: 14px; margin: 0 0 8px; color: #1f2328; }
  .sidebar .sub-label { color: var(--muted); font-size: 12px; }
  .sidebar ul { margin: 8px 0 0; padding-left: 18px; color: #1f2328; }
  .sidebar ul li { margin: 4px 0; }
  .sidebar .muted { color: var(--muted); font-size: 13px; }
  .sidebar a { color: var(--link); text-decoration: none; }
  .sidebar a:hover { text-decoration: underline; }

  .content { flex: 1; min-width: 0; }
  .tabs { display: flex; gap: 20px; border-bottom: 1px solid var(--border); margin-bottom: 20px; }
  .tabs span { padding: 8px 0; font-size: 14px; color: var(--muted); border-bottom: 2px solid transparent; cursor: default; }
  .tabs span.active { color: #1f2328; border-bottom-color: #fd8c73; font-weight: 600; }
  .repo-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 24px; }
  .repo-card {
    background: var(--card); border: 1px solid var(--border); border-radius: 6px;
    padding: 16px; min-height: 96px;
  }
  .repo-card strong { color: var(--link); font-size: 14px; }
  .repo-card p { color: var(--muted); font-size: 12px; margin: 6px 0 10px; min-height: 30px; }
  .repo-meta { font-size: 12px; color: var(--muted); display: flex; gap: 12px; }
  .repo-meta .dot { color: #0969da; }

  /* --- README card (GitHub-flavored markdown) --- */
  .readme {
    background: var(--card); border: 1px solid var(--border); border-radius: 6px;
    padding: 24px 32px; max-width: inherit;
  }
  .readme h1 {
    font-size: 30px; font-weight: 600; line-height: 1.25; margin: 0 0 16px;
    border-bottom: 1px solid var(--border); padding-bottom: 8px;
  }
  .readme h2 {
    font-size: 22px; font-weight: 600; margin: 24px 0 12px; line-height: 1.25;
    border-bottom: 1px solid var(--border); padding-bottom: 6px;
  }
  .readme h3 { font-size: 17px; font-weight: 600; margin: 20px 0 8px; }
  .readme p { margin: 0 0 12px; }
  .readme blockquote {
    margin: 16px 0; padding: 2px 16px; color: var(--muted);
    border-left: 4px solid #d0d7de;
  }
  .readme blockquote p { margin: 8px 0; }
  .readme code {
    background: var(--code-bg); border-radius: 6px; padding: 2px 6px;
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
    font-size: 85%;
  }
  .readme pre {
    background: var(--code-bg); border-radius: 6px; padding: 16px; overflow: auto; margin: 0 0 12px;
  }
  .readme pre code { background: none; padding: 0; }
  .readme ul, .readme ol { padding-left: 24px; margin: 0 0 12px; }
  .readme li { margin: 4px 0; }
  .readme hr {
    height: 1px; background: var(--border); border: none; margin: 24px 0;
  }
  .readme a { color: var(--link); text-decoration: none; }
  .readme a:hover { text-decoration: underline; }
  .readme strong { font-weight: 600; }
  .readme p:last-child { margin-bottom: 0; }
  footer { margin-top: 28px; text-align: center; color: var(--muted); font-size: 12px; }
</style>
</head>
<body>
  <div class="container">
    <header class="header">
      <div class="avatar-row">
        <div>
          <div class="avatar">KP</div>
          <div class="avatar-caption">@koatedevopskpai</div>
        </div>
        <div class="hdr-right">
          <h1 class="hdr-name">Koate Kpai</h1>
          <div class="hdr-handle">@koatedevopskpai</div>
          <p class="hdr-bio">AI Implementation Engineer &amp; Cloud Platform Builder — Azure AI / GCP / AWS</p>
          <div class="hdr-follow">
            <button class="btn-follow">Follow</button>
            <button class="btn-outline">Website & website</button>
          </div>
          <div class="stats">
            <span><b>22</b> followers</span>
            <span><b>38</b> following</span>
            <span><b>127</b> stars</span>
            <span><b>6</b> pinned</span>
          </div>
        </div>
      </div>
    </header>

    <div class="grid">
      <aside class="sidebar">
        <div class="card">
          <h3>Highlights</h3>
          <p class="sub-label" style="margin-top:2px">Platform &amp; DevOps Engineer (GCP • AWS • Azure) — Terraform, Kubernetes, CI/CD, FinOps — AI/ML platforms</p>
          <ul>
            <li>Azure AI Foundry (AI-103)</li>
            <li>RAG &amp; retrieval evaluation</li>
            <li>kdb+/q &amp; market data</li>
            <li>Terraform • K8s • CI/CD • FinOps</li>
          </ul>
        </div>
        <div class="card" style="margin-top:16px">
          <h3>Organizations</h3>
          <p class="muted">(private)</p>
        </div>
        <div class="card" style="margin-top:16px">
          <h3>Unavailable</h3>
          <p class="muted">Skype status, sound, directions, etc. hidden for the mock</p>
        </div>
        <div class="card" style="margin-top:16px">
          <h3>Connect</h3>
          <p class="muted">LinkedIn · koatekpai@outlook.com · <a href="https://gcp-architect-blog.web.app">gcp-architect-blog.web.app</a></p>
        </div>
      </aside>

      <main class="content">
        <div class="tabs">
          <span class="active">Overview</span>
          <span>Repositories</span>
          <span>Projects</span>
          <span>Packages</span>
          <span>Stars</span>
        </div>

        <div class="repo-grid">
          <div class="repo-card">
            <strong>enterprise-rag-pipeline</strong>
            <p>Hybrid retrieval + reranking evaluation harness for RAG on Azure AI — H@k, MRR, nDCG, latency.</p>
            <div class="repo-meta"><span class="dot">◆</span> Python <span>★ 24</span></div>
          </div>
          <div class="repo-card">
            <strong>azure-ai-rag-pipeline</strong>
            <p>Multi-agent RAG on Azure AI Foundry with structured output and tool-calling.</p>
            <div class="repo-meta"><span class="dot">◆</span> Python <span>★ 8</span></div>
          </div>
          <div class="repo-card">
            <strong>kdb-portfolio</strong>
            <p>Bank-style market-data platform: tickerplant, RDB, partitioned HDB, C++/Java/C# clients.</p>
            <div class="repo-meta"><span class="dot">◆</span> q · C++ · Java · C# <span>★ 15</span></div>
          </div>
          <div class="repo-card">
            <strong>gcp-proof-platform</strong>
            <p>Live GCP platform: GKE, Cloud Run, BigQuery, Cloud Build, FinOps budgets.</p>
            <div class="repo-meta"><span class="dot">◆</span> Terraform <span>★ 11</span></div>
          </div>
        </div>

        <article class="readme">
${body}
        </article>
      </main>
    </div>

    <footer>Mock generated from profile-readme-draft.md — pinned/topics/star counts are illustrative.</footer>
  </div>
</body>
</html>`;

writeFileSync(outPath, page, "utf8");
console.log("wrote " + outPath);