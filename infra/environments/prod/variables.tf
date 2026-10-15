# -----------------------------------------------------------------------------
# The prod root's interface: one object per concern. The environment's values
# live in the committed terraform.tfvars next to this file; only
# environment-neutral defaults are set here. Secrets, if any ever appear, are
# declared `sensitive = true` with no default and passed at plan/apply time
# via TF_VAR_<name> or -var.
# -----------------------------------------------------------------------------

variable "identity" {
  description = <<-EOT
    Who owns this stack. Drives resource names and the standard tags.
      project      name prefix and Project tag, e.g. jwall-engineering-site
      owner        Owner tag
      environment  Environment tag, e.g. prod
      repository   Repository tag: where the IaC lives
      extra_tags   merged onto the standard set
  EOT
  type = object({
    project     = string
    owner       = string
    environment = string
    repository  = string
    extra_tags  = optional(map(string), {})
  })

  validation {
    # 36 leaves room for the longest suffix any module appends (IAM role names
    # are capped at 64 characters, bucket names at 63).
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,35}$", var.identity.project))
    error_message = "identity.project must be lowercase letters, digits and hyphens, 2-36 characters (it prefixes every resource name)."
  }
}

variable "aws" {
  description = "AWS settings. region: for the buckets and IAM; CloudFront/ACM are global/us-east-1 regardless."
  type = object({
    region = optional(string, "us-east-1")
  })
  default = {}

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws.region))
    error_message = "aws.region must look like us-east-1."
  }
}

variable "dns" {
  description = <<-EOT
    The Route 53 hosted zone the site's records live in. The zone itself is
    owned by jwallace145/jwall-engineering-infra (`terraform output
    hosted_zone_id` there); this stack only creates alias and ACM validation
    records in it through the site modules.
      hosted_zone_id  ID of the existing zone
  EOT
  type = object({
    hosted_zone_id = string
  })

  validation {
    condition     = can(regex("^Z[A-Z0-9]{5,31}$", var.dns.hosted_zone_id))
    error_message = "dns.hosted_zone_id must be a Route 53 hosted zone ID (e.g. Z0123456789ABCDEFGHIJ)."
  }
}

variable "domain" {
  description = <<-EOT
    The hostname the site is served from. Leave name null to serve from the
    CloudFront domain (ACM validates via DNS in the zone).
      name          e.g. example.com; must be in the zone dns.hosted_zone_id refers to
      www_redirect  301-redirect www.<name> to name
  EOT
  type = object({
    name         = optional(string)
    www_redirect = optional(bool, true)
  })
  default = {}

  validation {
    condition     = var.domain.name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain.name))
    error_message = "domain.name must be a lowercase fully qualified domain name."
  }
}

variable "site" {
  description = "Production distribution options. price_class: CloudFront price class. error_caching_min_ttl: seconds the 404 page is cached."
  type = object({
    price_class           = optional(string, "PriceClass_100")
    error_caching_min_ttl = optional(number, 60)
  })
  default = {}

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.site.price_class)
    error_message = "site.price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "github" {
  description = <<-EOT
    The GitHub repository that deploys this stack through Actions OIDC.
      repository            owner/name
      owner_id              numeric owner ID (gh api users/<owner> --jq .id); with
                            repository_id enables the immutable OIDC subject
      repository_id         numeric repository ID (gh api repos/<owner>/<name> --jq .id)
      environment           GitHub Environment whose jobs may deploy production
      create_oidc_provider  create the OIDC provider; false looks up the account's existing one
  EOT
  type = object({
    repository           = string
    owner_id             = optional(number)
    repository_id        = optional(number)
    environment          = optional(string, "production")
    create_oidc_provider = optional(bool, true)
  })

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github.repository))
    error_message = "github.repository must be in owner/name form."
  }

  validation {
    condition     = (var.github.owner_id == null) == (var.github.repository_id == null)
    error_message = "github.owner_id and github.repository_id must be set together."
  }
}

variable "preview" {
  description = <<-EOT
    Pull-request previews (one bucket + distribution shared by every open PR).
      enabled                 create the preview stack; false removes it
      github_environment      GitHub Environment whose jobs may publish previews
      key_prefix              S3 key prefix per PR; the PR number is appended (pr- => pr-9/)
      retention_days          objects expire after this many days (safety net)
      price_class             CloudFront price class
      error_caching_min_ttl   seconds the 404 page is cached
      robots_tag              X-Robots-Tag on every preview response
      extra_response_headers  additional response headers (name => value)
      use_custom_domain       serve from domain_name instead of the CloudFront domain
                              (needs domain.name)
      domain_name             hostname for previews; null derives preview.<domain.name>
  EOT
  type = object({
    enabled                = optional(bool, true)
    github_environment     = optional(string, "preview")
    key_prefix             = optional(string, "pr-")
    retention_days         = optional(number, 30)
    price_class            = optional(string, "PriceClass_100")
    error_caching_min_ttl  = optional(number, 60)
    robots_tag             = optional(string, "noindex, nofollow")
    extra_response_headers = optional(map(string), {})
    use_custom_domain      = optional(bool, true)
    domain_name            = optional(string)
  })
  default = {}

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.preview.github_environment))
    error_message = "preview.github_environment must contain only letters, digits, '_', '.' and '-'."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.preview.key_prefix))
    error_message = "preview.key_prefix must be non-empty and contain only letters, digits, _ and - (no slashes)."
  }

  validation {
    condition     = var.preview.retention_days == floor(var.preview.retention_days) && var.preview.retention_days >= 1 && var.preview.retention_days <= 365
    error_message = "preview.retention_days must be a whole number between 1 and 365."
  }

  validation {
    condition     = var.preview.domain_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.preview.domain_name))
    error_message = "preview.domain_name must be a lowercase fully qualified domain name."
  }
}

variable "billing" {
  description = "Monthly cost budget. alert_email receives alerts at 80% actual and 100% forecasted; monthly_budget_usd is the limit."
  type = object({
    alert_email        = string
    monthly_budget_usd = optional(number, 5)
  })

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.billing.alert_email))
    error_message = "billing.alert_email must be a valid email address."
  }
}
