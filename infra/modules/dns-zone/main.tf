# dns-zone module
#
# One public Route 53 hosted zone plus any plain records the caller lists.
# Alias records that point at CloudFront are created by the site modules,
# which know the distribution; this module only owns the zone and generic
# records (MX, TXT, CNAME, ...).

resource "aws_route53_zone" "this" {
  name    = var.zone.name
  comment = var.zone.comment

  tags = merge(var.tags, { Name = local.names.dns_zone })
}

locals {
  # "@" -> zone apex; "mail" -> mail.<zone>; "x.<zone>" -> unchanged.
  record_fqdns = {
    for key, r in var.zone.records : key => (
      key == "@" ? var.zone.name :
      endswith(key, var.zone.name) ? key :
      "${key}.${var.zone.name}"
    )
  }
}

resource "aws_route53_record" "this" {
  for_each = var.zone.records

  zone_id = aws_route53_zone.this.zone_id
  name    = local.record_fqdns[each.key]
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.values
}
