# These map directly onto the GitHub `production` environment variables read
# by .github/workflows/release.yml.

output "site_bucket_name" {
  description = "S3_BUCKET: name of the site bucket."
  value       = aws_s3_bucket.site.id
}

output "cloudfront_distribution_id" {
  description = "CLOUDFRONT_DISTRIBUTION_ID: ID of the site distribution."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "deploy_role_arn" {
  description = "AWS_ROLE_ARN: IAM role assumed by GitHub Actions via OIDC."
  value       = aws_iam_role.deploy.arn
}

output "aws_region" {
  description = "AWS_REGION: region of the site bucket."
  value       = var.aws_region
}

output "site_url" {
  description = "SITE_URL: public URL of the site."
  value       = local.use_custom_domain ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "github_environment_variables" {
  description = "Everything to paste into the GitHub `production` environment, in one place."
  value = {
    AWS_ROLE_ARN               = aws_iam_role.deploy.arn
    AWS_REGION                 = var.aws_region
    S3_BUCKET                  = aws_s3_bucket.site.id
    CLOUDFRONT_DISTRIBUTION_ID = aws_cloudfront_distribution.site.id
    SITE_URL                   = local.use_custom_domain ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.site.domain_name}"
  }
}
