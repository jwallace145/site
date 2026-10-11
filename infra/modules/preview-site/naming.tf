# Naming standard: <name_prefix>-preview-<resource>. Every name this module
# uses is defined here so the convention lives in one place.
locals {
  prefix = var.name_prefix

  names = {
    preview_bucket           = "${local.prefix}-preview-bucket"
    preview_oac              = "${local.prefix}-preview-oac"
    preview_cdn              = "${local.prefix}-preview-cdn"
    preview_security_headers = "${local.prefix}-preview-security-headers"
    preview_github_role      = "${local.prefix}-preview-github-role"
    preview_github_policy    = "${local.prefix}-preview-github-policy"
    preview_plan_policy      = "${local.prefix}-preview-github-plan-policy"
  }
}
