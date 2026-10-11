# -----------------------------------------------------------------------------
# Standards: identity and tags. The environment's values live in the committed
# terraform.tfvars next to this file; only environment-neutral defaults are
# set here. Secrets, if any ever appear, are declared `sensitive = true` with
# no default and passed at plan/apply time via TF_VAR_<name> or -var.
# -----------------------------------------------------------------------------

variable "project" {
  description = "Project identifier. Used as the resource name prefix and the Project tag."
  type        = string
}

variable "owner" {
  description = "Owner tag value."
  type        = string
}

variable "environment" {
  description = "Environment tag value."
  type        = string
}

variable "repository" {
  description = "Repository tag value: where the IaC lives."
  type        = string
}

variable "extra_tags" {
  description = "Additional tags merged onto the standard set."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# AWS
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Region for the bucket and IAM resources. CloudFront/ACM are global/us-east-1 regardless."
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# DNS and custom domain
# -----------------------------------------------------------------------------

variable "dns_zone_name" {
  description = "Domain for the Terraform-managed Route 53 hosted zone. null manages no zone; then hosted_zone_id must point at an existing one for domain_name."
  type        = string

  validation {
    condition     = var.dns_zone_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.dns_zone_name))
    error_message = "dns_zone_name must be a lowercase fully qualified domain name."
  }
}

variable "domain_name" {
  description = "Hostname the site is served from. null serves it from the CloudFront domain. Set only after the zone's nameservers are live at the registrar (ACM validates via DNS)."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "domain_name must be a lowercase fully qualified domain name."
  }

  validation {
    condition     = var.domain_name == null || var.dns_zone_name == null || var.domain_name == var.dns_zone_name || endswith(var.domain_name, ".${var.dns_zone_name}")
    error_message = "domain_name must be dns_zone_name or a subdomain of it."
  }
}

variable "hosted_zone_id" {
  description = "Existing Route 53 hosted zone for domain_name, used only when dns_zone_name is null."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || var.dns_zone_name != null || var.hosted_zone_id != null
    error_message = "hosted_zone_id is required when domain_name is set and dns_zone_name is null."
  }
}

variable "www_redirect" {
  description = "Redirect www.<domain_name> to domain_name. Ignored when domain_name is null."
  type        = bool
  default     = true
}

variable "preview_use_custom_domain" {
  description = "Serve PR previews from preview_domain_name instead of the CloudFront domain. Ignored when domain_name is null."
  type        = bool
  default     = true
}

variable "preview_domain_name" {
  description = "Hostname for PR previews. null derives preview.<domain_name>."
  type        = string
  default     = null

  validation {
    condition     = var.preview_domain_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.preview_domain_name))
    error_message = "preview_domain_name must be a lowercase fully qualified domain name."
  }
}

variable "dns_records" {
  description = "Extra records in the managed zone, keyed by name (\"@\" = apex, \"mail\" = mail.<zone>). See modules/dns-zone."
  type = map(object({
    type   = string
    ttl    = optional(number, 300)
    values = list(string)
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Deploy identity
# -----------------------------------------------------------------------------

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to assume the deploy role."
  type        = string
}

variable "github_owner_id" {
  description = "Numeric GitHub ID of the repository owner (gh api users/<owner> --jq .id). Needed when the repo uses immutable OIDC subjects."
  type        = number
}

variable "github_repository_id" {
  description = "Numeric GitHub ID of the repository (gh api repos/<owner>/<name> --jq .id)."
  type        = number
}

variable "github_environment" {
  description = "GitHub Environment whose jobs may assume the deploy role."
  type        = string
  default     = "production"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. false looks up the account's existing one (one per account)."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Billing
# -----------------------------------------------------------------------------

variable "budget_alert_email" {
  description = "Email that receives budget alerts."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD."
  type        = number
  default     = 5
}

# -----------------------------------------------------------------------------
# PR previews
# -----------------------------------------------------------------------------

variable "preview_enabled" {
  description = "Create the PR preview stack (bucket, distribution, OIDC role). false removes it."
  type        = bool
  default     = true
}

variable "preview_github_environment" {
  description = "GitHub Environment whose jobs may publish previews."
  type        = string
  default     = "preview"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.preview_github_environment))
    error_message = "preview_github_environment must contain only letters, digits, '_', '.' and '-'."
  }
}

variable "preview_key_prefix" {
  description = "S3 key prefix per PR; the PR number is appended (pr- => pr-9/)."
  type        = string
  default     = "pr-"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.preview_key_prefix))
    error_message = "preview_key_prefix must be non-empty and contain only letters, digits, _ and - (no slashes)."
  }
}

variable "preview_retention_days" {
  description = "Days after which preview objects expire, in case a PR's cleanup never ran."
  type        = number
  default     = 30

  validation {
    condition     = var.preview_retention_days == floor(var.preview_retention_days) && var.preview_retention_days >= 1 && var.preview_retention_days <= 365
    error_message = "preview_retention_days must be a whole number between 1 and 365."
  }
}

variable "preview_price_class" {
  description = "CloudFront price class for the preview distribution."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.preview_price_class)
    error_message = "preview_price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "preview_robots_tag" {
  description = "X-Robots-Tag header on every preview response."
  type        = string
  default     = "noindex, nofollow"

  validation {
    condition     = length(trimspace(var.preview_robots_tag)) > 0
    error_message = "preview_robots_tag must not be empty."
  }
}

variable "preview_extra_response_headers" {
  description = "Extra response headers (name => value) on every preview response."
  type        = map(string)
  default     = {}
}
