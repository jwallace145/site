# -----------------------------------------------------------------------------
# Standards: identity and tags. Defaults match this project; override only if
# you are standing up a copy somewhere else.
# -----------------------------------------------------------------------------

variable "project" {
  description = "Project identifier. Used as the resource name prefix and the Project tag."
  type        = string
  default     = "jwallace145-site"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "jwallace145"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "prod"
}

variable "repository" {
  description = "Repository tag value: where the IaC lives."
  type        = string
  default     = "github.com/jwallace145/site"
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
# Site
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Custom domain (e.g. example.com). Leave null to serve from the CloudFront domain."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for domain_name. Required when domain_name is set."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Deploy identity
# -----------------------------------------------------------------------------

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to assume the deploy role."
  type        = string
  default     = "jwallace145/site"
}

variable "github_environment" {
  description = "GitHub Environment whose jobs may assume the deploy role."
  type        = string
  default     = "production"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Billing
# -----------------------------------------------------------------------------

variable "budget_alert_email" {
  description = "Email that receives budget alerts. The only required input."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD."
  type        = number
  default     = 5
}
