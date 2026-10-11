import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

// Render the Terraform template the way templatefile() would, then load the
// CloudFront Function's `handler` into this process.
function loadHandler({ primaryHost, redirectHosts }) {
  const dir = dirname(fileURLToPath(import.meta.url));
  const source = readFileSync(join(dir, "rewrite-index.js.tftpl"), "utf8")
    .replace("${primary_host}", primaryHost)
    .replace("${redirect_hosts}", JSON.stringify(redirectHosts));
  return new Function(`${source}; return handler;`)();
}

function request(host, uri, querystring = {}) {
  return { request: { uri, querystring, headers: { host: { value: host } } } };
}

describe("rewrite-index CloudFront function", () => {
  const handler = loadHandler({
    primaryHost: "jwall.engineering",
    redirectHosts: ["www.jwall.engineering"],
  });

  it("rewrites a directory path to its index.html", () => {
    expect(handler(request("jwall.engineering", "/blog/")).uri).toBe("/blog/index.html");
  });

  it("rewrites an extensionless path to a directory index", () => {
    expect(handler(request("jwall.engineering", "/blog")).uri).toBe("/blog/index.html");
  });

  it("passes a file path through unchanged", () => {
    expect(handler(request("jwall.engineering", "/favicon.svg")).uri).toBe("/favicon.svg");
  });

  it("redirects a redirect host to the primary host, keeping path and query", () => {
    const res = handler(
      request("www.jwall.engineering", "/blog", { x: { value: "1" }, y: { value: "" } }),
    );
    expect(res.statusCode).toBe(301);
    expect(res.headers.location.value).toBe("https://jwall.engineering/blog?x=1&y");
  });

  it("keeps multi-value query parameters on redirect", () => {
    const res = handler(
      request("www.jwall.engineering", "/", {
        t: { value: "a", multiValue: [{ value: "a" }, { value: "b" }] },
      }),
    );
    expect(res.headers.location.value).toBe("https://jwall.engineering/?t=a&t=b");
  });

  it("never redirects the preview or cloudfront hostnames", () => {
    expect(handler(request("preview.jwall.engineering", "/pr-9/")).uri).toBe("/pr-9/index.html");
    expect(handler(request("d123.cloudfront.net", "/about")).uri).toBe("/about/index.html");
  });

  it("behaves like the plain rewrite when no primary host is configured", () => {
    const plain = loadHandler({ primaryHost: "", redirectHosts: [] });
    expect(plain(request("www.jwall.engineering", "/blog/")).uri).toBe("/blog/index.html");
  });
});
