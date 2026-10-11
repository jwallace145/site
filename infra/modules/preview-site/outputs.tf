output "preview_bucket_name" {
  description = "Name of the preview bucket."
  value       = aws_s3_bucket.preview.id
}

output "preview_bucket_arn" {
  description = "ARN of the preview bucket."
  value       = aws_s3_bucket.preview.arn
}

output "preview_distribution_id" {
  description = "ID of the preview CloudFront distribution."
  value       = aws_cloudfront_distribution.preview.id
}

output "preview_distribution_arn" {
  description = "ARN of the preview CloudFront distribution."
  value       = aws_cloudfront_distribution.preview.arn
}

output "preview_distribution_domain_name" {
  description = "CloudFront hostname of the preview distribution."
  value       = aws_cloudfront_distribution.preview.domain_name
}

output "preview_role_arn" {
  description = "ARN of the IAM role the preview workflow assumes via OIDC."
  value       = aws_iam_role.preview.arn
}

output "preview_url" {
  description = "Base URL previews are served from (custom hostname if set). A PR lives at <preview_url>/<key_prefix><number>/."
  value       = "https://${local.preview_hostname}"
}

output "key_prefix" {
  description = "Key prefix the workflow must write under; it appends the PR number and a slash."
  value       = var.previews.key_prefix
}

output "resource_names" {
  description = "Every name this module assigns, for reference and audits."
  value       = local.names
}

output "github_environment_variables" {
  description = "Variables for the GitHub Environment named in github_environment."
  value = {
    AWS_ROLE_ARN               = aws_iam_role.preview.arn
    S3_BUCKET                  = aws_s3_bucket.preview.id
    CLOUDFRONT_DISTRIBUTION_ID = aws_cloudfront_distribution.preview.id
    SITE_URL                   = "https://${local.preview_hostname}"
    PREVIEW_KEY_PREFIX         = var.previews.key_prefix
  }
}
