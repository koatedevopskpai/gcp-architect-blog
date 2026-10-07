import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";
import { CATEGORY_KEYS } from "./data/categories";

// One `posts` collection. Files may be nested by category on disk
// (src/content/posts/<category>/NNN-slug.mdx) but the `category` field is
// the source of truth for routing, tags, and the derived A-G letter.
const posts = defineCollection({
  loader: glob({ pattern: "**/*.{md,mdx}", base: "./src/content/posts" }),
  schema: z.object({
    title: z.string().max(120),
    description: z.string().min(80).max(200),
    category: z.enum(CATEGORY_KEYS),
    tags: z.array(z.string()).default([]),
    publishDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    draft: z.boolean().default(false),
    featured: z.boolean().default(false),

    // Series
    series: z.string().optional(),
    seriesOrder: z.number().optional(),

    // Priority scoring: Priority = (Impact x Demand x Confidence) / Effort
    impact: z.number().min(1).max(5),
    demand: z.number().min(1).max(5),
    confidence: z.number().min(1).max(5),
    effort: z.number().min(1).max(5),

    // Proof tier: 1 = live run, 2 = code proof, 3 = reference
    proofTier: z.union([z.literal(1), z.literal(2), z.literal(3)]).default(3),
    requiresOrg: z.boolean().default(false),

    // Assets / links
    codeRepo: z.string().url().optional(),
    demoUrl: z.string().url().optional(),
    canonical: z.string().url().optional(),
    ogImage: z.string().optional(),
  }),
});

export const collections = { posts };
