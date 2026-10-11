# Naming standard: <name_prefix>-dns-<resource>. The hosted zone's own name
# is the domain; this is its Name tag.
locals {
  prefix = var.name_prefix

  names = {
    dns_zone = "${local.prefix}-dns-zone"
  }
}
