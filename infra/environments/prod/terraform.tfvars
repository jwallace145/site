# The `prod` environment. Terraform loads this file automatically, locally and
# in the PR plan check, so it is the single description of what prod should
# be. Nothing here is secret. A sensitive input, should one ever exist, is
# declared `sensitive = true` in variables.tf with no default and supplied at
# plan/apply time with TF_VAR_<name> or -var.

identity = {
  project     = "jwallace145-site"
  owner       = "jwallace145"
  environment = "prod"
  repository  = "github.com/jwallace145/site"
}

aws = {
  region = "us-east-1"
}

# Two-phase: the zone first, domain.name once the registrar delegates to it
# (see infra/README.md).
dns = {
  zone_name = "jwall.engineering"
  records = {
    # CS Survival Guide, hosted on GitHub Pages from jwallace145/cs-survival-guide.
    "survival-guide" = { type = "CNAME", values = ["jwallace145.github.io."] }
    # GitHub Pages verified domain for the jwallace145 account: proves ownership
    # of jwall.engineering so no other account can publish Pages on its subdomains.
    "_github-pages-challenge-jwallace145" = { type = "TXT", values = ["278aa0fd98189307922e6679ba36f1"] }
  }
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
