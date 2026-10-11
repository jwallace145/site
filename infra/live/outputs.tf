# These map onto the GitHub `production` environment variables read by
# .github/workflows/release.yml.

output "site_bucket_name" {
  description = "S3_BUCKET"
  value       = module.site.web_bucket_name
}

output "cloudfront_distribution_id" {
  description = "CLOUDFRONT_DISTRIBUTION_ID"
  value       = module.site.web_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront hostname."
  value       = module.site.web_distribution_domain_name
}

output "deploy_role_arn" {
  description = "AWS_ROLE_ARN"
  value       = module.site.deploy_role_arn
}

output "aws_region" {
  description = "AWS_REGION"
  value       = var.aws_region
}

output "site_url" {
  description = "SITE_URL"
  value       = module.site.site_url
}

output "github_environment_variables" {
  description = "Everything to paste into the GitHub `production` environment."
  value = {
    AWS_ROLE_ARN               = module.site.deploy_role_arn
    AWS_REGION                 = var.aws_region
    S3_BUCKET                  = module.site.web_bucket_name
    CLOUDFRONT_DISTRIBUTION_ID = module.site.web_distribution_id
    SITE_URL                   = module.site.site_url
  }
}

output "resource_names" {
  description = "Every resource name the module assigns."
  value       = module.site.resource_names
}

output "standard_tags" {
  description = "Tags applied to every resource."
  value       = local.standard_tags
}
