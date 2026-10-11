output "zone_id" {
  description = "Hosted zone ID, for alias records and ACM validation."
  value       = aws_route53_zone.this.zone_id
}

output "zone_name" {
  description = "The zone's domain name."
  value       = var.zone_name
}

output "name_servers" {
  description = "The four Route 53 nameservers to set at the registrar."
  value       = aws_route53_zone.this.name_servers
}

output "resource_names" {
  description = "Every name this module assigns."
  value       = local.names
}
