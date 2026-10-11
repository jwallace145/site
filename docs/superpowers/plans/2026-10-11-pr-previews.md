# PR Preview Deployments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every PR from a branch in this repo gets a live preview at `https://<preview-cdn>/pr-<n>/`, refreshed on push and deleted on close.

**Architecture:** A new `preview-site` Terraform module (one private S3 bucket, one CloudFront distribution, one OIDC role) applied from the existing prod root. A `preview.yml` workflow builds the site with Astro `base=/pr-<n>`, syncs `dist/` to that key prefix, and comments the URL. The app gains a `withBase()` helper so every root-relative link honours the base path.

**Tech Stack:** Terraform 1.14 / AWS provider 6.x, GitHub Actions + OIDC, Astro 6, React 19, Vitest.

**Spec:** `docs/superpowers/specs/2026-10-11-pr-previews-design.md`

## Global Constraints

- Resource names follow `<name_prefix>-preview-<resource>`; every name is defined once in the module's `naming.tf`.
- Every Terraform variable has a `description`, `type`, a default where sensible, and a `validation` block wherever the value has a constrained shape. Every knob is settable from `infra/environments/prod/terraform.tfvars`.
- Commits are one line, conventional, `type(scope): subject`, ≤100 chars, with only trailers after the header. End each with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Lefthook runs Prettier and ESLint on commit; run `pnpm format` before committing anything under `src/`, `docs/`, `.github/`.
- Terraform code must pass `terraform fmt -check -recursive` and `terraform validate`.
- Apply only with `AWS_PROFILE=prog-strength-admin` from `infra/environments/prod/`.
- Fork PRs get no OIDC token; the workflow must skip them with an explicit `if`.
- Preview responses carry `X-Robots-Tag: noindex, nofollow`.

## Review Focus

1. **A path that is already absolute** (`https://…`, `mailto:…`, `#work`) passed to `withBase` must come back untouched, or external links in the navbar and contact section break. Pinned by the `withBase` tests in Task 1.
2. **Base `/` (production)** must produce exactly the links the site has today: `withBase("/blog")` is `/blog`, `withBase("/")` is `/`. Pinned in Task 1.
3. **A hard-coded root link added later** (e.g. `href="/projects"`) must fail CI rather than silently 404 in previews. Pinned by the leak check added to `ci.yml` in Task 2.
4. **PR closed before its first deploy finished** must not fail the cleanup job on an empty prefix: `aws s3 rm --recursive` on a missing prefix exits 0, and the comment patch is guarded. Pinned by the `if` guards in Task 7.
5. **`preview_enabled = false`** must plan cleanly with no preview resources and null outputs, or turning previews off from tfvars breaks the root. Pinned by the validate-with-override step in Task 5.

---

### Task 1: `withBase` helper

**Files:**

- Modify: `src/lib/utils.ts`
- Create: `src/lib/utils.test.ts`

**Interfaces:**

- Produces: `withBase(path: string, base?: string): string` exported from `src/lib/utils.ts`. `base` defaults to `import.meta.env.BASE_URL`. Later tasks call it with one argument.

- [ ] **Step 1: Write the failing tests**

```ts
// src/lib/utils.test.ts
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `pnpm test -- src/lib/utils.test.ts`
Expected: FAIL, `withBase is not a function` (or "has no exported member").

- [ ] **Step 3: Implement `withBase`**

Append to `src/lib/utils.ts`:

```ts
/**
 * Prefix a root-relative path with Astro's `base` so links work when the
 * site is served under a sub-path (PR previews are built with
 * `BASE_PATH=/pr-<n>`). Absolute URLs, `mailto:`/`tel:` links and bare
 * fragments are returned unchanged.
 */
