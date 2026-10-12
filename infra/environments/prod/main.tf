# Root for the jwall-engineering-site `prod` environment.
#
# This file is intentionally thin: standards (names and tags) are computed
# here from the identity object and handed to the modules as grouped
# objects. Other environments (dev, staging) would be sibling directories
# under infra/environments/ with their own terraform.tfvars and state key.

locals {
  name_prefix = var.identity.project

  standard_tags = merge(
    {
      Project     = var.identity.project
      Owner       = var.identity.owner
      Environment = var.identity.environment
      ManagedBy   = "terraform"
      Repository  = var.identity.repository
    },
    var.identity.extra_tags,
  )
}

# DNS: the hosted zone for the domain, plus any plain records. Alias records
# for CloudFront are created by the site modules.
module "dns" {
  source = "../../modules/dns-zone"
  count  = var.dns.zone_name != null ? 1 : 0

  name_prefix = local.name_prefix

  zone = {
    name    = var.dns.zone_name
    comment = "${var.identity.project}: managed by Terraform in ${var.identity.repository}"
    records = var.dns.records
  }

  tags = local.standard_tags
}

locals {
  hosted_zone_id = var.dns.zone_name != null ? module.dns[0].zone_id : var.dns.hosted_zone_id

  redirect_hostnames = var.domain.name != null && var.domain.www_redirect ? ["www.${var.domain.name}"] : []

  preview_domain_name = (
    var.domain.name != null && var.preview.enabled && var.preview.use_custom_domain
    ? coalesce(var.preview.domain_name, "preview.${var.domain.name}")
    : null
  )
}

module "site" {
  source = "../../modules/static-site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix

  site = {
    domain_name           = var.domain.name
    hosted_zone_id        = var.domain.name != null ? local.hosted_zone_id : null
    redirect_hostnames    = local.redirect_hostnames
    price_class           = var.site.price_class
    error_caching_min_ttl = var.site.error_caching_min_ttl
  }

  github = var.github

  # Read-only plan role for pull requests
  plan = {
    enabled      = true
    state_bucket = local.terraform_state.bucket
    state_key    = local.terraform_state.key
  }

  billing = var.billing

  # default_tags already cover these; passing them too keeps the module
  # self-contained if it is ever used without default_tags.
  tags = local.standard_tags
}

# PR previews: one bucket + distribution shared by every open PR, each under
# its own key prefix. Switched off entirely with preview.enabled = false.
module "preview" {
  source = "../../modules/preview-site"
  count  = var.preview.enabled ? 1 : 0

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix

  previews = {
    key_prefix             = var.preview.key_prefix
    retention_days         = var.preview.retention_days
    price_class            = var.preview.price_class
    error_caching_min_ttl  = var.preview.error_caching_min_ttl
    robots_tag             = var.preview.robots_tag
    extra_response_headers = var.preview.extra_response_headers
  }

  # Custom hostname (null keeps the CloudFront domain)
  domain = {
    name           = local.preview_domain_name
    hosted_zone_id = local.preview_domain_name != null ? local.hosted_zone_id : null
  }

  github = {
    repository    = var.github.repository
    owner_id      = var.github.owner_id
    repository_id = var.github.repository_id
    environment   = var.preview.github_environment
  }

  shared = {
    oidc_provider_arn          = module.site.oidc_provider_arn
    rewrite_index_function_arn = module.site.web_rewrite_index_function_arn
    plan_role_name             = module.site.plan_role_name
  }

  tags = local.standard_tags
}
