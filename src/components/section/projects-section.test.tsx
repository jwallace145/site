import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { DATA } from "@/data/resume";
import ProjectsSection from "./projects-section";

const active = DATA.projects.filter((p) => p.active !== false);
const archived = DATA.projects.filter((p) => p.active === false);

// Titles appear in the markup HTML-escaped ("&" becomes "&amp;").
const asHeading = (title: string) => `>${title.replaceAll("&", "&amp;")}<`;

// Archived projects stay in the portfolio but start collapsed behind a toggle,
// so current work is what visitors see first.
describe("ProjectsSection archived toggle", () => {
  const html = renderToStaticMarkup(<ProjectsSection />);

  it.each(active.map((p) => p.title))("shows active project %s", (title) => {
    expect(html).toContain(asHeading(title));
  });

  it.each(archived.map((p) => p.title))("hides archived project %s by default", (title) => {
    expect(html).not.toContain(asHeading(title));
  });

  it("renders a collapsed toggle with the archived count", () => {
    expect(archived.length).toBeGreaterThan(0);
    expect(html).toContain('aria-expanded="false"');
    expect(html).toContain(`Show archived projects (${archived.length})`);
  });
});
