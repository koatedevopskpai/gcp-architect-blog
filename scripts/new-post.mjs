#!/usr/bin/env node
// Scaffold a new post.
// Usage: npm run new:post -- <category> <id> "<title>"
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const CATEGORIES = [
  "platform-engineering-idp",
  "sre-reliability",
  "security-iam",
  "data-mlops",
  "multicloud-enterprise",
  "finops",
  "architecture-leadership",
];

const CLOUDS = ["aws", "gcp", "azure", "multi"];

const [category, id, ...rest] = process.argv.slice(2);
const cloud = rest.includes("--cloud") ? rest[rest.indexOf("--cloud") + 1] : "gcp";
const title = rest.filter((part, i) => part !== "--cloud" && rest[i - 1] !== "--cloud").join(" ");

if (!category || !id || !title) {
  console.error('Usage: npm run new:post -- <category> <id> "<title>" [--cloud aws|gcp|azure|multi]');
  console.error(`Categories: ${CATEGORIES.join(", ")}`);
  process.exit(1);
}

if (!CATEGORIES.includes(category)) {
  console.error(`Unknown category "${category}".`);
  console.error(`Categories: ${CATEGORIES.join(", ")}`);
  process.exit(1);
}

if (!CLOUDS.includes(cloud)) {
  console.error(`Unknown cloud "${cloud}".`);
  console.error(`Clouds: ${CLOUDS.join(", ")}`);
  process.exit(1);
}

const slug = title
  .toLowerCase()
  .replace(/[^a-z0-9\s-]/g, "")
  .trim()
  .replace(/\s+/g, "-");

const dir = join("src", "content", "posts", category);
mkdirSync(dir, { recursive: true });

const file = join(dir, `${id}-${slug}.mdx`);
const today = new Date().toISOString().slice(0, 10);

const template = `---
title: "${title}"
description: "TODO: 80-200 char description."
category: "${category}"
cloud: "${cloud}"
tags: []
publishDate: ${today}
draft: true
impact: 5
demand: 5
confidence: 5
effort: 3
proofTier: 3
requiresOrg: false
---

## Overview

TODO

## Architecture

\`\`\`mermaid
flowchart TD
  A[Client] --> B[Service]
\`\`\`

## Prerequisites

TODO

## Steps

### 1. TODO

TODO

## Extras

TODO

## SLO / Security / FinOps notes

TODO

## Reproduce

TODO

## Links

- [Official docs](https://cloud.google.com)
`;

writeFileSync(file, template);
console.log(`Created ${file}`);