export function withBase(path: string, base: string = import.meta.env.BASE_URL): string {
  if (/^[a-z][a-z0-9+.-]*:/i.test(path) || path.startsWith("#")) {
    return path;
  }
  const trimmedBase = base.replace(/\/+$/, "");
  const trimmedPath = path.replace(/^\/+/, "");
  return `${trimmedBase}/${trimmedPath}`;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `pnpm test -- src/lib/utils.test.ts`
Expected: PASS, 5 tests.

- [ ] **Step 5: Lint, format, commit**

```bash
pnpm format && pnpm lint && pnpm check
git add src/lib/utils.ts src/lib/utils.test.ts
git commit -m "feat(site): add withBase helper for base-path aware links

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Astro `base` and base-aware links

**Files:**

- Modify: `astro.config.mjs`
- Modify: `.env.example`
- Modify: `src/components/navbar.tsx`
- Modify: `src/components/BlogList.tsx`
- Modify: `src/components/HomePage.tsx`
- Modify: `src/layouts/Layout.astro`
- Modify: `src/pages/404.astro`
- Modify: `src/pages/blog/[slug].astro`
- Modify: `.github/workflows/ci.yml` (build job)

**Interfaces:**

- Consumes: `withBase` from Task 1.
- Produces: `BASE_PATH` environment variable honoured by `pnpm build`; Task 7's workflow sets it.

- [ ] **Step 1: Read `BASE_PATH` in `astro.config.mjs`**

Replace the `loadEnv` line and the `site:` entry:

```js
// SITE_URL and BASE_PATH come from the environment (CI sets them from the
// GitHub Environment). SITE_URL falls back to the placeholder in
// src/data/config.ts; BASE_PATH defaults to "/" and is only set for PR
// previews, which are served under /pr-<n>/.
const { SITE_URL, BASE_PATH } = loadEnv(process.env.NODE_ENV ?? "production", process.cwd(), "");
```

and inside `defineConfig`:

```js
  site: SITE_URL || CONFIG.site.url,
  base: BASE_PATH || "/",
```

- [ ] **Step 2: Document `BASE_PATH` in `.env.example`**

Append:

```bash

# Sub-path the site is served from. Leave unset for production ("/"). PR
# previews are built with BASE_PATH=/pr-<number>.
# BASE_PATH=/pr-0
```

- [ ] **Step 3: Apply `withBase` in the navbar**

In `src/components/navbar.tsx`, add `import { withBase } from "@/lib/utils";` and change the nav link:

```tsx
                <a
                  href={isExternal ? item.href : withBase(item.href)}
```

(The social links are all absolute; leave them.)

- [ ] **Step 4: Apply `withBase` in the blog list**

In `src/components/BlogList.tsx`, add `import { withBase } from "@/lib/utils";` and change the post link:

```tsx
                      href={withBase(`/blog/${post.id}`)}
```

`pagination.prevUrl`/`nextUrl` come from Astro's `paginate()` which already includes `base`; leave them.

- [ ] **Step 5: Apply `withBase` to the avatar and about-section links**

In `src/components/HomePage.tsx`:

```tsx
import Markdown, { defaultUrlTransform } from "react-markdown";
import { withBase } from "@/lib/utils";

// Root-relative links in DATA.summary (e.g. /#work) must stay inside the
// current base path on PR previews.
const markdownUrlTransform = (url: string) => withBase(defaultUrlTransform(url));
```

Change the about section's Markdown to `<Markdown urlTransform={markdownUrlTransform}>{DATA.summary}</Markdown>` and the avatar to `<AvatarImage alt={DATA.name} src={withBase(DATA.avatarUrl)} />`.

- [ ] **Step 6: Apply `withBase` in the layout**

In `src/layouts/Layout.astro` frontmatter add `import { withBase } from "@/lib/utils";` and change the OG image fallback:

```ts
const ogImage = image
  ? image.startsWith("http")
    ? image
    : `${siteUrl}${withBase(image)}`
  : `${siteUrl}${withBase(DATA.ogImage)}`;
```

and the favicons:

```astro
<link rel="icon" type="image/svg+xml" href={withBase("/favicon.svg")} />
<link rel="icon" type="image/x-icon" href={withBase("/favicon.ico")} />
```

`canonicalURL` defaults to `Astro.url.href`, which already includes `base`; leave it.

- [ ] **Step 7: Apply `withBase` on the 404 page and blog post page**

`src/pages/404.astro`: add `import { withBase } from "@/lib/utils";` and use `<a href={withBase("/")}>`.

`src/pages/blog/[slug].astro`: add `withBase` to the existing `@/lib/utils` import, change the back link to `href={withBase("/blog")}`, and the two slug URLs:

```ts
const postPath = withBase(`/blog/${slug}`);
// in jsonLd:   url: `${siteUrl}${postPath}`,
// in <Layout>: canonicalURL={`${siteUrl}${postPath}`}
```

- [ ] **Step 8: Verify a prefixed build locally**

Run:

```bash
BASE_PATH=/pr-0 pnpm build
grep -rEoh '(href|src)="/[^"]*' --include='*.html' dist | grep -vE '^(href|src)="/pr-0(/|$)' || echo clean
grep -o 'href="/pr-0/blog"' dist/blog/example-post/index.html | head -1
pnpm build   # restore a normal build
```

Expected: `clean` (no leaked links printed), then `href="/pr-0/blog"`. Portable grep only: macOS has no `grep -P`.

- [ ] **Step 9: Add the leak check to CI**

In `.github/workflows/ci.yml`, after the `Verify static output` step of the `build` job add:

```yaml
- name: Build under a base path (PR previews)
  # Previews are served from /pr-<n>/. Any root-relative link that
  # ignores Astro's `base` would 404 there, so fail fast here.
  run: |
    BASE_PATH=/pr-0 pnpm build
    leaks=$(grep -rEoh '(href|src)="/[^"]*' --include='*.html' dist | grep -vE '^(href|src)="/pr-0(/|$)' || true)
    if [ -n "$leaks" ]; then
      echo "$leaks"
      echo "::error::Root-relative link(s) above ignore BASE_PATH; wrap them with withBase()"
      exit 1
    fi
```

- [ ] **Step 10: Run all checks, commit**

```bash
pnpm format && pnpm lint && pnpm check && pnpm test && pnpm build
git add astro.config.mjs .env.example src .github/workflows/ci.yml
git commit -m "feat(site): honour BASE_PATH so builds work under a sub-path

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Export preview inputs from `static-site`

**Files:**

- Modify: `infra/modules/static-site/outputs.tf`

**Interfaces:**

- Produces outputs `oidc_provider_arn`, `web_rewrite_index_function_arn`, `plan_role_name` consumed by the root in Task 5.

- [ ] **Step 1: Add the outputs**

Append to `infra/modules/static-site/outputs.tf`:

```hcl
output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider the roles trust (created or looked up)."
  value       = local.oidc_provider_arn
}

output "web_rewrite_index_function_arn" {
  description = "ARN of the CloudFront Function that maps directory paths to index.html. Reusable by other distributions."
  value       = aws_cloudfront_function.web_rewrite_index.arn
}

output "plan_role_name" {
  description = "Name of the read-only plan role, for attaching extra read policies. null when plan_role is false."
  value       = var.plan_role ? aws_iam_role.plan[0].name : null
}
```

- [ ] **Step 2: Validate and commit**

```bash
cd infra && terraform fmt -check -recursive && cd environments/prod && terraform init -backend=false -input=false >/dev/null && terraform validate && cd ../../..
git add infra/modules/static-site/outputs.tf
git commit -m "feat(infra): export oidc provider, rewrite function and plan role from static-site

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: `preview-site` module

**Files:**

- Create: `infra/modules/preview-site/versions.tf`
- Create: `infra/modules/preview-site/naming.tf`
- Create: `infra/modules/preview-site/variables.tf`
- Create: `infra/modules/preview-site/main.tf`
- Create: `infra/modules/preview-site/cloudfront.tf`
- Create: `infra/modules/preview-site/iam.tf`
- Create: `infra/modules/preview-site/outputs.tf`
- Create: `infra/modules/preview-site/files/404.html`

**Interfaces:**

- Consumes: nothing from code; inputs are plain variables.
- Produces: outputs `preview_bucket_name`, `preview_distribution_id`, `preview_distribution_domain_name`, `preview_role_arn`, `preview_url`, `resource_names`, `github_environment_variables`.

- [ ] **Step 1: `versions.tf`**

```hcl
terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

- [ ] **Step 2: `naming.tf`**

```hcl
# Naming standard: <name_prefix>-preview-<resource>. Every name this module
# uses is defined here so the convention lives in one place.
locals {
  prefix = var.name_prefix

  names = {
    preview_bucket           = "${local.prefix}-preview-bucket"
    preview_oac              = "${local.prefix}-preview-oac"
    preview_cdn              = "${local.prefix}-preview-cdn"
    preview_security_headers = "${local.prefix}-preview-security-headers"
    preview_github_role      = "${local.prefix}-preview-github-role"
    preview_github_policy    = "${local.prefix}-preview-github-policy"
    preview_plan_policy      = "${local.prefix}-preview-github-plan-policy"
  }
}
```

- [ ] **Step 3: `variables.tf`**

```hcl
# -----------------------------------------------------------------------------
# Identity and naming
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jwallace145-site. Names become <name_prefix>-preview-<resource>."
  type        = string

  validation {
    # Leaves room for "-preview-bucket-" plus the 26-char suffix AWS appends to bucket_prefix (63 max).
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits and hyphens, 2-21 characters."
  }
}

# -----------------------------------------------------------------------------
# Previews
# -----------------------------------------------------------------------------

variable "key_prefix" {
  description = "S3 key prefix previews are written under; the PR number is appended (pr- => pr-9/). Scopes the lifecycle rule and the role's write permission, and is exported to the workflow as PREVIEW_KEY_PREFIX."
  type        = string
  default     = "pr-"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.key_prefix))
    error_message = "key_prefix must be non-empty and contain only letters, digits, '_' and '-' (no slashes)."
  }
}

variable "retention_days" {
  description = "Days after which preview objects expire. A safety net for PRs whose cleanup job never ran."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days == floor(var.retention_days) && var.retention_days >= 1 && var.retention_days <= 365
    error_message = "retention_days must be a whole number between 1 and 365."
  }
}

variable "price_class" {
  description = "CloudFront price class for the preview distribution."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "error_caching_min_ttl" {
  description = "Seconds CloudFront caches the 404 response for missing preview paths."
  type        = number
  default     = 60

  validation {
    condition     = var.error_caching_min_ttl >= 0 && var.error_caching_min_ttl <= 86400
    error_message = "error_caching_min_ttl must be between 0 and 86400 seconds."
  }
}

variable "robots_tag" {
  description = "Value of the X-Robots-Tag header on every preview response, so search engines never index previews."
  type        = string
  default     = "noindex, nofollow"

  validation {
    condition     = length(trimspace(var.robots_tag)) > 0
    error_message = "robots_tag must not be empty."
  }
}

variable "extra_response_headers" {
  description = "Additional response headers (name => value) added to every preview response."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.extra_response_headers) : can(regex("^[A-Za-z0-9-]+$", k))])
    error_message = "extra_response_headers keys must be valid HTTP header names (letters, digits, hyphens)."
  }
}

variable "rewrite_index_function_arn" {
  description = "ARN of the CloudFront Function that maps /path/ to /path/index.html. Shared with the production distribution."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:cloudfront::[0-9]{12}:function/", var.rewrite_index_function_arn))
    error_message = "rewrite_index_function_arn must be a CloudFront Function ARN."
  }
}

# -----------------------------------------------------------------------------
# Deploy identity (GitHub Actions OIDC)
# -----------------------------------------------------------------------------

variable "oidc_provider_arn" {
  description = "ARN of the account's token.actions.githubusercontent.com OIDC provider."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.oidc_provider_arn))
    error_message = "oidc_provider_arn must be the ARN of a token.actions.githubusercontent.com OIDC provider."
  }
}

variable "github_repository" {
  description = "GitHub repository (owner/name) whose preview jobs may assume the preview role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in owner/name form."
  }
}

variable "github_owner_id" {
  description = "Numeric GitHub ID of the repository owner. With github_repository_id, enables GitHub's immutable OIDC subject. null accepts the plain subject only."
  type        = number
  default     = null
}

variable "github_repository_id" {
  description = "Numeric GitHub ID of the repository. See github_owner_id."
  type        = number
  default     = null

  validation {
    condition     = (var.github_owner_id == null) == (var.github_repository_id == null)
    error_message = "github_owner_id and github_repository_id must be set together."
  }
}

variable "github_environment" {
  description = "GitHub Environment whose jobs may assume the preview role."
  type        = string
  default     = "preview"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github_environment))
    error_message = "github_environment must contain only letters, digits, '_', '.' and '-'."
  }
}

variable "plan_role_name" {
  description = "Name of an existing read-only role (the PR terraform-plan role) that is granted read access to the preview resources. null attaches nothing."
  type        = string
  default     = null

  validation {
    condition     = var.plan_role_name == null || can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.plan_role_name))
    error_message = "plan_role_name must be a valid IAM role name."
  }
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags merged onto every taggable resource, in addition to the caller's provider default_tags. The module adds Name per resource."
  type        = map(string)
  default     = {}
}
```

- [ ] **Step 4: `files/404.html`**

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="robots" content="noindex" />
    <title>Preview not found</title>
    <style>
      body {
        font-family: system-ui, sans-serif;
        display: grid;
        place-items: center;
        min-height: 100vh;
        margin: 0;
        color: #333;
      }
      main {
        text-align: center;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>Preview not found</h1>
      <p>This pull request preview does not exist or has been removed.</p>
    </main>
  </body>
</html>
```

- [ ] **Step 5: `main.tf`**

```hcl
# preview-site module
#
# A private S3 bucket fronted by CloudFront (OAC) that hosts one build per
# pull request under <key_prefix><number>/, plus a GitHub Actions OIDC role
# scoped to one repository environment that may write it.
#
# Files:
#   naming.tf      the <prefix>-preview-<resource> naming standard
#   main.tf        preview bucket and lifecycle
#   cloudfront.tf  distribution and headers (reuses the production rewrite function)
#   iam.tf         preview role; optional read grant for the plan role
#   files/         the shared 404 page uploaded to the bucket root

resource "aws_s3_bucket" "preview" {
  bucket_prefix = "${local.names.preview_bucket}-"

  tags = merge(var.tags, { Name = local.names.preview_bucket })
}

resource "aws_s3_bucket_public_access_block" "preview" {
  bucket = aws_s3_bucket.preview.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "preview" {
  bucket = aws_s3_bucket.preview.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "preview" {
  bucket = aws_s3_bucket.preview.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "preview" {
  bucket = aws_s3_bucket.preview.id

  versioning_configuration {
    status = "Suspended"
  }
}

# Safety net: a PR whose cleanup job never ran still expires.
resource "aws_s3_bucket_lifecycle_configuration" "preview" {
  bucket = aws_s3_bucket.preview.id

  rule {
    id     = "expire-stale-previews"
    status = "Enabled"

    filter {
      prefix = var.key_prefix
    }

    expiration {
      days = var.retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.preview]
}

# One 404 page at the bucket root serves every preview; each PR's own
# 404.html lives under its prefix where CloudFront cannot select it.
resource "aws_s3_object" "not_found" {
  bucket        = aws_s3_bucket.preview.id
  key           = "404.html"
  source        = "${path.module}/files/404.html"
  etag          = filemd5("${path.module}/files/404.html")
  content_type  = "text/html; charset=utf-8"
  cache_control = "public, max-age=60"

  tags = merge(var.tags, { Name = local.names.preview_bucket })
}

data "aws_iam_policy_document" "preview_bucket" {
  statement {
    sid     = "AllowCloudFrontOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.preview.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.preview.arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.preview.arn,
      "${aws_s3_bucket.preview.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "preview" {
  bucket = aws_s3_bucket.preview.id
  policy = data.aws_iam_policy_document.preview_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.preview]
}
```

- [ ] **Step 6: `cloudfront.tf`**

```hcl
# -----------------------------------------------------------------------------
# preview: CloudFront distribution in front of the preview bucket.
# -----------------------------------------------------------------------------

locals {
  preview_origin_id = "s3-preview"
}

resource "aws_cloudfront_origin_access_control" "preview" {
  name                              = local.names.preview_oac
  description                       = "OAC for ${local.names.preview_bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_response_headers_policy" "preview_security" {
  name    = local.names.preview_security_headers
  comment = "Security headers + noindex for ${local.names.preview_cdn}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000 # 2 years
      include_subdomains         = true
      preload                    = false
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }

  custom_headers_config {
    items {
      header   = "X-Robots-Tag"
      value    = var.robots_tag
      override = true
    }

    items {
      header   = "Permissions-Policy"
      value    = "camera=(), microphone=(), geolocation=()"
      override = true
    }

    dynamic "items" {
      for_each = var.extra_response_headers
      content {
        header   = items.key
        value    = items.value
        override = true
      }
    }
  }
}

resource "aws_cloudfront_distribution" "preview" {
  enabled             = true
  comment             = local.names.preview_cdn
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.price_class
  # No default_root_object: "/" goes through the rewrite function to
  # /index.html, which does not exist, and so returns the 404 page.
  wait_for_deployment = true

  origin {
    origin_id                = local.preview_origin_id
    domain_name              = aws_s3_bucket.preview.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.preview.id
  }

  default_cache_behavior {
    target_origin_id       = local.preview_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.preview_security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = var.rewrite_index_function_arn
    }
  }

  # S3 answers 403 for missing keys when the caller lacks ListBucket, so both
  # become the shared 404 page with a 404 status.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = var.error_caching_min_ttl
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = var.error_caching_min_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, { Name = local.names.preview_cdn })
}
```

- [ ] **Step 7: `iam.tf`**

```hcl
# -----------------------------------------------------------------------------
# preview role: assumed by the pull_request preview workflow through the
# repository's `preview` GitHub Environment. Writes only the preview bucket
# and invalidates only the preview distribution.
# -----------------------------------------------------------------------------

data "aws_partition" "current" {}

locals {
  github_oidc_host = "token.actions.githubusercontent.com"

  github_owner = split("/", var.github_repository)[0]
  github_name  = split("/", var.github_repository)[1]

  # Plain and immutable subject shapes, as in the static-site module.
  github_subject_prefixes = compact([
    "repo:${var.github_repository}",
    var.github_owner_id != null ? "repo:${local.github_owner}@${var.github_owner_id}/${local.github_name}@${var.github_repository_id}" : null,
  ])

  preview_subjects = [for p in local.github_subject_prefixes : "${p}:environment:${var.github_environment}"]

  partition = data.aws_partition.current.partition
}

data "aws_iam_policy_document" "preview_assume_role" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = local.preview_subjects
    }
  }
}

resource "aws_iam_role" "preview" {
  name                 = local.names.preview_github_role
  description          = "Assumed by GitHub Actions (${var.github_repository}, ${var.github_environment}) to publish PR previews to ${local.names.preview_cdn}"
  assume_role_policy   = data.aws_iam_policy_document.preview_assume_role.json
  max_session_duration = 3600

  tags = merge(var.tags, { Name = local.names.preview_github_role })
}

data "aws_iam_policy_document" "preview" {
  statement {
    sid       = "ListPreviewBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.preview.arn]
  }

  # Only keys under the PR prefix root; the shared 404 page is Terraform's.
  statement {
    sid    = "WritePreviewObjects"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.preview.arn}/${var.key_prefix}*"]
  }

  statement {
    sid       = "InvalidatePreviewDistribution"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.preview.arn]
  }
}

