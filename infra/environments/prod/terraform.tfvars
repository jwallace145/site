# The `prod` environment. Terraform loads this file automatically, locally and
# in the PR plan check, so it is the single description of what prod should
# be. Nothing here is secret. A sensitive input, should one ever exist, is
# declared `sensitive = true` in variables.tf with no default and supplied at
# plan/apply time with TF_VAR_<name> or -var.

identity = {
  project     = "jwall-engineering-site"
  owner       = "jwallace145"
  environment = "prod"
  repository  = "github.com/jwallace145/site"
}

aws = {
  region = "us-east-1"
}

# The jwall.engineering zone is owned by jwallace145/jwall-engineering-infra
# (`terraform output hosted_zone_id` there). Records for other projects live
# in their own repos.
dns = {
  hosted_zone_id = "Z029546536VUFGDCPXZ21"
}

domain = {
  name         = "jwall.engineering"
  www_redirect = true
}

site = {
  price_class = "PriceClass_100"
}

github = {
  repository           = "jwallace145/site"
  owner_id             = 35950238
  repository_id        = 1413965497
  environment          = "production"
  create_oidc_provider = false # the account already has one
}

preview = {
  enabled            = true
  github_environment = "preview"
  key_prefix         = "pr-"
  retention_days     = 30
  price_class        = "PriceClass_100"
  robots_tag         = "noindex, nofollow"
  use_custom_domain  = true
  domain_name        = null # derives preview.<domain.name>
}

billing = {
  alert_email        = "jimmy.wallace145@gmail.com"
  monthly_budget_usd = 5
}
