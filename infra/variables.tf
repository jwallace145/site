variable "aws_region" {
  description = "Region for the site bucket and IAM resources. CloudFront and ACM are global/us-east-1 regardless."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Short project name used as a prefix for resource names."
  type        = string
  default     = "jwallace145-site"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}$", var.name))
    error_message = "name must be lowercase letters, digits and hyphens (2-41 chars)."
  }
}

variable "domain_name" {
  description = "Custom domain for the site (e.g. example.com). Leave null to use the CloudFront domain."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID that owns domain_name. Required when domain_name is set."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || var.hosted_zone_id != null
    error_message = "hosted_zone_id is required when domain_name is set."
  }
}

variable "create_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set to false if the account already has one for token.actions.githubusercontent.com."
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to assume the deploy role."
  type        = string
  default     = "jwallace145/site"

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

variable "budget_alert_email" {
  description = "Email address that receives the monthly budget alert."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_alert_email))
    error_message = "budget_alert_email must be a valid email address."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD. Alerts fire at 80% actual and 100% forecasted."
  type        = number
  default     = 5
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
