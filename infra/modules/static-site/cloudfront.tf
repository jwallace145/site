# -----------------------------------------------------------------------------
# web: CloudFront distribution in front of the site bucket.
# -----------------------------------------------------------------------------

locals {
  web_origin_id = "s3-web"
}

resource "aws_cloudfront_origin_access_control" "web" {
  name                              = local.names.web_oac
  description                       = "OAC for ${local.names.web_bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Astro's directory build format writes `/about/index.html`. S3 has no default
# document for sub-paths, so this viewer-request function maps `/about/` and
# `/about` to `/about/index.html` before the origin request.
resource "aws_cloudfront_function" "web_rewrite_index" {
  name    = local.names.web_rewrite_index
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite directory and extensionless paths to index.html"
  publish = true
  code    = file("${path.module}/function/rewrite-index.js")
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_response_headers_policy" "web_security" {
  name    = local.names.web_security_headers
  comment = "Security headers for ${local.names.web_cdn}"

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
      header   = "Permissions-Policy"
      value    = "camera=(), microphone=(), geolocation=()"
      override = true
    }
  }
}

resource "aws_cloudfront_distribution" "web" {
  enabled             = true
  comment             = local.names.web_cdn
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.price_class
  default_root_object = "index.html"
  wait_for_deployment = true

  aliases = local.use_custom_domain ? [var.domain_name] : []

  origin {
    origin_id                = local.web_origin_id
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.web.id
  }

  default_cache_behavior {
    target_origin_id       = local.web_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.web_security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.web_rewrite_index.arn
    }
  }

  # S3 answers 403 for missing keys when the caller lacks ListBucket, so both
  # 403 and 404 become the site's 404 page with a 404 status.
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
    cloudfront_default_certificate = local.use_custom_domain ? null : true
    acm_certificate_arn            = local.use_custom_domain ? aws_acm_certificate_validation.web[0].certificate_arn : null
    ssl_support_method             = local.use_custom_domain ? "sni-only" : null
    minimum_protocol_version       = local.use_custom_domain ? "TLSv1.2_2021" : "TLSv1"
  }

  tags = merge(var.tags, { Name = local.names.web_cdn })
}

# -----------------------------------------------------------------------------
# web: optional custom domain. ACM certificate (us-east-1) + Route 53 aliases.
# Only created when domain_name is set.
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "web" {
  count    = local.use_custom_domain ? 1 : 0
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = merge(var.tags, { Name = local.names.web_certificate })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "web_acm_validation" {
  for_each = local.use_custom_domain ? {
    for dvo in aws_acm_certificate.web[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "web" {
  count    = local.use_custom_domain ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.web[0].arn
  validation_record_fqdns = [for r in aws_route53_record.web_acm_validation : r.fqdn]
}

resource "aws_route53_record" "web" {
  for_each = local.use_custom_domain ? toset(["A", "AAAA"]) : toset([])

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = each.key

  alias {
    name                   = aws_cloudfront_distribution.web.domain_name
    zone_id                = aws_cloudfront_distribution.web.hosted_zone_id
    evaluate_target_health = false
  }
}
