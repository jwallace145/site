// @ts-check
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import react from "@astrojs/react";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import remarkGfm from "remark-gfm";
import rehypePrettyCode from "rehype-pretty-code";
import { loadEnv } from "vite";
import { remarkCodeMeta } from "./src/lib/remark-code-meta.ts";
import { CONFIG } from "./src/data/config.ts";

// SITE_URL and BASE_PATH come from the environment (CI sets SITE_URL per
// workflow). SITE_URL falls back to the placeholder in src/data/config.ts;
// BASE_PATH defaults to "/" (previews get their own hostname, so CI no longer
// sets it).
const { SITE_URL, BASE_PATH } = loadEnv(process.env.NODE_ENV ?? "production", process.cwd(), "");

/** @type {import('rehype-pretty-code').Options} */
const prettyCodeOptions = {
  theme: {
    light: "github-light",
    dark: "github-dark",
  },
  keepBackground: false,
};

// https://astro.build/config
export default defineConfig({
  site: SITE_URL || CONFIG.site.url,
  base: BASE_PATH || "/",

  // Pure static output: every route becomes a self-contained HTML file in dist/.
  output: "static",
  build: {
    // `/about` -> `dist/about/index.html`
    format: "directory",
  },
  trailingSlash: "ignore",

  vite: {
    plugins: [tailwindcss()],
  },

  integrations: [
    react(),
    mdx({
      remarkPlugins: [remarkGfm, remarkCodeMeta],
      rehypePlugins: [[rehypePrettyCode, prettyCodeOptions]],
      syntaxHighlight: false,
    }),
    sitemap(),
  ],

  markdown: {
    syntaxHighlight: false,
    remarkPlugins: [remarkGfm, remarkCodeMeta],
    rehypePlugins: [[rehypePrettyCode, prettyCodeOptions]],
  },
});
