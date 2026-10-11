# Naming standard: <name_prefix>-<domain>-<resource>
#   domain  = logical area of the system: web, deploy, billing
#   resource = what the thing is
# Every name used by this module is defined here so the convention lives in
# one place.
locals {
  prefix = var.name_prefix

  names = {
    # web: everything that serves the site
    web_bucket           = "${local.prefix}-web-bucket"
    web_oac              = "${local.prefix}-web-oac"
    web_cdn              = "${local.prefix}-web-cdn"
    web_security_headers = "${local.prefix}-web-security-headers"
    web_rewrite_index    = "${local.prefix}-web-rewrite-index"
    web_certificate      = "${local.prefix}-web-certificate"

    # deploy: CI/CD identity
    deploy_github_role   = "${local.prefix}-deploy-github-role"
    deploy_github_policy = "${local.prefix}-deploy-github-policy"
    deploy_oidc_provider = "${local.prefix}-deploy-github-oidc"

    # billing
    billing_monthly = "${local.prefix}-billing-monthly"
  }

  use_custom_domain = var.domain_name != null
}
