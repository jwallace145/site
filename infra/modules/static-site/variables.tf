# -----------------------------------------------------------------------------
# Identity and naming
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jwall-engineering-site. Names become <name_prefix>-<domain>-<resource>."
  type        = string

  validation {
    # The longest name this module builds is <prefix>-deploy-github-plan-role;
    # IAM caps role names at 64 characters and S3 caps bucket names at 63.
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,35}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits and hyphens, 2-36 characters."
  }
}

# -----------------------------------------------------------------------------
# Site: how the distribution serves
# -----------------------------------------------------------------------------

variable "site" {
  description = <<-EOT
    Serving options.
      domain_name            custom hostname (null serves from the CloudFront domain)
      hosted_zone_id         Route 53 zone owning domain_name; required with it
      redirect_hostnames     hostnames 301-redirected to domain_name (e.g. www.<domain>);
                             added to the certificate, the aliases and the zone
      price_class            CloudFront price class
      error_caching_min_ttl  seconds CloudFront caches the 404 page
  EOT
  type = object({
    domain_name           = optional(string)
    hosted_zone_id        = optional(string)
    redirect_hostnames    = optional(list(string), [])
    price_class           = optional(string, "PriceClass_100")
    error_caching_min_ttl = optional(number, 60)
  })
  default = {}

  validation {
    condition     = var.site.domain_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.site.domain_name))
    error_message = "site.domain_name must be a lowercase fully qualified domain name."
  }

  validation {
    condition     = var.site.domain_name == null || var.site.hosted_zone_id != null
    error_message = "site.hosted_zone_id is required when site.domain_name is set."
  }

  validation {
    condition     = alltrue([for h in var.site.redirect_hostnames : can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", h))])
    error_message = "site.redirect_hostnames must be lowercase fully qualified domain names."
  }

  validation {
    condition     = length(var.site.redirect_hostnames) == 0 || var.site.domain_name != null
    error_message = "site.redirect_hostnames requires site.domain_name."
  }

  validation {
    condition     = !contains(var.site.redirect_hostnames, coalesce(var.site.domain_name, "-"))
    error_message = "site.redirect_hostnames must not contain site.domain_name itself."
  }

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.site.price_class)
    error_message = "site.price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }

  validation {
    condition     = var.site.error_caching_min_ttl >= 0 && var.site.error_caching_min_ttl <= 86400
    error_message = "site.error_caching_min_ttl must be between 0 and 86400 seconds."
  }
}

# -----------------------------------------------------------------------------
# GitHub: deploy identity (Actions OIDC)
# -----------------------------------------------------------------------------

variable "github" {
  description = <<-EOT
    GitHub repository whose workflows may deploy.
      repository            owner/name
      owner_id              numeric owner ID; with repository_id enables GitHub's immutable
                            OIDC subject (repo:owner@id/name@id:...). null = plain subject only
      repository_id         numeric repository ID (set together with owner_id)
      environment           GitHub Environment whose jobs may assume the deploy role
      create_oidc_provider  create the token.actions.githubusercontent.com provider;
                            false looks up the account's existing one (one per account)
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

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github.environment))
    error_message = "github.environment must contain only letters, digits, '_', '.' and '-'."
  }
}

# -----------------------------------------------------------------------------
# Plan: read-only role for pull-request terraform plan
# -----------------------------------------------------------------------------

variable "plan" {
  description = <<-EOT
    Read-only role that pull_request workflows assume to run terraform plan.
      enabled       create the role
      state_bucket  S3 bucket holding this stack's state (read by the role)
      state_key     S3 key of the state file
  EOT
  type = object({
    enabled      = optional(bool, true)
    state_bucket = optional(string)
    state_key    = optional(string)
  })
  default = {}

  validation {
    condition     = !var.plan.enabled || (var.plan.state_bucket != null && var.plan.state_key != null)
    error_message = "plan.state_bucket and plan.state_key are required when plan.enabled is true."
  }
}

# -----------------------------------------------------------------------------
# Billing
# -----------------------------------------------------------------------------

variable "billing" {
  description = <<-EOT
    Monthly cost budget.
      alert_email         receives the alerts (80% actual, 100% forecasted)
      monthly_budget_usd  budget in USD
  EOT
  type = object({
    alert_email        = string
    monthly_budget_usd = optional(number, 5)
  })

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.billing.alert_email))
    error_message = "billing.alert_email must be a valid email address."
  }

  validation {
    condition     = var.billing.monthly_budget_usd > 0
    error_message = "billing.monthly_budget_usd must be positive."
  }
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags merged onto every taggable resource, in addition to the caller's provider default_tags. The module adds Name per resource."
  type        = map(string)
  default     = {}
}
