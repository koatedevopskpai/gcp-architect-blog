// Single source of truth for the 7 architecture pillars.
// The A-G letter is derived (never stored in post frontmatter) so it can't drift.
export const CATEGORY_KEYS = [
  "platform-engineering-idp",
  "sre-reliability",
  "security-iam",
  "data-mlops",
  "multicloud-enterprise",
  "finops",
  "architecture-leadership",
] as const;

export type CategoryKey = (typeof CATEGORY_KEYS)[number];

export interface CategoryMeta {
  letter: string;
  label: string;
  description: string;
  requiresOrg: boolean;
}

export const categories: Record<CategoryKey, CategoryMeta> = {
  "platform-engineering-idp": {
    letter: "A",
    label: "Platform Engineering / IDP",
    description:
      "Golden paths, self-service infrastructure, Backstage, and paved roads for multi-team GCP platforms.",
    requiresOrg: false,
  },
  "sre-reliability": {
    letter: "B",
    label: "SRE / Reliability",
    description:
      "SLOs, error budgets, multi-window burn-rate alerting, and resilient GCP architectures.",
    requiresOrg: false,
  },
  "security-iam": {
    letter: "C",
    label: "Security & IAM",
    description:
      "Zero trust, Workload Identity Federation, VPC Service Controls, KMS, and enterprise IAM governance.",
    requiresOrg: false,
  },
  "data-mlops": {
    letter: "D",
    label: "Data & MLOps",
    description:
      "BigQuery, Dataflow, Vertex AI, feature stores, RAG, and end-to-end ML platforms on GCP.",
    requiresOrg: false,
  },
  "multicloud-enterprise": {
    letter: "E",
    label: "Multi-Cloud / Enterprise",
    description:
      "Anthos, hybrid networking, Crossplane, data portability, and enterprise-scale architecture.",
    requiresOrg: false,
  },
  finops: {
    letter: "F",
    label: "FinOps / Cost Engineering",
    description:
      "Budgets, labels, rightsizing, anomaly detection, and egress optimisation on GCP.",
    requiresOrg: false,
  },
  "architecture-leadership": {
    letter: "G",
    label: "Architecture Leadership & Strategy",
    description:
      "Org-level design, governance, migration strategy, reference architectures, and operating models.",
    requiresOrg: true,
  },
};

export function categoryOf(key: CategoryKey): CategoryMeta {
  return categories[key];
}
