output "bucket_name" {
  description = "Site bucket the deploy and preview workflows sync into."
  value       = module.context.bucket_name
}

output "prod_url" {
  description = "Production URL."
  value       = module.site.prod_url
}

output "prod_distribution_id" {
  description = "Production CloudFront distribution ID; the deploy workflow invalidates it."
  value       = module.site.prod_distribution_id
}
