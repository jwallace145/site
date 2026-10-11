# PR preview deployments

**Date:** 2026-10-11
**Status:** approved design, pending implementation plan

## Goal

Every pull request from a branch in `jwallace145/site` gets a live preview of
the built site at a stable URL, updated on each push and removed when the PR
closes. Previews reuse the production stack's patterns (S3 + CloudFront, OIDC,
Terraform module + thin live root) and add no long-lived credentials.

## Constraints and decisions

- **Hosting shape:** path prefix on AWS. One long-lived preview bucket and one
  preview CloudFront distribution; each PR is a key prefix `pr-<number>/`.
  Chosen over subdomain-per-PR (needs a custom domain, none configured) and
  over a third-party host (would add a second provider).
- **Terraform interface:** modular code with a well-defined, validated
  variables interface. Every configurable knob is a module variable surfaced
  through the live root's `terraform.tfvars`; nothing is hard-coded in the
  module that a user would reasonably want to change.
- **Fork PRs** receive no OIDC token and therefore get no preview. The
  workflow skips them explicitly.
- **Not a required check.** Previews are informational.
- **Apply:** the owner's local `AWS_PROFILE=prog-strength-admin` applies the
  change; CI only plans.

## 1. Infrastructure

### New module: `infra/modules/preview-site`

Sibling of `static-site`. The production module is not modified except to
export three values the preview module consumes (below).

Files, mirroring the existing module layout:

| File            | Contents                                                       |
| --------------- | -------------------------------------------------------------- |
| `naming.tf`     | `<name_prefix>-preview-<resource>` names, all in one place     |
| `main.tf`       | preview bucket, public access block, ownership, SSE, lifecycle |
| `cloudfront.tf` | OAC, response headers policy, distribution                     |
| `iam.tf`        | GitHub OIDC preview role and policy                            |
| `variables.tf`  | the interface (see below)                                      |
| `outputs.tf`    | names, ARNs, URL, and a ready-to-paste GitHub env map          |
| `versions.tf`   | provider requirements                                          |

Resources and names:

| Resource                                 | Name                                        |
| ---------------------------------------- | ------------------------------------------- |
| `aws_s3_bucket`                          | `jwallace145-site-preview-bucket-<suffix>`  |
| `aws_cloudfront_origin_access_control`   | `jwallace145-site-preview-oac`              |
| `aws_cloudfront_distribution`            | `jwallace145-site-preview-cdn`              |
| `aws_cloudfront_response_headers_policy` | `jwallace145-site-preview-security-headers` |
| `aws_iam_role`                           | `jwallace145-site-preview-github-role`      |
| `aws_iam_role_policy`                    | `jwallace145-site-preview-github-policy`    |

Behaviour:

- **Bucket** is private, OAC-only, AES256, versioning suspended, same policy
  shape as the web bucket (allow the preview distribution, deny insecure
  transport). A lifecycle rule expires every object after
  `preview_retention_days` as a safety net for PRs whose cleanup never ran.
- **Distribution** reuses the production `rewrite-index` CloudFront Function
  by ARN (functions may be associated with many distributions). Its response
  headers policy copies the production security headers and adds
  `X-Robots-Tag: noindex, nofollow` so previews are never indexed. 403 and 404
  from S3 map to a 404 status with no custom page: CloudFront accepts a single
  error page path, but each PR's `404.html` lives under its own prefix.
  Terraform uploads a minimal shared `404.html` to the bucket root instead.
- **Role** trusts `repo:<owner>/<name>:environment:<github_environment>` in
  both plain and immutable subject shapes, exactly as the deploy role does.
  Permissions: `s3:ListBucket` on the preview bucket, `s3:PutObject` and
  `s3:DeleteObject` on `<bucket>/*`, `cloudfront:CreateInvalidation` on the
  preview distribution. Nothing else.

### Variables interface

Every variable has a description, a type, and a validation where the value
has a constrained shape. Defaults match this project.

| Variable                     | Type        | Default               | Validation                                       |
| ---------------------------- | ----------- | --------------------- | ------------------------------------------------ |
| `name_prefix`                | string      | required              | `^[a-z0-9][a-z0-9-]{1,24}$`                      |
| `github_repository`          | string      | required              | `owner/name`                                     |
| `github_owner_id`            | number      | null                  | must be set together with `github_repository_id` |
| `github_repository_id`       | number      | null                  | see above                                        |
| `github_environment`         | string      | `"preview"`           | non-empty, `^[A-Za-z0-9_.-]+$`                   |
| `oidc_provider_arn`          | string      | required              | `^arn:aws[a-z-]*:iam::\d{12}:oidc-provider/`     |
| `rewrite_index_function_arn` | string      | required              | `^arn:aws[a-z-]*:cloudfront::\d{12}:function/`   |
| `preview_retention_days`     | number      | 30                    | integer, 1–365                                   |
| `price_class`                | string      | `PriceClass_100`      | one of the three CloudFront price classes        |
| `error_caching_min_ttl`      | number      | 60                    | 0–86400                                          |
| `robots_tag`                 | string      | `"noindex, nofollow"` | non-empty                                        |
| `extra_response_headers`     | map(string) | `{}`                  | header names `^[A-Za-z0-9-]+$`                   |
| `tags`                       | map(string) | `{}`                  | none                                             |

