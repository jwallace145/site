# The `prod` environment. Terraform loads this file automatically, locally and
# in the PR plan check, so it is the single description of what prod should
# be. Nothing here is secret. A sensitive input, should one ever exist, is
# declared `sensitive = true` in variables.tf with no default and supplied at
# plan/apply time with TF_VAR_<name> or -var.

# Identity and tags
project     = "jwallace145-site"
owner       = "jwallace145"
environment = "prod"
repository  = "github.com/jwallace145/site"

# AWS
aws_region = "us-east-1"

# DNS and custom domain. Two-phase: the zone first, domain_name once the
# registrar delegates to it (see infra/README.md).
dns_zone_name = "jwall.engineering"
domain_name   = null
www_redirect  = true
dns_records   = {}

# Deploy identity (GitHub Actions OIDC)
github_repository    = "jwallace145/site"
github_owner_id      = 35950238
github_repository_id = 1413965497
github_environment   = "production"
create_oidc_provider = false # the account already has one

# PR previews
preview_enabled            = true
preview_github_environment = "preview"
preview_key_prefix         = "pr-"
preview_retention_days     = 30
preview_price_class        = "PriceClass_100"
preview_robots_tag         = "noindex, nofollow"
preview_use_custom_domain  = true
preview_domain_name        = null # derives preview.<domain_name>

# Billing
budget_alert_email = "jimmy.wallace145@gmail.com"
monthly_budget_usd = 5