resource "aws_iam_role_policy" "preview" {
  name   = local.names.preview_github_policy
  role   = aws_iam_role.preview.id
  policy = data.aws_iam_policy_document.preview.json
}

# -----------------------------------------------------------------------------
# Optional: let the read-only plan role refresh this module's resources so the
# PR terraform-plan check keeps working. CloudFront read is already account
# wide in that role.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "plan_read" {
  count = var.plan_role_name != null ? 1 : 0

  statement {
    sid       = "ReadPreviewBucketConfig"
    effect    = "Allow"
    actions   = ["s3:Get*", "s3:List*"]
    resources = [aws_s3_bucket.preview.arn]
  }

  statement {
    sid       = "ReadNotFoundObject"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectTagging"]
    resources = ["${aws_s3_bucket.preview.arn}/404.html"]
  }

  statement {
    sid    = "ReadPreviewRole"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListRoleTags",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = [aws_iam_role.preview.arn]
  }
}

resource "aws_iam_role_policy" "plan_read" {
  count = var.plan_role_name != null ? 1 : 0

  name   = local.names.preview_plan_policy
  role   = var.plan_role_name
  policy = data.aws_iam_policy_document.plan_read[0].json
}
```

- [ ] **Step 8: `outputs.tf`**

```hcl
output "preview_bucket_name" {
  description = "Name of the preview bucket."
  value       = aws_s3_bucket.preview.id
}

