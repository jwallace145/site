import { describe, expect, it } from "vitest";
import lint from "@commitlint/lint";
import load from "@commitlint/load";
import bodyTrailersOnly from "./body-trailers-only.mjs";

// Unit tests call the rule directly; integration tests run the real
// commitlint config so the type list and header length are covered too.

describe("body-trailers-only (rule)", () => {
  it("passes a subject-only message", () => {
    const [valid] = bodyTrailersOnly({ raw: "feat: add thing" });
    expect(valid).toBe(true);
  });

  it("passes a subject followed by a Co-authored-by trailer", () => {
    const [valid] = bodyTrailersOnly({
      raw: "feat: add thing\n\nCo-authored-by: Someone <someone@example.com>",
    });
    expect(valid).toBe(true);
  });

  it("passes multiple trailers", () => {
    const [valid] = bodyTrailersOnly({
      raw: "fix: x\n\nCo-authored-by: A <a@example.com>\nSigned-off-by: B <b@example.com>",
    });
    expect(valid).toBe(true);
  });

  it("ignores blank and comment lines", () => {
    const [valid] = bodyTrailersOnly({
      raw: "fix: x\n\n# Please enter the commit message\n#\n\nCo-authored-by: A <a@example.com>\n",
    });
    expect(valid).toBe(true);
  });

  it("fails a subject followed by a prose body", () => {
    const [valid, message] = bodyTrailersOnly({
      raw: "feat: add thing\n\nThis explains why the thing was added.",
    });
    expect(valid).toBe(false);
    expect(message).toContain("single line");
    expect(message).toContain("This explains why the thing was added.");
  });

  it("fails when prose is mixed with trailers", () => {
    const [valid] = bodyTrailersOnly({
      raw: "feat: add thing\n\nSome prose.\n\nCo-authored-by: A <a@example.com>",
    });
    expect(valid).toBe(false);
  });

  it("supports the never condition", () => {
    const [valid] = bodyTrailersOnly({ raw: "feat: add thing" }, "never");
    expect(valid).toBe(false);
  });
});

describe("commitlint config", async () => {
  const config = await load({}, { cwd: new URL("../../", import.meta.url).pathname });
  const run = (message) =>
    lint(message, config.rules, {
      plugins: config.plugins,
      parserOpts: config.parserPreset?.parserOpts,
    });

  it("accepts a one-line conventional commit", async () => {
    const result = await run("chore: scaffold site from starfolio template");
    expect(result.valid).toBe(true);
  });

  it("accepts a scoped commit with a trailer", async () => {
    const result = await run(
      "feat(infra): add s3 cloudfront and oidc terraform\n\nCo-authored-by: Someone <someone@example.com>",
    );
    expect(result.valid).toBe(true);
  });

  it("accepts a breaking change marker", async () => {
    const result = await run("feat!: drop node 22 support");
    expect(result.valid).toBe(true);
  });

  it("rejects a prose body", async () => {
    const result = await run("fix: thing\n\nLong explanation of the fix.");
    expect(result.valid).toBe(false);
    expect(result.errors.map((e) => e.name)).toContain("body-trailers-only");
  });

  it("rejects an unknown type", async () => {
    const result = await run("update: thing");
    expect(result.valid).toBe(false);
    expect(result.errors.map((e) => e.name)).toContain("type-enum");
  });

  it("rejects a header over 100 characters", async () => {
    const result = await run(`feat: ${"x".repeat(100)}`);
    expect(result.valid).toBe(false);
    expect(result.errors.map((e) => e.name)).toContain("header-max-length");
  });
});
