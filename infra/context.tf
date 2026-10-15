# Identity of this stack. The registry context module derives the tag set
# that default_tags stamps on everything and the bucket name the infra repo
# created for this project (jwall-engineering-main-site).
#
# Module versions are pinned exactly, here and in main.tf, because Terraform
# records provider versions in .terraform.lock.hcl but not module versions.
# Dependabot opens bump PRs; keep both pins identical.
module "context" {
  source  = "jwallace145/jwall-engineering/aws//modules/context"
  version = "0.5.0"

  project     = "main-site"
  environment = "prod"
  repository  = "jwallace145/site"
}
