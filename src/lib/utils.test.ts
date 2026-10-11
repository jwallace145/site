import { describe, expect, it } from "vitest";
import { withBase } from "./utils";

describe("withBase", () => {
  it("returns root-relative paths unchanged when base is /", () => {
    expect(withBase("/", "/")).toBe("/");
    expect(withBase("/blog", "/")).toBe("/blog");
    expect(withBase("/#work", "/")).toBe("/#work");
  });

  it("prefixes root-relative paths with the base", () => {
    expect(withBase("/", "/pr-9")).toBe("/pr-9/");
    expect(withBase("/blog", "/pr-9")).toBe("/pr-9/blog");
    expect(withBase("/#work", "/pr-9")).toBe("/pr-9/#work");
    expect(withBase("/picofme.png", "/pr-9")).toBe("/pr-9/picofme.png");
  });

  it("tolerates a trailing slash on the base", () => {
    expect(withBase("/blog", "/pr-9/")).toBe("/pr-9/blog");
    expect(withBase("/", "/pr-9/")).toBe("/pr-9/");
  });

  it("leaves absolute URLs, mailto links and fragments alone", () => {
    expect(withBase("https://github.com/jwallace145", "/pr-9")).toBe(
      "https://github.com/jwallace145",
    );
    expect(withBase("mailto:a@b.c", "/pr-9")).toBe("mailto:a@b.c");
    expect(withBase("#work", "/pr-9")).toBe("#work");
  });

  it("treats a relative path as root-relative", () => {
    expect(withBase("blog", "/pr-9")).toBe("/pr-9/blog");
  });
});

describe("withBase edge cases", () => {
  it("returns an empty path unchanged so optional media stays empty", () => {
    expect(withBase("", "/pr-9")).toBe("");
  });

  it("leaves protocol-relative URLs alone", () => {
    expect(withBase("//cdn.example.com/a.png", "/pr-9")).toBe("//cdn.example.com/a.png");
  });
});