output "preview_bucket_arn" {
  description = "ARN of the preview bucket."
  value       = aws_s3_bucket.preview.arn
}

output "preview_distribution_id" {
  description = "ID of the preview CloudFront distribution."
  value       = aws_cloudfront_distribution.preview.id
}

output "preview_distribution_arn" {
  description = "ARN of the preview CloudFront distribution."
  value       = aws_cloudfront_distribution.preview.arn
}

output "preview_distribution_domain_name" {
  description = "CloudFront hostname of the preview distribution."
  value       = aws_cloudfront_distribution.preview.domain_name
}

output "preview_role_arn" {
  description = "ARN of the IAM role the preview workflow assumes via OIDC."
  value       = aws_iam_role.preview.arn
}

output "preview_url" {
  description = "Base URL previews are served from. A PR lives at <preview_url>/<key prefix>."
  value       = "https://${aws_cloudfront_distribution.preview.domain_name}"
}

output "key_prefix" {
  description = "Key prefix the workflow must write under; it appends the PR number and a slash."
  value       = var.key_prefix
}

output "resource_names" {
  description = "Every name this module assigns, for reference and audits."
  value       = local.names
}

output "github_environment_variables" {
  description = "Variables for the GitHub Environment named in github_environment."
  value = {
    AWS_ROLE_ARN               = aws_iam_role.preview.arn
    S3_BUCKET                  = aws_s3_bucket.preview.id
    CLOUDFRONT_DISTRIBUTION_ID = aws_cloudfront_distribution.preview.id
    SITE_URL                   = "https://${aws_cloudfront_distribution.preview.domain_name}"
    PREVIEW_KEY_PREFIX         = var.key_prefix
  }
}
```

- [ ] **Step 9: Format, validate the module standalone, commit**

```bash
cd infra && terraform fmt -recursive && cd modules/preview-site && terraform init -backend=false -input=false >/dev/null && terraform validate && cd ../../..
git add infra/modules/preview-site
git commit -m "feat(infra): add preview-site module for pr previews

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

