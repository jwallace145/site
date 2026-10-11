variable "name_prefix" {
  description = "Prefix for resource Name tags, e.g. jwallace145-site."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits and hyphens, 2-25 characters."
  }
}

variable "zone_name" {
  description = "Domain the hosted zone is authoritative for, e.g. example.com. Lowercase, no trailing dot."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.zone_name))
    error_message = "zone_name must be a lowercase fully qualified domain name without a trailing dot."
  }
}

variable "comment" {
  description = "Hosted zone comment shown in the Route 53 console."
  type        = string
  default     = "Managed by Terraform"
}

variable "records" {
  description = <<-EOT
    DNS records to create in the zone, keyed by record name: "@" is the apex,
    "mail" becomes mail.<zone_name>, and a name already ending in the zone
    name is used as is. CloudFront alias records are owned by the site
    modules, not this map.
  EOT
  type = map(object({
    type   = string
    ttl    = optional(number, 300)
    values = list(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.records) : contains(["A", "AAAA", "CNAME", "MX", "TXT", "SRV", "CAA", "NS"], r.type)])
    error_message = "records[*].type must be one of A, AAAA, CNAME, MX, TXT, SRV, CAA, NS."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : r.ttl >= 60 && r.ttl <= 86400])
    error_message = "records[*].ttl must be between 60 and 86400 seconds."
  }

  validation {
    condition     = alltrue([for r in values(var.records) : length(r.values) > 0])
    error_message = "records[*].values must contain at least one value."
  }

  validation {
    condition     = alltrue([for k in keys(var.records) : can(regex("^(@|[a-z0-9_]([a-z0-9_.-]*[a-z0-9_])?)$", k))])
    error_message = "records keys must be \"@\" or a lowercase hostname (letters, digits, '_', '-', '.')."
  }
}

variable "tags" {
  description = "Tags merged onto every taggable resource. The module adds Name."
  type        = map(string)
  default     = {}
}
