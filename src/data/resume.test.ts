import { describe, expect, it } from "vitest";
import { DATA, PROJECT_DESCRIPTION_MAX_CHARS } from "./resume";

// Project cards sit side by side, so one long description stretches the whole
// row and pushes the rest of the page down. Keep every description short
// enough to read as a pitch, not a README.
describe("project descriptions", () => {
  it.each(DATA.projects.map((p) => [p.title, p.description] as const))(
    "%s stays within the character limit",
    (_title, description) => {
      expect(description.length).toBeLessThanOrEqual(PROJECT_DESCRIPTION_MAX_CHARS);
    },
  );
});

// progstrength.fitness was retired and will not be renewed, so anyone could
// register it. Nothing on this site may send visitors there.
describe("retired domains", () => {
  it("nothing links to progstrength.fitness", () => {
    const hrefs = DATA.projects.flatMap((p) => [p.href, ...p.links.map((l) => l.href)]);
    for (const text of [...hrefs, DATA.summary, DATA.description]) {
      expect(text).not.toContain("progstrength.fitness");
    }
  });
});
