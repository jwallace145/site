# Root for the jwallace145-site `prod` environment.
#
# This file is intentionally thin: standards (names and tags) are computed
# here from a handful of variables and handed to the static-site module. Other environments (dev, staging) would be
# sibling directories under infra/environments/ with their own state key.

locals {
  name_prefix = var.project

  standard_tags = merge(
    {
      Project     = var.project
      Owner       = var.owner
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = var.repository
    },
    var.extra_tags,
  )
}

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

module "site" {
  source = "../../modules/static-site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix

  # Site
  domain_name        = var.domain_name
  hosted_zone_id     = var.domain_name != null ? local.hosted_zone_id : null
  redirect_hostnames = local.redirect_hostnames

  # Deploy identity
  github_repository    = var.github_repository
  github_owner_id      = var.github_owner_id
  github_repository_id = var.github_repository_id
  github_environment   = var.github_environment
  create_oidc_provider = var.create_oidc_provider

  # Read-only plan role for pull requests
  plan_role              = true
  terraform_state_bucket = local.terraform_state.bucket
  terraform_state_key    = local.terraform_state.key

  # Billing
  budget_alert_email = var.budget_alert_email
  monthly_budget_usd = var.monthly_budget_usd

  # default_tags already cover these; passing them too keeps the module
  # self-contained if it is ever used without default_tags.
  tags = local.standard_tags
}

# PR previews: one bucket + distribution shared by every open PR, each under
# its own key prefix. Switched off entirely with preview_enabled = false.
module "preview" {
  source = "../../modules/preview-site"
  count  = var.preview_enabled ? 1 : 0

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix

  # Previews
  key_prefix                 = var.preview_key_prefix
  retention_days             = var.preview_retention_days
  price_class                = var.preview_price_class
  robots_tag                 = var.preview_robots_tag
  extra_response_headers     = var.preview_extra_response_headers
  rewrite_index_function_arn = module.site.web_rewrite_index_function_arn

  # Custom hostname (null keeps the CloudFront domain)
  domain_name    = local.preview_domain_name
  hosted_zone_id = local.preview_domain_name != null ? local.hosted_zone_id : null

  # Deploy identity
  oidc_provider_arn    = module.site.oidc_provider_arn
  github_repository    = var.github_repository
  github_owner_id      = var.github_owner_id
  github_repository_id = var.github_repository_id
  github_environment   = var.preview_github_environment
  plan_role_name       = module.site.plan_role_name

  tags = local.standard_tags
}
