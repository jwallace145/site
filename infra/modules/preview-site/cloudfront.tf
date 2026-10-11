# -----------------------------------------------------------------------------
# preview: CloudFront distribution in front of the preview bucket.
# -----------------------------------------------------------------------------

locals {
  preview_origin_id = "s3-preview"
}

resource "aws_cloudfront_origin_access_control" "preview" {
  name                              = local.names.preview_oac
  description                       = "OAC for ${local.names.preview_bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_response_headers_policy" "preview_security" {
  name    = local.names.preview_security_headers
  comment = "Security headers + noindex for ${local.names.preview_cdn}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000 # 2 years
      include_subdomains         = true
      preload                    = false
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }

  custom_headers_config {
    items {
      header   = "X-Robots-Tag"
      value    = var.robots_tag
      override = true
    }

    items {
      header   = "Permissions-Policy"
      value    = "camera=(), microphone=(), geolocation=()"
      override = true
    }

    dynamic "items" {
      for_each = var.extra_response_headers
      content {
        header   = items.key
        value    = items.value
        override = true
      }
    }
  }
}

resource "aws_cloudfront_distribution" "preview" {
  enabled         = true
  comment         = local.names.preview_cdn
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = var.price_class
  # No default_root_object: "/" goes through the rewrite function to
  # /index.html, which does not exist, and so returns the 404 page.
  wait_for_deployment = true

  origin {
    origin_id                = local.preview_origin_id
    domain_name              = aws_s3_bucket.preview.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.preview.id
  }

  default_cache_behavior {
    target_origin_id       = local.preview_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.preview_security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = var.rewrite_index_function_arn
    }
  }

  # S3 answers 403 for missing keys when the caller lacks ListBucket, so both
  # become the shared 404 page with a 404 status.
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = var.error_caching_min_ttl
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = var.error_caching_min_ttl
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, { Name = local.names.preview_cdn })
}