Expected: `Success! The configuration is valid.` Delete the `infra/modules/preview-site/.terraform` directory afterwards (it is git-ignored).

---

### Task 5: Wire the module into the prod root

**Files:**

- Modify: `infra/environments/prod/variables.tf`
- Modify: `infra/environments/prod/main.tf`
- Modify: `infra/environments/prod/outputs.tf`
- Modify: `infra/environments/prod/terraform.tfvars.example`

**Interfaces:**

- Consumes: Task 3 outputs, Task 4 module.
- Produces: root output `github_preview_environment_variables`, used in Task 6.

- [ ] **Step 1: Root variables**

Append to `infra/environments/prod/variables.tf`:

```hcl
# -----------------------------------------------------------------------------
# PR previews
# -----------------------------------------------------------------------------

variable "preview_enabled" {
  description = "Create the PR preview stack (bucket, distribution, OIDC role). false removes it."
  type        = bool
  default     = true
}

variable "preview_github_environment" {
  description = "GitHub Environment whose jobs may publish previews."
  type        = string
  default     = "preview"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.preview_github_environment))
    error_message = "preview_github_environment must contain only letters, digits, '_', '.' and '-'."
  }
}

variable "preview_key_prefix" {
  description = "S3 key prefix per PR; the PR number is appended (pr- => pr-9/)."
  type        = string
  default     = "pr-"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.preview_key_prefix))
    error_message = "preview_key_prefix must be non-empty and contain only letters, digits, _ and - (no slashes)."
  }
}

variable "preview_retention_days" {
  description = "Days after which preview objects expire, in case a PR's cleanup never ran."
  type        = number
  default     = 30

  validation {
    condition     = var.preview_retention_days == floor(var.preview_retention_days) && var.preview_retention_days >= 1 && var.preview_retention_days <= 365
    error_message = "preview_retention_days must be a whole number between 1 and 365."
  }
}

variable "preview_price_class" {
  description = "CloudFront price class for the preview distribution."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.preview_price_class)
    error_message = "preview_price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "preview_robots_tag" {
  description = "X-Robots-Tag header on every preview response."
  type        = string
  default     = "noindex, nofollow"

  validation {
    condition     = length(trimspace(var.preview_robots_tag)) > 0
    error_message = "preview_robots_tag must not be empty."
  }
}

variable "preview_extra_response_headers" {
  description = "Extra response headers (name => value) on every preview response."
  type        = map(string)
  default     = {}
}
```

