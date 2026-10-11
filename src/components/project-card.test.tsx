import { afterEach, describe, expect, it, vi } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { ProjectCard } from "./project-card";

// Media paths come from DATA as root-relative strings; the card must prefix
// them with Astro's base so PR previews (served under /pr-<n>/) load them.
describe("ProjectCard media paths", () => {
  afterEach(() => vi.unstubAllEnvs());

  it("prefixes the image path with the base", () => {
    vi.stubEnv("BASE_URL", "/pr-9");
    const html = renderToStaticMarkup(
      <ProjectCard title="T" description="d" dates="2026" tags={[]} image="/img.png" />,
    );
    expect(html).toContain('src="/pr-9/img.png"');
  });

  it("prefixes the video path with the base", () => {
    vi.stubEnv("BASE_URL", "/pr-9");
    const html = renderToStaticMarkup(
      <ProjectCard title="T" description="d" dates="2026" tags={[]} video="/clip.mp4" />,
    );
    expect(html).toContain('src="/pr-9/clip.mp4"');
  });

  it("leaves an absolute image URL alone", () => {
    vi.stubEnv("BASE_URL", "/pr-9");
    const html = renderToStaticMarkup(
      <ProjectCard title="T" description="d" dates="2026" tags={[]} image="https://x/y.png" />,
    );
    expect(html).toContain('src="https://x/y.png"');
  });
});
