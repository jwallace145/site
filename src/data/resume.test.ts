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
