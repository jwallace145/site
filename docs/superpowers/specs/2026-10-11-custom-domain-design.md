# Custom domain: jwall.engineering

**Date:** 2026-10-11
**Status:** approved design, pending implementation plan

## Goal

Serve the site at `https://jwall.engineering`, redirect `www.jwall.engineering`
to it, serve PR previews at `https://preview.jwall.engineering/pr-<n>/`, and
manage every DNS record for the domain from this repository with Terraform
and Route 53. The registration stays at GoDaddy; only the nameservers move.

## Constraints and decisions

- **DNS lives in Route 53**, in a hosted zone created by Terraform. GoDaddy
  keeps the registration and delegates to the Route 53 nameservers. A
  registrar transfer is optional and out of scope.
- **Two-phase cutover.** ACM DNS validation only succeeds once the zone is
  authoritative, so the zone is created and delegated first, and the site is
  attached second. Each phase is a commit whose root defaults describe the
  intended live state, so the PR `terraform-plan` check always compares the
  committed state to prod.
- **Project values are root defaults.** `terraform.tfvars` is git-ignored and
  CI plans with defaults, so the domain, the zone name and the www redirect
  live in `environments/prod/variables.tf` defaults, overridable from tfvars.
- **Terraform interface:** every variable has a description, type, default
  where sensible, and a validation where the value has a shape. No module
  hard-codes a hostname.
- **www is a redirect, not a second host.** One canonical origin for search
  engines. The redirect runs in the existing CloudFront function.
- **Apply:** the owner's `AWS_PROFILE=prog-strength-admin` applies; CI plans.

## 1. `dns-zone` module (`infra/modules/dns-zone`)

| File           | Contents                                  |
| -------------- | ----------------------------------------- |
| `naming.tf`    | `<name_prefix>-dns-zone` Name tag         |
| `main.tf`      | `aws_route53_zone`, `aws_route53_record`s |
| `variables.tf` | interface below                           |
| `outputs.tf`   | `zone_id`, `zone_name`, `name_servers`    |
| `versions.tf`  | provider requirements                     |

Variables:

| Variable      | Type                                                                                 | Default                  | Validation                                                            |
| ------------- | ------------------------------------------------------------------------------------ | ------------------------ | --------------------------------------------------------------------- |
| `name_prefix` | string                                                                               | required                 | `^[a-z0-9][a-z0-9-]{1,24}$`                                           |
| `zone_name`   | string                                                                               | required                 | FQDN, lowercase, no trailing dot                                      |
| `comment`     | string                                                                               | `"Managed by Terraform"` | none                                                                  |
| `records`     | `map(object({ type = string, ttl = optional(number, 300), values = list(string) }))` | `{}`                     | type in A, AAAA, CNAME, MX, TXT, SRV, CAA, NS; ttl 60–86400; ≥1 value |
| `tags`        | map(string)                                                                          | `{}`                     | none                                                                  |

`records` is keyed by record name: `"@"` is the apex, `"mail"` becomes
`mail.<zone>`, and a name already ending in the zone name is used as is.
Alias records for CloudFront are not part of this map; the site modules own
those.

## 2. `static-site` module changes

- New variable `redirect_hostnames` (`list(string)`, default `[]`, each an
  FQDN; requires `domain_name`). Each hostname is:
  - a subject alternative name on the ACM certificate (validation records
    already iterate `domain_validation_options`);
  - an alias on the distribution;
  - an A and AAAA alias record in the hosted zone.
- The CloudFront function becomes a template
  (`function/rewrite-index.js.tftpl`) rendered with the primary host and the
  redirect list. A request whose `Host` is in the list gets a 301 to
  `https://<domain_name><uri><query>`; everything else is the existing
  index rewrite. The function is still shared with the preview
  distribution; preview hostnames never match the list.
- The function logic is unit-tested with Vitest by rendering the template
  with test values.

## 3. `preview-site` module changes

- New variables `domain_name` (nullable FQDN) and `hosted_zone_id`
  (required when `domain_name` is set), mirroring `static-site`.
- When set: ACM certificate in us-east-1 with DNS validation records, the
  hostname as a distribution alias, A/AAAA alias records. The module now
  requires the `aws.us_east_1` provider alias.
- `preview_url` and `github_environment_variables.SITE_URL` use the custom
  hostname when set.
- New name: `<prefix>-preview-certificate`.

## 4. Root changes (`infra/environments/prod`)

Variables (all with validation; defaults are this project's values):

| Variable                    | Default                                           | Notes                                                    |
| --------------------------- | ------------------------------------------------- | -------------------------------------------------------- |
| `dns_zone_name`             | `"jwall.engineering"`                             | null skips the zone; then `hosted_zone_id` must be given |
| `domain_name`               | null in phase 1, `"jwall.engineering"` in phase 2 | must equal or be under `dns_zone_name`                   |
| `hosted_zone_id`            | null                                              | only for an externally managed zone                      |
| `www_redirect`              | `true`                                            | adds `www.<domain_name>` to `redirect_hostnames`         |
| `preview_use_custom_domain` | `true`                                            | previews at `preview_domain_name` when `domain_name` set |
| `preview_domain_name`       | null → `preview.<domain_name>`                    | FQDN                                                     |
| `dns_records`               | `{}`                                              | same type as the module's `records`                      |

- `module "dns"` with `count = var.dns_zone_name != null ? 1 : 0`.
- `local.hosted_zone_id` = the managed zone's ID, else `var.hosted_zone_id`.
- `module.site` receives `domain_name`, `hosted_zone_id`,
  `redirect_hostnames`; `module.preview` receives `domain_name` and
  `hosted_zone_id` and the `aws.us_east_1` provider.
- Outputs: `dns_zone_id`, `dns_name_servers`, and the existing
  `site_url` / `github_*_environment_variables` reflect the custom hostnames.

## 5. Application and GitHub

After phase 2:

- `src/data/config.ts`: `site.url = "https://jwall.engineering"`.
- README "Live" line.
- GitHub `production` environment `SITE_URL` → `https://jwall.engineering`;
  `preview` environment `SITE_URL` → `https://preview.jwall.engineering`.
- One manual run of the Release workflow redeploys the current release so
  canonical URLs, Open Graph URLs and the sitemap use the domain.

## 6. Rollout

1. **Phase 1 commit:** modules, root wiring, `dns_zone_name` default set,
   `domain_name` default null. Apply: zone (+ any `dns_records`) only.
2. **Owner:** at GoDaddy, replace the nameservers with the four from
   `terraform output dns_name_servers`. Wait until
   `dig +short NS jwall.engineering` returns them.
3. **Phase 2 commit:** `domain_name` default `"jwall.engineering"`. Apply:
   two certificates, validation records, aliases, A/AAAA records. Verify
   `curl -sI https://jwall.engineering`, `https://www.jwall.engineering`
   (301 to apex) and `https://preview.jwall.engineering/pr-0/` (404 page).
4. GitHub variables, config, README; manual Release run; verify canonical.
5. One PR containing both commits, opened after phase 1 so the plan check
   is meaningful at each push.

## Out of scope

- Transferring the registration to Route 53.
- Email hosting (records can be added via `dns_records` at any time).
- DNSSEC.
