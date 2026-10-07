import rss from "@astrojs/rss";
import { getCollection } from "astro:content";
import type { APIContext } from "astro";

export async function GET(context: APIContext) {
  const posts = (
    await getCollection("posts", ({ data }) => !data.draft)
  ).sort((a, b) => b.data.publishDate.getTime() - a.data.publishDate.getTime());

  return rss({
    title: "Koate Kpai — GCP Architecture",
    description:
      "Production-grade GCP architecture and platform engineering patterns, backed by working code.",
    site: context.site ?? "https://gcp-architect-blog.web.app",
    items: posts.map((post) => ({
      title: post.data.title,
      description: post.data.description,
      pubDate: post.data.publishDate,
      link: `/posts/${post.id}/`,
      categories: [post.data.category, ...post.data.tags],
    })),
  });
}