- [ ] **Step 2: Module call**

Append to `infra/environments/prod/main.tf`:

```hcl
# PR previews: one bucket + distribution shared by every open PR, each under
# its own key prefix. Switched off entirely with preview_enabled = false.
module "preview" {
  source = "../../modules/preview-site"
  count  = var.preview_enabled ? 1 : 0

  name_prefix = local.name_prefix

  # Previews
  key_prefix                 = var.preview_key_prefix
  retention_days             = var.preview_retention_days
  price_class                = var.preview_price_class
  robots_tag                 = var.preview_robots_tag
  extra_response_headers     = var.preview_extra_response_headers
  rewrite_index_function_arn = module.site.web_rewrite_index_function_arn

  # Deploy identity
  oidc_provider_arn    = module.site.oidc_provider_arn
  github_repository    = var.github_repository
  github_owner_id      = var.github_owner_id
  github_repository_id = var.github_repository_id
  github_environment   = var.preview_github_environment
  plan_role_name       = module.site.plan_role_name

  tags = local.standard_tags
}
```

- [ ] **Step 3: Root outputs**

Append to `infra/environments/prod/outputs.tf`:

```hcl
# -----------------------------------------------------------------------------
# PR previews. All null when preview_enabled = false.
# -----------------------------------------------------------------------------

output "preview_url" {
  description = "Base URL of PR previews."
  value       = one(module.preview[*].preview_url)
}

output "preview_role_arn" {
  description = "Role the preview workflow assumes."
  value       = one(module.preview[*].preview_role_arn)
}

output "github_preview_environment_variables" {
  description = "Everything to paste into the GitHub `preview` environment."
  value = var.preview_enabled ? merge(
    module.preview[0].github_environment_variables,
    { AWS_REGION = var.aws_region },
  ) : null
}
```

- [ ] **Step 4: tfvars example**

Append to `infra/environments/prod/terraform.tfvars.example`:

```hcl

# PR previews (https://<preview cdn>/pr-<n>/). All optional.
# preview_enabled                = true
# preview_github_environment     = "preview"
# preview_key_prefix             = "pr-"
# preview_retention_days         = 30
# preview_price_class            = "PriceClass_100"
# preview_robots_tag             = "noindex, nofollow"
# preview_extra_response_headers = { X-Preview = "true" }
```

- [ ] **Step 5: Format, validate both ways**

```bash
cd infra && terraform fmt -check -recursive && cd environments/prod
terraform init -backend=false -input=false >/dev/null
terraform validate
cd ../../..
```

Expected: `Success! The configuration is valid.` The `preview_enabled = false` path is exercised by the second plan in Step 6.

- [ ] **Step 6: Plan against prod with the admin profile**

```bash
cd infra/environments/prod
AWS_PROFILE=prog-strength-admin terraform init -input=false
AWS_PROFILE=prog-strength-admin terraform plan -input=false -out=tfplan
AWS_PROFILE=prog-strength-admin terraform plan -input=false -lock=false -var preview_enabled=false | grep -E '^Plan:|No changes'
cd ../../..
```

Expected: the first plan adds only `module.preview[0].*` resources plus the `plan_read` role policy, changes nothing in `module.site` except outputs. The second prints `No changes.` (previews are not created yet) which proves the off switch plans cleanly.

- [ ] **Step 7: Commit**

```bash
git add infra/environments/prod
git commit -m "feat(infra): apply the preview-site module from the prod root

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Apply and create the GitHub `preview` environment

**Files:** none in the repo.

**Interfaces:**

- Produces: live AWS resources and GitHub environment variables `AWS_ROLE_ARN`, `AWS_REGION`, `S3_BUCKET`, `CLOUDFRONT_DISTRIBUTION_ID`, `SITE_URL` on environment `preview`, read by Task 7.

- [ ] **Step 1: Apply**

```bash
cd infra/environments/prod
AWS_PROFILE=prog-strength-admin terraform apply tfplan
AWS_PROFILE=prog-strength-admin terraform output github_preview_environment_variables
cd ../../..
```

Expected: `Apply complete! Resources: N added, 0 changed, 0 destroyed.` CloudFront takes a few minutes.

- [ ] **Step 2: Verify the 404 page and header are live**

```bash
url=$(cd infra/environments/prod && AWS_PROFILE=prog-strength-admin terraform output -raw preview_url)
curl -sI "$url/pr-0/" | grep -iE '^(HTTP|x-robots-tag)'
```

Expected: `HTTP/2 404` and `x-robots-tag: noindex, nofollow`.

- [ ] **Step 3: Create the environment and its variables**

```bash
REPO=jwallace145/site
gh api -X PUT "repos/$REPO/environments/preview" --input - <<'JSON'
{ "deployment_branch_policy": null }
JSON
cd infra/environments/prod
for kv in $(AWS_PROFILE=prog-strength-admin terraform output -json github_preview_environment_variables | jq -r 'to_entries[] | "\(.key)=\(.value)"'); do
  gh variable set "${kv%%=*}" --env preview --repo "$REPO" --body "${kv#*=}"
