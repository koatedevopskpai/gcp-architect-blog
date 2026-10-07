export function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-");
}

export function formatDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function readingTime(body: string | undefined): number {
  if (!body) return 1;
  const words = body.trim().split(/\s+/).length;
  return Math.max(1, Math.round(words / 200));
}

export const TIER_LABEL: Record<number, { label: string; desc: string }> = {
  1: {
    label: "live run",
    desc: "Tier 1: deployed live with screenshots, metrics, and cost.",
  },
  2: {
    label: "applied",
    desc: "Tier 2: Terraform applied and the workflow authenticated for real.",
  },
  3: {
    label: "reference",
    desc: "Tier 3: reference architecture with code and tradeoffs.",
  },
};

export function priority(score: {
  impact: number;
  demand: number;
  confidence: number;
  effort: number;
}): number {
  return +(
    (score.impact * score.demand * score.confidence) /
    score.effort
  ).toFixed(2);
}
