# -----------------------------------------------------------------------------
# Identity and naming
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for every resource name, e.g. jwallace145-site. Names become <name_prefix>-preview-<resource>."
  type        = string

  validation {
    # Leaves room for "-preview-bucket-" plus the 26-char suffix AWS appends to bucket_prefix (63 max).
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits and hyphens, 2-21 characters."
  }
}

# -----------------------------------------------------------------------------
# Previews
# -----------------------------------------------------------------------------

variable "key_prefix" {
  description = "S3 key prefix previews are written under; the PR number is appended (pr- => pr-9/). Scopes the lifecycle rule and the role's write permission, and is exported to the workflow as PREVIEW_KEY_PREFIX."
  type        = string
  default     = "pr-"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.key_prefix))
    error_message = "key_prefix must be non-empty and contain only letters, digits, '_' and '-' (no slashes)."
  }
}

variable "retention_days" {
  description = "Days after which preview objects expire. A safety net for PRs whose cleanup job never ran."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days == floor(var.retention_days) && var.retention_days >= 1 && var.retention_days <= 365
    error_message = "retention_days must be a whole number between 1 and 365."
  }
}

variable "price_class" {
  description = "CloudFront price class for the preview distribution."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "error_caching_min_ttl" {
  description = "Seconds CloudFront caches the 404 response for missing preview paths."
  type        = number
  default     = 60

  validation {
    condition     = var.error_caching_min_ttl >= 0 && var.error_caching_min_ttl <= 86400
    error_message = "error_caching_min_ttl must be between 0 and 86400 seconds."
  }
}

variable "robots_tag" {
  description = "Value of the X-Robots-Tag header on every preview response, so search engines never index previews."
  type        = string
  default     = "noindex, nofollow"

  validation {
    condition     = length(trimspace(var.robots_tag)) > 0
    error_message = "robots_tag must not be empty."
  }
}

variable "extra_response_headers" {
  description = "Additional response headers (name => value) added to every preview response."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.extra_response_headers) : can(regex("^[A-Za-z0-9-]+$", k))])
    error_message = "extra_response_headers keys must be valid HTTP header names (letters, digits, hyphens)."
  }
}

variable "rewrite_index_function_arn" {
  description = "ARN of the CloudFront Function that maps /path/ to /path/index.html. Shared with the production distribution."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:cloudfront::[0-9]{12}:function/", var.rewrite_index_function_arn))
    error_message = "rewrite_index_function_arn must be a CloudFront Function ARN."
  }
}

# -----------------------------------------------------------------------------
# Custom hostname (optional)
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Custom hostname for previews (e.g. preview.example.com). null serves them from the CloudFront domain."
  type        = string
  default     = null

  validation {
    condition     = var.domain_name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "domain_name must be a lowercase fully qualified domain name."
  }
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

# -----------------------------------------------------------------------------
# Deploy identity (GitHub Actions OIDC)
# -----------------------------------------------------------------------------

variable "oidc_provider_arn" {
  description = "ARN of the account's token.actions.githubusercontent.com OIDC provider."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.oidc_provider_arn))
    error_message = "oidc_provider_arn must be the ARN of a token.actions.githubusercontent.com OIDC provider."
  }
}

variable "github_repository" {
  description = "GitHub repository (owner/name) whose preview jobs may assume the preview role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in owner/name form."
  }
}

variable "github_owner_id" {
  description = "Numeric GitHub ID of the repository owner. With github_repository_id, enables GitHub's immutable OIDC subject. null accepts the plain subject only."
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
  description = "GitHub Environment whose jobs may assume the preview role."
  type        = string
  default     = "preview"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.github_environment))
    error_message = "github_environment must contain only letters, digits, '_', '.' and '-'."
  }
}

variable "plan_role_name" {
  description = "Name of an existing read-only role (the PR terraform-plan role) that is granted read access to the preview resources. null attaches nothing."
  type        = string
  default     = null

  validation {
    condition     = var.plan_role_name == null || can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.plan_role_name))
    error_message = "plan_role_name must be a valid IAM role name."
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
