# Live root for the jwallace145-site production stack.
#
# This file is intentionally thin: standards (names and tags) are computed
# here from a handful of variables and handed to the static-site module.

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

module "site" {
  source = "../modules/static-site"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix

  # Site
  domain_name    = var.domain_name
  hosted_zone_id = var.hosted_zone_id

  # Deploy identity
  github_repository    = var.github_repository
  github_environment   = var.github_environment
  create_oidc_provider = var.create_oidc_provider

  # Billing
  budget_alert_email = var.budget_alert_email
  monthly_budget_usd = var.monthly_budget_usd

  # default_tags already cover these; passing them too keeps the module
  # self-contained if it is ever used without default_tags.
  tags = local.standard_tags
}