done
cd ../../..
gh variable list --env preview --repo "$REPO"
```

Expected: six variables listed (`AWS_ROLE_ARN`, `AWS_REGION`, `S3_BUCKET`, `CLOUDFRONT_DISTRIBUTION_ID`, `SITE_URL`, `PREVIEW_KEY_PREFIX`).

---

### Task 7: `preview.yml` workflow

**Files:**

- Create: `.github/workflows/preview.yml`

**Interfaces:**

- Consumes: `BASE_PATH` (Task 2), environment variables (Task 6).

- [ ] **Step 1: Write the workflow**

```yaml
name: Preview

# Publishes a live preview of each pull request to the preview bucket under
# pr-<number>/ and removes it when the PR closes. Fork PRs receive no OIDC
# token, so both jobs only run for branches in this repository. Informational:
# not a required check.

on:
  pull_request:
    types: [opened, synchronize, reopened, closed]

permissions:
  contents: read

concurrency:
  group: preview-${{ github.event.pull_request.number }}
  cancel-in-progress: true

# PREFIX is computed per job because PREVIEW_KEY_PREFIX is an environment
# variable, only resolvable inside a job that declares `environment: preview`.
env:
  PR_NUMBER: ${{ github.event.pull_request.number }}
  COMMENT_MARKER: "<!-- preview-deploy -->"

jobs:
  deploy:
    name: deploy
    if: >-
      github.event.action != 'closed' &&
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest
    environment:
      name: preview
      url: ${{ vars.SITE_URL }}/${{ vars.PREVIEW_KEY_PREFIX }}${{ github.event.pull_request.number }}/
    permissions:
      contents: read
      id-token: write # OIDC token for the preview role
      pull-requests: write # sticky preview comment
    env:
      PREFIX: ${{ vars.PREVIEW_KEY_PREFIX }}${{ github.event.pull_request.number }}
    steps:
      # actions/checkout v7.0.1
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
        with:
          persist-credentials: false

      - uses: ./.github/actions/setup

      - name: Build under /pr-<n>
        run: pnpm build
        env:
          SITE_URL: ${{ vars.SITE_URL }}
          BASE_PATH: /${{ env.PREFIX }}

      - name: Configure AWS credentials (OIDC, preview role)
        # aws-actions/configure-aws-credentials v6.3.0
        uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
          role-session-name: github-preview-pr${{ env.PR_NUMBER }}

      - name: Sync to S3
        env:
          S3_BUCKET: ${{ vars.S3_BUCKET }}
        run: |
          set -euo pipefail
          dest="s3://$S3_BUCKET/$PREFIX/"

          # 1. Everything except HTML and hashed assets: short cache.
          aws s3 sync dist/ "$dest" \
            --delete \
            --exclude "*.html" \
            --exclude "_astro/*" \
            --cache-control "public, max-age=300"

          # 2. Hashed assets under _astro/: cache forever.
          aws s3 sync dist/_astro/ "${dest}_astro/" \
            --delete \
            --cache-control "public, max-age=31536000, immutable"

          # 3. HTML: always revalidate so each push shows up immediately.
          aws s3 sync dist/ "$dest" \
            --delete \
            --exclude "*" \
            --include "*.html" \
            --cache-control "public, max-age=0, must-revalidate" \
            --content-type "text/html; charset=utf-8"

      - name: Invalidate CloudFront
        env:
          CLOUDFRONT_DISTRIBUTION_ID: ${{ vars.CLOUDFRONT_DISTRIBUTION_ID }}
        run: |
          aws cloudfront create-invalidation \
            --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
            --paths "/$PREFIX/*" \
            --query 'Invalidation.Id' --output text

      - name: Comment preview URL
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GH_REPO: ${{ github.repository }}
          SHA: ${{ github.event.pull_request.head.sha }}
          SITE_URL: ${{ vars.SITE_URL }}
        run: |
          url="$SITE_URL/$PREFIX/"
          body_file=$(mktemp)
          {
            echo "$COMMENT_MARKER"
            echo "## Preview"
            echo
            echo "**$url**"
            echo
            echo "Built from $SHA. Updated on every push; removed when the PR closes."
          } > "$body_file"
          existing=$(gh api "repos/$GH_REPO/issues/$PR_NUMBER/comments" --paginate \
            --jq ".[] | select(.body | startswith(\"$COMMENT_MARKER\")) | .id" | head -n1)
          if [ -n "$existing" ]; then
            gh api -X PATCH "repos/$GH_REPO/issues/comments/$existing" -F body=@"$body_file" >/dev/null
          else
            gh api "repos/$GH_REPO/issues/$PR_NUMBER/comments" -F body=@"$body_file" >/dev/null
          fi
          { echo "## Preview"; echo; echo "- $url"; } >> "$GITHUB_STEP_SUMMARY"

  cleanup:
    name: cleanup
    if: >-
      github.event.action == 'closed' &&
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest
    environment:
      name: preview
    permissions:
      contents: read
      id-token: write
      pull-requests: write
    env:
      PREFIX: ${{ vars.PREVIEW_KEY_PREFIX }}${{ github.event.pull_request.number }}
    steps:
      - name: Configure AWS credentials (OIDC, preview role)
        # aws-actions/configure-aws-credentials v6.3.0
        uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
          role-session-name: github-preview-cleanup-pr${{ env.PR_NUMBER }}

      - name: Remove preview objects
        env:
          S3_BUCKET: ${{ vars.S3_BUCKET }}
        # `aws s3 rm --recursive` on an empty prefix exits 0.
        run: aws s3 rm "s3://$S3_BUCKET/$PREFIX/" --recursive

      - name: Invalidate CloudFront
        env:
          CLOUDFRONT_DISTRIBUTION_ID: ${{ vars.CLOUDFRONT_DISTRIBUTION_ID }}
        run: |
          aws cloudfront create-invalidation \
            --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
            --paths "/$PREFIX/*" \
            --query 'Invalidation.Id' --output text

      - name: Update preview comment
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GH_REPO: ${{ github.repository }}
        run: |
          existing=$(gh api "repos/$GH_REPO/issues/$PR_NUMBER/comments" --paginate \
            --jq ".[] | select(.body | startswith(\"$COMMENT_MARKER\")) | .id" | head -n1)
          if [ -n "$existing" ]; then
            printf '%s\n## Preview\n\nRemoved: this pull request is closed.\n' "$COMMENT_MARKER" > body.md
            gh api -X PATCH "repos/$GH_REPO/issues/comments/$existing" -F body=@body.md >/dev/null
          else
            echo "No preview comment to update."
          fi
