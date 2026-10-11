output "web_bucket_name" {
  description = "Name of the site bucket."
  value       = aws_s3_bucket.web.id
}

output "web_bucket_arn" {
  description = "ARN of the site bucket."
  value       = aws_s3_bucket.web.arn
}

output "web_distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.web.id
}

output "web_distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.web.arn
}

output "web_distribution_domain_name" {
  description = "CloudFront hostname of the distribution."
  value       = aws_cloudfront_distribution.web.domain_name
}

output "deploy_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC."
  value       = aws_iam_role.deploy.arn
}

output "plan_role_arn" {
  description = "ARN of the read-only role pull_request workflows assume for terraform plan. null when plan_role is false."
  value       = var.plan.enabled ? aws_iam_role.plan[0].arn : null
}

output "site_url" {
  description = "Public URL of the site: the custom domain if set, else the CloudFront domain."
  value       = local.use_custom_domain ? "https://${var.site.domain_name}" : "https://${aws_cloudfront_distribution.web.domain_name}"
}

output "resource_names" {
  description = "Every name this module assigns, for reference and audits."
  value       = local.names
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider the roles trust (created or looked up)."
  value       = local.oidc_provider_arn
}

output "web_rewrite_index_function_arn" {
  description = "ARN of the CloudFront Function that maps directory paths to index.html. Reusable by other distributions."
  value       = aws_cloudfront_function.web_rewrite_index.arn
}

output "plan_role_name" {
  description = "Name of the read-only plan role, for attaching extra read policies. null when plan_role is false."
  value       = var.plan.enabled ? aws_iam_role.plan[0].name : null
}
