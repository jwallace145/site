# -----------------------------------------------------------------------------
# Identity and naming
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jwallace145-site. Names become <name_prefix>-<domain>-<resource>."
  type        = string

  validation {
    # Leaves room for "-web-bucket-" plus the 26-char suffix AWS appends to bucket_prefix (63 max).
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits and hyphens, 2-25 characters."
  }
}

# -----------------------------------------------------------------------------
# Site
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Custom domain for the site (e.g. example.com). null serves the site from the CloudFront domain."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone that owns domain_name. Required when domain_name is set."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || var.hosted_zone_id != null
    error_message = "hosted_zone_id is required when domain_name is set."
  }
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "error_caching_min_ttl" {
  description = "Seconds CloudFront caches the 404 page for 403/404 origin responses."
  type        = number
  default     = 60
}

# -----------------------------------------------------------------------------
# Deploy identity (GitHub Actions OIDC)
# -----------------------------------------------------------------------------

variable "github_repository" {
  description = "GitHub repository (owner/name) whose workflows may assume the deploy role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in owner/name form."
  }
}

variable "github_environment" {
  description = "GitHub Environment whose jobs may assume the deploy role."
  type        = string
  default     = "production"
}

variable "create_oidc_provider" {
  description = "Create the token.actions.githubusercontent.com OIDC provider. false looks up an existing one (one per account)."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Billing
# -----------------------------------------------------------------------------

variable "budget_alert_email" {
  description = "Email that receives the monthly budget alerts."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_alert_email))
    error_message = "budget_alert_email must be a valid email address."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD. Alerts at 80% actual and 100% forecasted."
  type        = number
  default     = 5
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags merged onto every taggable resource, in addition to the caller's provider default_tags. The module adds Name per resource."
  type        = map(string)
  default     = {}
}
