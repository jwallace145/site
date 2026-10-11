variable "name_prefix" {
  description = "Prefix for resource Name tags, e.g. jwallace145-site."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits and hyphens, 2-25 characters."
  }
}

variable "zone" {
  description = <<-EOT
    The hosted zone.
      name     domain the zone is authoritative for (lowercase, no trailing dot)
      comment  shown in the Route 53 console
      records  plain records keyed by name: "@" is the apex, "mail" becomes
               mail.<name>, a key already ending in <name> is used as is.
               CloudFront alias records are owned by the site modules.
  EOT
  type = object({
    name    = string
    comment = optional(string, "Managed by Terraform")
    records = optional(map(object({
      type   = string
      ttl    = optional(number, 300)
      values = list(string)
    })), {})
  })

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.zone.name))
    error_message = "zone.name must be a lowercase fully qualified domain name without a trailing dot."
  }

  validation {
    condition     = alltrue([for r in values(var.zone.records) : contains(["A", "AAAA", "CNAME", "MX", "TXT", "SRV", "CAA", "NS"], r.type)])
    error_message = "zone.records[*].type must be one of A, AAAA, CNAME, MX, TXT, SRV, CAA, NS."
  }

  validation {
    condition     = alltrue([for r in values(var.zone.records) : r.ttl >= 60 && r.ttl <= 86400])
    error_message = "zone.records[*].ttl must be between 60 and 86400 seconds."
  }

  validation {
    condition     = alltrue([for r in values(var.zone.records) : length(r.values) > 0])
    error_message = "zone.records[*].values must contain at least one value."
  }

  validation {
    condition     = alltrue([for k in keys(var.zone.records) : can(regex("^(@|[a-z0-9_]([a-z0-9_.-]*[a-z0-9_])?)$", k))])
    error_message = "zone.records keys must be \"@\" or a lowercase hostname (letters, digits, '_', '-', '.')."
  }
}

variable "tags" {
  description = "Tags merged onto every taggable resource. The module adds Name."
  type        = map(string)
  default     = {}
}
