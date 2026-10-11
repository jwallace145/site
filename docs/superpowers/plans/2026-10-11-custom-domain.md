# Custom Domain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve the site at `https://jwall.engineering` (www redirecting to it) and previews at `https://preview.jwall.engineering/pr-<n>/`, with all DNS in a Terraform-managed Route 53 zone.

**Architecture:** A new `dns-zone` module owns the hosted zone and generic records. `static-site` gains redirect hostnames (cert SANs, aliases, A/AAAA records, a 301 in the shared CloudFront function). `preview-site` gains an optional custom hostname. The prod root wires them with validated variables whose defaults are this project's values. Cutover is two commits: zone first, site attachment after nameserver delegation.

**Tech Stack:** Terraform 1.14 / AWS provider 6.x (Route 53, ACM, CloudFront), CloudFront Functions (cloudfront-js-2.0), Vitest for the function logic, GitHub CLI.

**Spec:** `docs/superpowers/specs/2026-10-11-custom-domain-design.md`

## Global Constraints

- Names follow `<name_prefix>-<domain>-<resource>`; every name lives in the module's `naming.tf`.
- Every Terraform variable has `description`, `type`, a default where sensible, and `validation` wherever the value has a constrained shape. Project values are root defaults in `infra/environments/prod/variables.tf`, overridable from `terraform.tfvars`.
- Commits are one line, conventional, ≤100 chars, trailers only after the header, ending `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Lefthook runs Prettier/ESLint on commit; `pnpm format` before committing anything outside `infra/*.tf`.
- `terraform fmt -check -recursive` and `terraform validate` must pass; applies use `AWS_PROFILE=prog-strength-admin` from `infra/environments/prod/`.
- Phase 2 (attaching `domain_name`) must not be applied until `dig +short NS jwall.engineering` returns the Route 53 nameservers; the GoDaddy change is the owner's.
- Never touch the production distribution's existing behaviour for the cloudfront.net hostname: it keeps working throughout.

## Review Focus

1. **Request to `www.jwall.engineering/blog?x=1`** must 301 to `https://jwall.engineering/blog?x=1`, path and query intact. Pinned by the function tests in Task 2.
2. **Request to the preview hostname or the cloudfront.net hostname** must never redirect; it gets the index rewrite as today. Pinned by the function tests in Task 2.
3. **`domain_name = null` (today's state)** must render a function with an empty redirect list that behaves exactly like the current one. Pinned by the function test "no primary host" in Task 2 and the phase-1 plan in Task 4 showing no change to the production distribution.
4. **A `dns_records` key like `"mail"` or `"@"`** must resolve to `mail.jwall.engineering` / the apex, never `mail.jwall.engineering.jwall.engineering`. Pinned by the validate-with-example-records plan in Task 1.
5. **`preview_use_custom_domain = false` or `domain_name = null`** must leave the preview distribution on cloudfront.net with no certificate resources. Pinned by the phase-1 plan in Task 4 (preview module unchanged).

---

### Task 1: `dns-zone` module

**Files:**

- Create: `infra/modules/dns-zone/versions.tf`
- Create: `infra/modules/dns-zone/naming.tf`
- Create: `infra/modules/dns-zone/variables.tf`
- Create: `infra/modules/dns-zone/main.tf`
- Create: `infra/modules/dns-zone/outputs.tf`

**Interfaces:**

- Produces: inputs `name_prefix`, `zone_name`, `comment`, `records`, `tags`; outputs `zone_id`, `zone_name`, `name_servers`, `resource_names`. Root (Task 4) consumes `zone_id` and `name_servers`.

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
# Naming standard: <name_prefix>-dns-<resource>. The hosted zone's own name
# is the domain; this is its Name tag.
locals {
  prefix = var.name_prefix

  names = {
    dns_zone = "${local.prefix}-dns-zone"
  }
}
```

- [ ] **Step 3: `variables.tf`**

```hcl
variable "name_prefix" {
  description = "Prefix for resource Name tags, e.g. jwallace145-site."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits and hyphens, 2-25 characters."
  }
}

variable "zone_name" {
  description = "Domain the hosted zone is authoritative for, e.g. example.com. Lowercase, no trailing dot."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.zone_name))
    error_message = "zone_name must be a lowercase fully qualified domain name without a trailing dot."
  }
}

variable "comment" {
  description = "Hosted zone comment shown in the Route 53 console."
  type        = string
  default     = "Managed by Terraform"
}

variable "records" {
  description = <<-EOT
    DNS records to create in the zone, keyed by record name: "@" is the apex,
    "mail" becomes mail.<zone_name>, and a name already ending in the zone
    name is used as is. CloudFront alias records are owned by the site
    modules, not this map.
  EOT
  type = map(object({
    type   = string
    ttl    = optional(number, 300)
    values = list(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.records) : contains(["A", "AAAA", "CNAME", "MX", "TXT", "SRV", "CAA", "NS"], r.type)])
    error_message = "records[*].type must be one of A, AAAA, CNAME, MX, TXT, SRV, CAA, NS."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : r.ttl >= 60 && r.ttl <= 86400])
    error_message = "records[*].ttl must be between 60 and 86400 seconds."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : length(r.values) > 0])
    error_message = "records[*].values must contain at least one value."
  }

  validation {
    condition     = alltrue([for k in keys(var.records) : can(regex("^(@|[a-z0-9_]([a-z0-9_.-]*[a-z0-9_])?)$", k))])
    error_message = "records keys must be \"@\" or a lowercase hostname label/path (letters, digits, '_', '-', '.')."
  }
}

variable "tags" {
  description = "Tags merged onto every taggable resource. The module adds Name."
  type        = map(string)
  default     = {}
}
```

- [ ] **Step 4: `main.tf`**

```hcl
# dns-zone module
#
# One public Route 53 hosted zone plus any plain records the caller lists.
# Alias records that point at CloudFront are created by the site modules,
# which know the distribution; this module only owns the zone and generic
# records (MX, TXT, CNAME, ...).

resource "aws_route53_zone" "this" {
  name    = var.zone_name
  comment = var.comment

  tags = merge(var.tags, { Name = local.names.dns_zone })
}

locals {
  # "@" -> zone apex; "mail" -> mail.<zone>; "x.<zone>" -> unchanged.
  record_fqdns = {
    for key, r in var.records : key => (
      key == "@" ? var.zone_name :
      endswith(key, var.zone_name) ? key :
      "${key}.${var.zone_name}"
    )
  }
}

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = aws_route53_zone.this.zone_id
  name    = local.record_fqdns[each.key]
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.values
}
```

- [ ] **Step 5: `outputs.tf`**

```hcl
output "zone_id" {
  description = "Hosted zone ID, for alias records and ACM validation."
  value       = aws_route53_zone.this.zone_id
}

output "zone_name" {
  description = "The zone's domain name."
  value       = var.zone_name
}

output "name_servers" {
  description = "The four Route 53 nameservers to set at the registrar."
  value       = aws_route53_zone.this.name_servers
}

output "resource_names" {
  description = "Every name this module assigns."
  value       = local.names
}
```

- [ ] **Step 6: Validate, including a negative variable test and the name-resolution logic**

```bash
cd infra/modules/dns-zone && terraform init -backend=false -input=false >/dev/null && terraform validate
# Negative: a bad zone name must be rejected by the validation block.
terraform plan -input=false -var name_prefix=x -var 'zone_name=Bad_Name' 2>&1 | grep -q "lowercase fully qualified" && echo "validation ok"
# Name resolution: plan with example records and read the computed names.
cat > /tmp/dns-test.tfvars <<'EOF'
name_prefix = "jwallace145-site"
zone_name   = "jwall.engineering"
records = {
  "@"                      = { type = "TXT", values = ["v=spf1 -all"] }
  "mail"                   = { type = "MX", ttl = 3600, values = ["10 mx.example.net."] }
  "_dmarc.jwall.engineering" = { type = "TXT", values = ["v=DMARC1; p=none"] }
}
EOF
AWS_PROFILE=prog-strength-admin terraform plan -input=false -var-file=/tmp/dns-test.tfvars -no-color 2>&1 | grep -E '^\s+\+ name\s+='
rm -rf .terraform .terraform.lock.hcl; cd ../../..
```

Expected: `Success!`, `validation ok`, and three `+ name = "..."` lines reading `"jwall.engineering"`, `"mail.jwall.engineering"`, `"_dmarc.jwall.engineering"` (any order).

- [ ] **Step 7: Format and commit**

```bash
terraform -chdir=infra fmt -recursive
git add infra/modules/dns-zone
git commit -m "feat(infra): add dns-zone module for route 53 hosted zones

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: `static-site` redirect hostnames and templated function

**Files:**

- Create: `infra/modules/static-site/function/rewrite-index.js.tftpl` (replaces `rewrite-index.js`)
- Delete: `infra/modules/static-site/function/rewrite-index.js`
- Create: `infra/modules/static-site/function/rewrite-index.test.mjs`
- Modify: `infra/modules/static-site/variables.tf`
- Modify: `infra/modules/static-site/cloudfront.tf`
- Modify: `infra/modules/static-site/main.tf` (header comment only)

**Interfaces:**

- Produces: variable `redirect_hostnames` (list(string), default []). Root (Task 4) passes `["www.<domain>"]` when `www_redirect` is true.

- [ ] **Step 1: Write the failing function tests**

```js
// infra/modules/static-site/function/rewrite-index.test.mjs
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
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `pnpm test -- infra/modules/static-site/function`
Expected: FAIL with `ENOENT ... rewrite-index.js.tftpl`.

- [ ] **Step 3: Write the template and delete the old file**

`infra/modules/static-site/function/rewrite-index.js.tftpl`:

```js
// CloudFront Function (viewer-request, cloudfront-js-2.0). Rendered by
// Terraform's templatefile(): the two placeholders below are substituted.
//
// 1. Hostname redirect: a request whose Host is one of REDIRECT_HOSTS (e.g.
//    www.example.com) is 301-redirected to PRIMARY_HOST with its path and
//    query string intact. Other hosts (the preview distribution, the raw
//    cloudfront.net name) are left alone.
// 2. Index rewrite: Astro's directory build format produces
//    /about/index.html. S3 only serves a default document at the root, so
//      /about/  -> /about/index.html
//      /about   -> /about/index.html
//    Paths whose last segment has an extension (e.g. /favicon.svg) pass
//    through.

var PRIMARY_HOST = "${primary_host}";
var REDIRECT_HOSTS = ${redirect_hosts};

function buildQueryString(querystring) {
  var parts = [];
  for (var key in querystring) {
    var entry = querystring[key];
    if (entry.multiValue) {
      for (var i = 0; i < entry.multiValue.length; i++) {
        parts.push(key + '=' + entry.multiValue[i].value);
      }
    } else if (entry.value === '') {
      parts.push(key);
    } else {
      parts.push(key + '=' + entry.value);
    }
  }
  return parts.length ? '?' + parts.join('&') : '';
}

function handler(event) {
  var request = event.request;
  var uri = request.uri;

  var host = request.headers.host && request.headers.host.value;
  if (PRIMARY_HOST && host && REDIRECT_HOSTS.indexOf(host) !== -1) {
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: {
        location: { value: 'https://' + PRIMARY_HOST + uri + buildQueryString(request.querystring) }
      }
    };
  }

  if (uri.endsWith('/')) {
    request.uri = uri + 'index.html';
    return request;
  }

  var lastSegment = uri.substring(uri.lastIndexOf('/') + 1);
  if (!lastSegment.includes('.')) {
    request.uri = uri + '/index.html';
  }

  return request;
}
```

Then `git rm infra/modules/static-site/function/rewrite-index.js`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `pnpm test -- infra/modules/static-site/function`
Expected: PASS, 7 tests. Also `pnpm test` overall stays green.

- [ ] **Step 5: Add `redirect_hostnames` to `variables.tf`**

After the `hosted_zone_id` variable:

```hcl
variable "redirect_hostnames" {
  description = "Hostnames that 301-redirect to domain_name (e.g. www.example.com). Added to the certificate, the distribution aliases and the hosted zone. Requires domain_name."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for h in var.redirect_hostnames : can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", h))])
    error_message = "redirect_hostnames must be lowercase fully qualified domain names."
  }

  validation {
    condition     = length(var.redirect_hostnames) == 0 || var.domain_name != null
    error_message = "redirect_hostnames requires domain_name."
  }

  validation {
    condition     = !contains(var.redirect_hostnames, coalesce(var.domain_name, "-"))
    error_message = "redirect_hostnames must not contain domain_name itself."
  }
}
```

- [ ] **Step 6: Update `cloudfront.tf`**

Replace the function resource's `code` line and add a local:

```hcl
locals {
  web_origin_id = "s3-web"

  # Every hostname the distribution answers for: the primary domain first.
  alias_hostnames = local.use_custom_domain ? concat([var.domain_name], var.redirect_hostnames) : []
}
```

```hcl
resource "aws_cloudfront_function" "web_rewrite_index" {
  name    = local.names.web_rewrite_index
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite directory paths to index.html; redirect alternate hostnames"
  publish = true
  code = templatefile("${path.module}/function/rewrite-index.js.tftpl", {
    primary_host   = coalesce(var.domain_name, "")
    redirect_hosts = jsonencode(var.redirect_hostnames)
  })
}
```

Distribution aliases: `aliases = local.alias_hostnames`.

Certificate: add `subject_alternative_names = var.redirect_hostnames` after `domain_name`.

Replace the `aws_route53_record.web` resource:

```hcl
resource "aws_route53_record" "web" {
  for_each = {
    for pair in setproduct(local.alias_hostnames, ["A", "AAAA"]) : "${pair[0]}-${pair[1]}" => {
      name = pair[0]
      type = pair[1]
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.web.domain_name
    zone_id                = aws_cloudfront_distribution.web.hosted_zone_id
    evaluate_target_health = false
  }
}
```

In `main.tf`'s header comment, change the `cloudfront.tf` line to `cloudfront.tf  distribution, headers, function (index rewrite + www redirect), optional ACM/Route 53 (web)`.

- [ ] **Step 7: Validate and commit**

```bash
terraform -chdir=infra fmt -recursive
terraform -chdir=infra/environments/prod validate
pnpm format && pnpm lint
git add infra/modules/static-site
git commit -m "feat(infra): redirect alternate hostnames to the primary domain

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `preview-site` custom hostname

**Files:**

- Modify: `infra/modules/preview-site/versions.tf`
- Modify: `infra/modules/preview-site/naming.tf`
- Modify: `infra/modules/preview-site/variables.tf`
- Modify: `infra/modules/preview-site/cloudfront.tf`
- Modify: `infra/modules/preview-site/outputs.tf`

**Interfaces:**

- Produces: variables `domain_name` (nullable), `hosted_zone_id` (nullable); provider alias requirement `aws.us_east_1`. Root (Task 4) passes both and the provider map.

- [ ] **Step 1: Provider alias in `versions.tf`**

```hcl
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # CloudFront only accepts ACM certificates from us-east-1.
      configuration_aliases = [aws.us_east_1]
    }
```

- [ ] **Step 2: Name in `naming.tf`**

Add `preview_certificate = "${local.prefix}-preview-certificate"` to the `names` map.

- [ ] **Step 3: Variables**

Insert after `rewrite_index_function_arn`:

```hcl
# -----------------------------------------------------------------------------
# Custom hostname (optional)
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Custom hostname for previews (e.g. preview.example.com). null serves them from the CloudFront domain."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "domain_name must be a lowercase fully qualified domain name."
  }
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone that owns domain_name. Required when domain_name is set."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || var.hosted_zone_id != null
    error_message = "hosted_zone_id is required when domain_name is set."
  }
}
```

- [ ] **Step 4: Certificate, aliases and records in `cloudfront.tf`**

Add to the `locals` block: `use_custom_domain = var.domain_name != null` and `preview_hostname = local.use_custom_domain ? var.domain_name : aws_cloudfront_distribution.preview.domain_name`.

In the distribution, after `wait_for_deployment`: `aliases = local.use_custom_domain ? [var.domain_name] : []`, and replace `viewer_certificate`:

```hcl
  viewer_certificate {
    cloudfront_default_certificate = local.use_custom_domain ? null : true
    acm_certificate_arn            = local.use_custom_domain ? aws_acm_certificate_validation.preview[0].certificate_arn : null
    ssl_support_method             = local.use_custom_domain ? "sni-only" : null
    minimum_protocol_version       = local.use_custom_domain ? "TLSv1.2_2021" : "TLSv1"
  }
```

Append:

```hcl
# -----------------------------------------------------------------------------
# preview: optional custom hostname. ACM certificate (us-east-1) + Route 53
# aliases. Only created when domain_name is set.
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "preview" {
  count    = local.use_custom_domain ? 1 : 0
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = merge(var.tags, { Name = local.names.preview_certificate })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "preview_acm_validation" {
  for_each = local.use_custom_domain ? {
    for dvo in aws_acm_certificate.preview[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "preview" {
  count    = local.use_custom_domain ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.preview[0].arn
  validation_record_fqdns = [for r in aws_route53_record.preview_acm_validation : r.fqdn]
}

resource "aws_route53_record" "preview" {
  for_each = local.use_custom_domain ? toset(["A", "AAAA"]) : toset([])

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = each.key

  alias {
    name                   = aws_cloudfront_distribution.preview.domain_name
    zone_id                = aws_cloudfront_distribution.preview.hosted_zone_id
    evaluate_target_health = false
  }
}
```

- [ ] **Step 5: Outputs use the hostname**

In `outputs.tf`, change both URL values to `"https://${local.preview_hostname}"` (`preview_url` and `github_environment_variables.SITE_URL`).

- [ ] **Step 6: Validate the module standalone and commit**

```bash
terraform -chdir=infra fmt -recursive
cd infra/modules/preview-site && terraform init -backend=false -input=false >/dev/null && terraform validate; rm -rf .terraform .terraform.lock.hcl; cd ../../..
git add infra/modules/preview-site
git commit -m "feat(infra): optional custom hostname for the preview distribution

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

Expected: `Success!` (validate with `-backend=false` accepts the alias requirement without a provider block).

---

### Task 4: Root wiring, phase-1 defaults, plan

**Files:**

- Modify: `infra/environments/prod/variables.tf`
- Modify: `infra/environments/prod/main.tf`
- Modify: `infra/environments/prod/outputs.tf`
- Modify: `infra/environments/prod/terraform.tfvars.example`

**Interfaces:**

- Consumes: Tasks 1–3.
- Produces: root outputs `dns_zone_id`, `dns_name_servers`; updated `site_url`, `github_environment_variables.SITE_URL`, `github_preview_environment_variables.SITE_URL`.

- [ ] **Step 1: Variables**

Replace the existing `domain_name` and `hosted_zone_id` variables in the `# Site` section with:

```hcl
# -----------------------------------------------------------------------------
# DNS and custom domain
# -----------------------------------------------------------------------------

variable "dns_zone_name" {
  description = "Domain for the Terraform-managed Route 53 hosted zone. null manages no zone; then hosted_zone_id must point at an existing one for domain_name."
  type        = string
  default     = "jwall.engineering"

  validation {
    condition     = var.dns_zone_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.dns_zone_name))
    error_message = "dns_zone_name must be a lowercase fully qualified domain name."
  }
}

variable "domain_name" {
  description = "Hostname the site is served from. null serves it from the CloudFront domain. Set only after the zone's nameservers are live at the registrar (ACM validates via DNS)."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "domain_name must be a lowercase fully qualified domain name."
  }

  validation {
    condition     = var.domain_name == null || var.dns_zone_name == null || var.domain_name == var.dns_zone_name || endswith(var.domain_name, ".${var.dns_zone_name}")
    error_message = "domain_name must be dns_zone_name or a subdomain of it."
  }
}

variable "hosted_zone_id" {
  description = "Existing Route 53 hosted zone for domain_name, used only when dns_zone_name is null."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || var.dns_zone_name != null || var.hosted_zone_id != null
    error_message = "hosted_zone_id is required when domain_name is set and dns_zone_name is null."
  }
}

variable "www_redirect" {
  description = "Redirect www.<domain_name> to domain_name. Ignored when domain_name is null."
  type        = bool
  default     = true
}

variable "preview_use_custom_domain" {
  description = "Serve PR previews from preview_domain_name instead of the CloudFront domain. Ignored when domain_name is null."
  type        = bool
  default     = true
}

variable "preview_domain_name" {
  description = "Hostname for PR previews. null derives preview.<domain_name>."
  type        = string
  default     = null

  validation {
    condition     = var.preview_domain_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.preview_domain_name))
    error_message = "preview_domain_name must be a lowercase fully qualified domain name."
  }
}

variable "dns_records" {
  description = "Extra records in the managed zone, keyed by name (\"@\" = apex, \"mail\" = mail.<zone>). See modules/dns-zone."
  type = map(object({
    type   = string
    ttl    = optional(number, 300)
    values = list(string)
  }))
  default = {}
}
```

- [ ] **Step 2: Module wiring in `main.tf`**

Before `module "site"`, add:

```hcl
# DNS: the hosted zone for the domain, plus any plain records from
# dns_records. Alias records for CloudFront are created by the site modules.
module "dns" {
  source = "../../modules/dns-zone"
  count  = var.dns_zone_name != null ? 1 : 0

  name_prefix = local.name_prefix
  zone_name   = var.dns_zone_name
  comment     = "${var.project}: managed by Terraform in ${var.repository}"
  records     = var.dns_records

  tags = local.standard_tags
}

locals {
  hosted_zone_id = var.dns_zone_name != null ? module.dns[0].zone_id : var.hosted_zone_id

  redirect_hostnames = var.domain_name != null && var.www_redirect ? ["www.${var.domain_name}"] : []

  preview_domain_name = (
    var.domain_name != null && var.preview_enabled && var.preview_use_custom_domain
    ? coalesce(var.preview_domain_name, "preview.${var.domain_name}")
    : null
  )
}
```

In `module "site"`, replace the `# Site` block:

```hcl
  # Site
  domain_name        = var.domain_name
  hosted_zone_id     = var.domain_name != null ? local.hosted_zone_id : null
  redirect_hostnames = local.redirect_hostnames
```

In `module "preview"`, add the provider map and the hostname:

```hcl
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
```

and after `rewrite_index_function_arn`:

```hcl
  # Custom hostname (null keeps the CloudFront domain)
  domain_name    = local.preview_domain_name
  hosted_zone_id = local.preview_domain_name != null ? local.hosted_zone_id : null
```

- [ ] **Step 3: Outputs**

Append to `outputs.tf`:

```hcl
# -----------------------------------------------------------------------------
# DNS. Null when dns_zone_name is null.
# -----------------------------------------------------------------------------

output "dns_zone_id" {
  description = "Hosted zone ID of the managed zone."
  value       = one(module.dns[*].zone_id)
}

output "dns_name_servers" {
  description = "Nameservers to set at the registrar for dns_zone_name."
  value       = one(module.dns[*].name_servers)
}
```

- [ ] **Step 4: tfvars example**

Replace the custom-domain comment block in `terraform.tfvars.example` with:

```hcl
# DNS and custom domain. Defaults are this project's values; the zone is
# created first, then domain_name is set once the registrar delegates to it.
# dns_zone_name             = "jwall.engineering"
# domain_name               = "jwall.engineering"
# www_redirect              = true
# preview_use_custom_domain = true
# preview_domain_name       = "preview.jwall.engineering"
# dns_records = {
#   "@"   = { type = "TXT", values = ["v=spf1 -all"] }
#   "mail" = { type = "MX", ttl = 3600, values = ["10 mx.example.net."] }
# }
# Externally managed zone instead: dns_zone_name = null, hosted_zone_id = "Z..."
```

- [ ] **Step 5: Validate and plan phase 1**

```bash
terraform -chdir=infra fmt -check -recursive
AWS_PROFILE=prog-strength-admin terraform -chdir=infra/environments/prod init -input=false >/dev/null
terraform -chdir=infra/environments/prod validate
AWS_PROFILE=prog-strength-admin terraform -chdir=infra/environments/prod plan -input=false -out=tfplan -no-color | grep -E "^  # |^Plan:|must be replaced"
```

Expected: `module.dns[0].aws_route53_zone.this will be created`, `module.site.aws_cloudfront_function.web_rewrite_index will be updated in-place` (new code with empty redirect list), `Plan: 1 to add, 1 to change, 0 to destroy.` Nothing under `module.preview` and no `must be replaced`.

- [ ] **Step 6: Commit phase 1**

```bash
git add infra/environments/prod
git commit -m "feat(infra): manage the jwall.engineering hosted zone from the prod root

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Apply phase 1 and hand off the nameserver change

**Files:** none.

- [ ] **Step 1: Apply**

```bash
AWS_PROFILE=prog-strength-admin terraform -chdir=infra/environments/prod apply -input=false tfplan
AWS_PROFILE=prog-strength-admin terraform -chdir=infra/environments/prod output -json dns_name_servers
```

Expected: `Apply complete! Resources: 1 added, 1 changed, 0 destroyed.` and four `awsdns-*` hostnames.

- [ ] **Step 2: Confirm the production site still serves unchanged**

```bash
curl -sI https://d3lcvar3pq0s6a.cloudfront.net/blog | head -1
```

Expected: `HTTP/2 200`.

- [ ] **Step 3: Push the branch and open the PR now** (title `feat(infra): serve the site from jwall.engineering`), so the plan check runs on each phase. Then **STOP** and give the owner the four nameservers for GoDaddy. Phase 2 waits for delegation.

---

### Task 6: Phase 2: attach the domain

**Files:**

- Modify: `infra/environments/prod/variables.tf` (`domain_name` default)

- [ ] **Step 1: Verify delegation**

```bash
dig +short NS jwall.engineering
```

Expected: the four Route 53 nameservers from Task 5. If GoDaddy's `domaincontrol.com` servers still show, wait and re-check; do not continue.

- [ ] **Step 2: Flip the default**

In `variables.tf`, `domain_name` default becomes `"jwall.engineering"`.

- [ ] **Step 3: Plan and apply**

```bash
AWS_PROFILE=prog-strength-admin terraform -chdir=infra/environments/prod plan -input=false -out=tfplan -no-color | grep -E "^  # |^Plan:|must be replaced"
AWS_PROFILE=prog-strength-admin terraform -chdir=infra/environments/prod apply -input=false tfplan
```

Expected plan: two `aws_acm_certificate`, their validation records and validations, `module.site.aws_route53_record.web["jwall.engineering-A"]` etc. (4 records), `module.preview[0].aws_route53_record.preview["A"/"AAAA"]`, both distributions updated in place (aliases + certificate), the function updated in place. No `must be replaced`. Apply takes 10–20 minutes (two CloudFront deployments + validation).

- [ ] **Step 4: Verify every hostname**

```bash
curl -sI https://jwall.engineering/ | head -1                              # 200
curl -sI "https://www.jwall.engineering/blog?x=1" | grep -iE '^(HTTP|location)' # 301, https://jwall.engineering/blog?x=1
curl -sI https://preview.jwall.engineering/pr-0/ | grep -iE '^(HTTP|x-robots)'  # 404 + noindex
curl -sI https://d3lcvar3pq0s6a.cloudfront.net/ | head -1                  # 200, still works
```

- [ ] **Step 5: Commit**

```bash
git add infra/environments/prod/variables.tf
git commit -m "feat(infra): attach jwall.engineering to the site and previews

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: GitHub variables, app config, redeploy

**Files:**

- Modify: `src/data/config.ts`
- Modify: `README.md`
- Modify: `.env.example`

- [ ] **Step 1: Update the GitHub environments**

```bash
REPO=jwallace145/site
gh variable set SITE_URL --env production --repo "$REPO" --body "https://jwall.engineering"
gh variable set SITE_URL --env preview    --repo "$REPO" --body "https://preview.jwall.engineering"
gh variable list --env production --repo "$REPO" | grep SITE_URL
gh variable list --env preview    --repo "$REPO" | grep SITE_URL
```

- [ ] **Step 2: App config and docs**

`src/data/config.ts`: `url: "https://jwall.engineering",` and drop the `TODO` comment above it.
`README.md`: `**Live:** <https://jwall.engineering>`.
`.env.example`: `SITE_URL=https://jwall.engineering`.

- [ ] **Step 3: Verify and commit**

```bash
pnpm format && pnpm lint && pnpm check && pnpm build && grep -c "https://jwall.engineering" dist/sitemap-0.xml
git add src/data/config.ts README.md .env.example
git commit -m "feat(site): set jwall.engineering as the canonical site url

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

Expected: sitemap count ≥ 1.

- [ ] **Step 4: Redeploy the current release so canonical/OG/sitemap carry the domain**

```bash
gh workflow run release.yml --repo jwallace145/site
gh run watch "$(gh run list --workflow=release.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
curl -s https://jwall.engineering/blog/example-post/ | grep -o '<link rel="canonical" href="[^"]*"'
```

Expected: canonical `https://jwall.engineering/blog/example-post`.

---

### Task 8: Documentation

**Files:**

- Modify: `infra/README.md`
- Modify: `docs/repo-setup.md`

- [ ] **Step 1: infra/README**

Add `modules/dns-zone/` to the tree; add name rows `Hosted zone | jwallace145-site-dns-zone (Name tag; zone name jwall.engineering)` and `ACM certificate (previews) | jwallace145-site-preview-certificate`; replace the "Adding a custom domain later" section with:

```markdown
## DNS and custom domain

`modules/dns-zone` creates the `jwall.engineering` hosted zone. The site
module attaches `domain_name` (apex) plus `www.` as a redirect, and the
preview module attaches `preview.jwall.engineering`. Certificates are
ACM/us-east-1 with DNS validation. Extra records (MX, TXT, ...) go in
`dns_records` in `terraform.tfvars`; alias records are owned by the modules.

Bringing up a new domain is two applies, because ACM validation needs the
zone to be authoritative:

1. `dns_zone_name` set, `domain_name = null`: apply, then set the four
   nameservers from `terraform output dns_name_servers` at the registrar.
2. When `dig +short NS <zone>` shows them, set `domain_name` and apply.
   Then update `SITE_URL` on the `production` and `preview` GitHub
   environments and run the Release workflow once to redeploy.

The registrar is GoDaddy; only the nameservers point at Route 53.
```

- [ ] **Step 2: repo-setup**

In section 5 and 5c, change the `SITE_URL` example bodies to `https://jwall.engineering` and `https://preview.jwall.engineering`.

- [ ] **Step 3: Commit**

```bash
pnpm format
git add infra/README.md docs/repo-setup.md
git commit -m "docs(infra): describe dns management and the two-phase domain cutover

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Finish the PR

- [ ] **Step 1:** Push; confirm all checks pass and `terraform-plan` reports `No changes.`; confirm the PR's own preview comment now points at `https://preview.jwall.engineering/pr-<n>/` and loads.
- [ ] **Step 2:** Report the PR link, the live URLs, and anything deferred.
