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
# Previews: how PR builds are stored and served
# -----------------------------------------------------------------------------

variable "previews" {
  description = <<-EOT
    Storage and serving options.
      key_prefix              S3 key prefix per PR; the number is appended (pr- => pr-9/).
                              Scopes the lifecycle rule and the role's write permission,
                              exported to the workflow as PREVIEW_KEY_PREFIX
      retention_days          objects expire after this many days (safety net)
      price_class             CloudFront price class
      error_caching_min_ttl   seconds CloudFront caches the 404 page
      robots_tag              X-Robots-Tag on every response
      extra_response_headers  additional response headers (name => value)
  EOT
  type = object({
    key_prefix             = optional(string, "pr-")
    retention_days         = optional(number, 30)
    price_class            = optional(string, "PriceClass_100")
    error_caching_min_ttl  = optional(number, 60)
    robots_tag             = optional(string, "noindex, nofollow")
    extra_response_headers = optional(map(string), {})
  })
  default = {}

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.previews.key_prefix))
    error_message = "previews.key_prefix must be non-empty and contain only letters, digits, '_' and '-' (no slashes)."
  }

  validation {
    condition     = var.previews.retention_days == floor(var.previews.retention_days) && var.previews.retention_days >= 1 && var.previews.retention_days <= 365
    error_message = "previews.retention_days must be a whole number between 1 and 365."
  }

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.previews.price_class)
    error_message = "previews.price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }

  validation {
    condition     = var.previews.error_caching_min_ttl >= 0 && var.previews.error_caching_min_ttl <= 86400
    error_message = "previews.error_caching_min_ttl must be between 0 and 86400 seconds."
  }

  validation {
    condition     = length(trimspace(var.previews.robots_tag)) > 0
    error_message = "previews.robots_tag must not be empty."
  }

  validation {
    condition     = alltrue([for k in keys(var.previews.extra_response_headers) : can(regex("^[A-Za-z0-9-]+$", k))])
    error_message = "previews.extra_response_headers keys must be valid HTTP header names."
  }
}

# -----------------------------------------------------------------------------
# Domain: optional custom hostname
# -----------------------------------------------------------------------------

variable "domain" {
  description = <<-EOT
    Custom hostname for previews. Leave empty to serve from the CloudFront domain.
      name            e.g. preview.example.com
      hosted_zone_id  Route 53 zone owning name; required with it
  EOT
  type = object({
    name           = optional(string)
    hosted_zone_id = optional(string)
  })
  default = {}

  validation {
    condition     = var.domain.name == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain.name))
    error_message = "domain.name must be a lowercase fully qualified domain name."
  }

  validation {
    condition     = var.domain.name == null || var.domain.hosted_zone_id != null
    error_message = "domain.hosted_zone_id is required when domain.name is set."
  }
}

# -----------------------------------------------------------------------------
# GitHub: deploy identity (Actions OIDC)
# -----------------------------------------------------------------------------

variable "github" {
  description = <<-EOT
    GitHub repository whose preview jobs may assume the preview role.
      repository     owner/name
      owner_id       numeric owner ID; with repository_id enables the immutable OIDC subject
      repository_id  numeric repository ID (set together with owner_id)
      environment    GitHub Environment whose jobs may assume the role
  EOT
  type = object({
    repository    = string
    owner_id      = optional(number)
    repository_id = optional(number)
    environment   = optional(string, "preview")
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
# Shared: resources owned by the production stack that previews reuse
# -----------------------------------------------------------------------------

variable "shared" {
  description = <<-EOT
    Wiring to the production (static-site) stack.
      oidc_provider_arn           the account's token.actions.githubusercontent.com provider
      rewrite_index_function_arn  CloudFront Function mapping /path/ to /path/index.html
      plan_role_name              read-only plan role granted read access to preview
                                  resources so the PR terraform-plan check keeps working;
                                  null attaches nothing
  EOT
  type = object({
    oidc_provider_arn          = string
    rewrite_index_function_arn = string
    plan_role_name             = optional(string)
  })

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.shared.oidc_provider_arn))
    error_message = "shared.oidc_provider_arn must be the ARN of a token.actions.githubusercontent.com OIDC provider."
  }

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:cloudfront::[0-9]{12}:function/", var.shared.rewrite_index_function_arn))
    error_message = "shared.rewrite_index_function_arn must be a CloudFront Function ARN."
  }

  validation {
    condition     = var.shared.plan_role_name == null || can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.shared.plan_role_name))
    error_message = "shared.plan_role_name must be a valid IAM role name."
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