```

- [ ] **Step 2: Lint the YAML and commit**

```bash
pnpm format   # prettier formats .github/workflows/*.yml
git add .github/workflows/preview.yml
git commit -m "ci: publish a live preview for every pull request

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Documentation

**Files:**

- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `infra/README.md`
- Modify: `docs/repo-setup.md`

- [ ] **Step 1: README**

After the release flow bullet list, add:

```markdown
### PR previews

Every pull request from a branch in this repository is built with
`BASE_PATH=/pr-<n>` and published to a separate preview bucket + CloudFront
distribution at `https://<preview-cdn>/pr-<n>/`. The URL is posted as a
sticky comment and as the PR's `preview` deployment; the prefix is deleted
when the PR closes. Previews send `X-Robots-Tag: noindex`. Forks get no
preview (no OIDC token). See [`infra/README.md`](infra/README.md).
```

Also add `preview.yml (PR previews)` to the `.github/` line in the layout block.

- [ ] **Step 2: CONTRIBUTING**

In the checks table (around line 104), add a row:

```markdown
| `BASE_PATH=/pr-0 pnpm build` | links honour Astro `base` (needed for PR previews) |
```

And after the table a paragraph:

```markdown
Internal links must go through `withBase()` from `src/lib/utils.ts` (or
Astro's own URL helpers) so they work when the site is served under
`/pr-<n>/` on previews. The build check above fails on any `href="/..."`
that bypasses it. PRs from branches in this repo get a live preview comment;
fork PRs do not.
```

- [ ] **Step 3: infra/README**

Add `modules/preview-site/` to the tree, a `preview` row block to the names table:

```markdown
| S3 bucket (previews) | `jwallace145-site-preview-bucket-<aws suffix>` |
| Origin access control (previews) | `jwallace145-site-preview-oac` |
| CloudFront distribution (previews) | `jwallace145-site-preview-cdn` |
| Response headers policy (previews) | `jwallace145-site-preview-security-headers` |
| IAM role (previews) | `jwallace145-site-preview-github-role` |
| IAM role policy (previews) | `jwallace145-site-preview-github-policy` |
| IAM role policy (plan → previews) | `jwallace145-site-preview-github-plan-policy` |
```

a row to the OIDC trust table:

```markdown
| `jwallace145-site-preview-github-role` | jobs in the `preview` environment | write `pr-*/` in the preview bucket, invalidate the preview CDN |
```

and a section:

```markdown
## PR previews

`modules/preview-site` is applied from the prod root when
`preview_enabled = true` (default). One private bucket and one distribution
host every open PR under `pr-<n>/`; a lifecycle rule expires those keys after
`preview_retention_days`. The shared `404.html` at the bucket root is
uploaded by Terraform. Every knob (`preview_*` in
`environments/prod/variables.tf`) is set from `terraform.tfvars`.

After apply: `terraform output github_preview_environment_variables` goes on
the GitHub `preview` environment (`docs/repo-setup.md` section 5c).
```

- [ ] **Step 4: repo-setup**

After section 5b add:

````markdown
## 5c. `preview` environment (PR previews)

Created after `terraform apply` with `preview_enabled = true`. No branch
policy: any PR from this repository may deploy a preview.

```bash
gh api -X PUT "repos/$REPO/environments/preview" --input - <<'JSON'
{ "deployment_branch_policy": null }
JSON

# From infra/environments/prod/: terraform output github_preview_environment_variables
gh variable set AWS_ROLE_ARN               --env preview --repo "$REPO" --body "arn:aws:iam::<account>:role/jwallace145-site-preview-github-role"
gh variable set AWS_REGION                 --env preview --repo "$REPO" --body "us-east-1"
gh variable set S3_BUCKET                  --env preview --repo "$REPO" --body "<preview bucket name>"
gh variable set CLOUDFRONT_DISTRIBUTION_ID --env preview --repo "$REPO" --body "<preview distribution id>"
gh variable set SITE_URL                   --env preview --repo "$REPO" --body "https://<preview cloudfront domain>"
gh variable set PREVIEW_KEY_PREFIX         --env preview --repo "$REPO" --body "pr-"
```
````

````

Update the "Verify" section's `gh variable list` lines to include `--env preview`.

- [ ] **Step 5: Format and commit**

```bash
pnpm format
git add README.md CONTRIBUTING.md infra/README.md docs/repo-setup.md
git commit -m "docs: describe pr previews and the preview environment

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
````

---

### Task 9: Open the PR and verify end to end

- [ ] **Step 1: Push and open the PR** (feature template, title `feat: add live previews for pull requests`). The PR runs `preview.yml` from the branch, so the preview appears on this very PR.

- [ ] **Step 2: Wait for checks**

```bash
gh pr checks <n> --watch
```

Expected: all CI checks pass; `terraform-plan` comment reports `No changes.` (already applied); `deploy` job in Preview workflow succeeds and a `## Preview` comment appears.

- [ ] **Step 3: Verify the preview in a browser**

Open the preview URL. Check: home renders, navbar Blog link goes to `/pr-<n>/blog`, blog post back link returns to `/pr-<n>/blog`, avatar loads, `curl -sI <url>` shows `x-robots-tag`.

- [ ] **Step 4: Report** the PR link and preview URL to the owner. After the owner merges, confirm the `cleanup` job ran and `curl -sI <preview url>` returns 404.
