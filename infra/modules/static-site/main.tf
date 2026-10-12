# static-site module
#
# A private S3 bucket fronted by CloudFront (OAC), a GitHub Actions OIDC deploy
# role scoped to one repository environment, and a monthly budget alert.
#
# Files:
#   naming.tf      the <prefix>-<domain>-<resource> naming standard
#   main.tf        site bucket (domain: web)
#   cloudfront.tf  distribution, headers, function (index rewrite + www redirect), optional ACM/Route 53 (web)
#   iam.tf         OIDC provider and deploy role (domain: deploy)
#   budget.tf      cost alert (domain: billing)
#
# Room is left for a backend as a second CloudFront origin under /api/* and a
# separate private documents bucket; neither is built here.

# -----------------------------------------------------------------------------
# web: site bucket. Private, encrypted, readable only by the distribution.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "web" {
  # Bucket names are global. The prefix carries the project's domain, which is
  # unique enough; a deterministic name keeps the bucket findable by name.
  bucket = local.names.web_bucket

  tags = merge(var.tags, { Name = local.names.web_bucket })
}

resource "aws_s3_bucket_public_access_block" "web" {
  bucket = aws_s3_bucket.web.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "web" {
  bucket = aws_s3_bucket.web.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "web" {
  bucket = aws_s3_bucket.web.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "web" {
  bucket = aws_s3_bucket.web.id

  versioning_configuration {
    status = "Suspended"
  }
}

data "aws_iam_policy_document" "web_bucket" {
  statement {
    sid     = "AllowCloudFrontOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.web.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.web.arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.web.arn,
      "${aws_s3_bucket.web.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.id
  policy = data.aws_iam_policy_document.web_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.web]
}
