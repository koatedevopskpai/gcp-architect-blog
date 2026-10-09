// Cloud / track dimension so one posts collection can serve AWS, GCP, Azure, and bridges.
// Optional on posts; a missing `cloud` is treated as "gcp" (backwards compatible).
export const CLOUD_KEYS = ["aws", "gcp", "azure", "multi"] as const;

export type CloudKey = (typeof CLOUD_KEYS)[number];

export interface CloudMeta {
  label: string;
  tagline: string;
  description: string;
}

export const clouds: Record<CloudKey, CloudMeta> = {
  aws: {
    label: "AWS",
    tagline: "Amazon Web Services",
    description:
      "EC2, Fargate, EKS/Karpenter, S3, networking, IAM, observability, FinOps, and Bedrock patterns on AWS.",
  },
  gcp: {
    label: "GCP",
    tagline: "Google Cloud",
    description:
      "Terraform, Cloud Run, GKE, SRE, IAM, data, MLOps, and FinOps patterns on Google Cloud.",
  },
  azure: {
    label: "Azure",
    tagline: "Microsoft Azure",
    description:
      "Microsoft Foundry, Azure OpenAI, Azure AI Search, agents, evaluation, observability, and Bicep/azd.",
  },
  multi: {
    label: "Multi-Cloud",
    tagline: "Cross-cloud bridge",
    description:
      "One technique mapped across AWS, GCP, and Azure — the bridge series.",
  },
};

export function cloudOf(key: CloudKey | undefined): CloudKey {
  return key ?? "gcp";
}