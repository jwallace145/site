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

variable "redirect_hostnames" {
  description = "Hostnames that 301-redirect to domain_name (e.g. www.example.com). Added to the certificate, the distribution aliases and the hosted zone. Requires domain_name."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for h in var.redirect_hostnames : can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", h))])
    error_message = "redirect_hostnames must be lowercase fully qualified domain names."
  }

  validation {
    condition     = length(var.redirect_hostnames) == 0 || var.domain_name != null
    error_message = "redirect_hostnames requires domain_name."
  }

  validation {
    condition     = !contains(var.redirect_hostnames, coalesce(var.domain_name, "-"))
    error_message = "redirect_hostnames must not contain domain_name itself."
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

variable "github_owner_id" {
  description = "Numeric GitHub ID of the repository owner. With github_repository_id, enables GitHub's immutable OIDC subject (repo:owner@id/name@id:...). null accepts the plain subject only."
  type        = number
  default     = null
}

variable "github_repository_id" {
  description = "Numeric GitHub ID of the repository. See github_owner_id."
  type        = number
  default     = null

  validation {
    condition     = (var.github_owner_id == null) == (var.github_repository_id == null)
    error_message = "github_owner_id and github_repository_id must be set together."
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

variable "plan_role" {
  description = "Create a read-only role that pull_request workflows assume to run terraform plan. Needs terraform_state_bucket/key."
  type        = bool
  default     = true
}

variable "terraform_state_bucket" {
  description = "S3 bucket holding this stack's state. Read by the plan role."
  type        = string
  default     = null

  validation {
    condition     = !var.plan_role || (var.terraform_state_bucket != null && var.terraform_state_key != null)
    error_message = "terraform_state_bucket and terraform_state_key are required when plan_role is true."
  }
}

variable "terraform_state_key" {
  description = "S3 key of this stack's state file. Read by the plan role."
  type        = string
  default     = null
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