The three `required` inputs that come from the production module
(`oidc_provider_arn`, `rewrite_index_function_arn`, and the subject prefixes
derived from the GitHub inputs) are passed by the live root from
`module.site` outputs. `static-site/outputs.tf` gains:

- `oidc_provider_arn`
- `web_rewrite_index_function_arn`

- `plan_role_name`

The preview module takes `plan_role_name` (nullable) and attaches a small
read-only policy to that role so the PR `terraform-plan` check can refresh
the preview resources. This keeps the dependency one-way (preview depends on
static-site, never the reverse).

### Live root changes (`infra/environments/prod`)

- `main.tf`: `module "preview"` wired from `module.site` outputs and new root
  variables.
- `variables.tf`: new `preview` block of variables, each with description,
  default, and validation: `preview_enabled` (bool, default true),
  `preview_github_environment`, `preview_retention_days`,
  `preview_price_class`, `preview_robots_tag`. `count = var.preview_enabled ? 1 : 0`
  on the module so previews can be switched off from tfvars alone.
- `terraform.tfvars.example`: documents every preview knob.
- `outputs.tf`: `github_preview_environment_variables` map with
  `AWS_ROLE_ARN`, `AWS_REGION`, `S3_BUCKET`, `CLOUDFRONT_DISTRIBUTION_ID`,
  `SITE_URL`, `PREVIEW_KEY_PREFIX`, mirroring the production map.

## 2. Workflow: `.github/workflows/preview.yml`

```
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
permissions: { contents: read }
concurrency: preview-<pr number>, cancel-in-progress: true
```

Both jobs guard on `github.event.pull_request.head.repo.full_name == github.repository`.

**deploy** (`action != closed`)

- `environment: { name: preview, url: <SITE_URL>/<PREVIEW_KEY_PREFIX><n>/ }`;
  the environment's `SITE_URL` is the preview CDN and `PREVIEW_KEY_PREFIX`
  comes from Terraform, so the workflow and the bucket policy always agree.
- permissions: `id-token: write`, `pull-requests: write`
- steps: checkout (no persisted creds) → setup action → `pnpm build` with
  `SITE_URL=<preview cdn>` and `BASE_PATH=/pr-<n>` → assume preview role
  → sync `dist/` to `s3://<bucket>/pr-<n>/` using the same three
  cache-control tiers as the release workflow, `--delete` scoped to the prefix
  → invalidate `/pr-<n>/*` → sticky comment (marker
  `<!-- preview-deploy -->`) with URL and head SHA, created or patched with
  the same `gh api` pattern the terraform-plan job uses.

**cleanup** (`action == closed`)

- permissions: `id-token: write`, `pull-requests: write`
- steps: assume preview role → `aws s3 rm --recursive s3://<bucket>/pr-<n>/`
  → invalidate `/pr-<n>/*` → patch the sticky comment to "Preview removed".

GitHub `preview` environment: no protection rules, four variables from the
Terraform output. `docs/repo-setup.md` gets a section with the `gh` commands.

## 3. Application: honour Astro `base`

- `astro.config.mjs`: `base: BASE_PATH || "/"` read via the existing
  `loadEnv` call. `.env.example` documents `BASE_PATH`.
- `src/lib/utils.ts`: `withBase(path: string): string` that prefixes a
  root-relative path with `import.meta.env.BASE_URL`, collapsing duplicate
  slashes and leaving absolute URLs, `mailto:`, and `#` fragments untouched.
  Unit-tested with Vitest.
- Apply `withBase` at render sites, not in the data file:
  `navbar.tsx` (nav hrefs), `Layout.astro` (favicons, canonical, OG image
  path), `404.astro` (home link), `blog/[...page].astro` and
  `blog/[slug].astro` (post and back links), `BlogList.tsx`, `HomePage.tsx`
  (avatar). The about-section `<Markdown>` gets a `urlTransform` that applies
  `withBase` so `/#work` style links stay in the preview.
- `ci.yml` build job: after the normal build, run a second
  `BASE_PATH=/pr-0 pnpm build` into a separate `outDir` and fail if
  `grep -R 'href="/blog"' dist-preview` or the client bundle contains an
  un-prefixed `"/blog"` string. This keeps previews from silently breaking
  when someone adds a hard-coded link.

## 4. Documentation

- `README.md`: "PR previews" paragraph under the release flow.
- `CONTRIBUTING.md`: what a contributor sees on a PR and that forks get none.
- `infra/README.md`: the preview module, its variables, and the GitHub
  environment it feeds.
- `docs/repo-setup.md`: creating the `preview` environment and its variables.

## Rollout

1. Land the Terraform and app changes in one PR. The PR's own
   `terraform-plan` check shows the new resources.
2. Owner applies locally with `AWS_PROFILE=prog-strength-admin`.
3. Create the GitHub `preview` environment from the Terraform output.
4. Merge; the next PR exercises the preview workflow end to end.

## Out of scope

- Per-PR styled 404 pages on previews (a shared plain page is served).
- Previews for fork PRs.
- Subdomain-per-PR; revisit when a custom domain exists.
