# preview-site module
#
# A private S3 bucket fronted by CloudFront (OAC) that hosts one build per
# pull request under <key_prefix><number>/, plus a GitHub Actions OIDC role
# scoped to one repository environment that may write it.
#
# Files:
#   naming.tf      the <prefix>-preview-<resource> naming standard
#   main.tf        preview bucket and lifecycle
#   cloudfront.tf  distribution and headers (reuses the production rewrite function)
#   iam.tf         preview role; optional read grant for the plan role
#   files/         the shared 404 page uploaded to the bucket root

resource "aws_s3_bucket" "preview" {
  bucket_prefix = "${local.names.preview_bucket}-"

  tags = merge(var.tags, { Name = local.names.preview_bucket })
}

resource "aws_s3_bucket_public_access_block" "preview" {
  bucket = aws_s3_bucket.preview.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "preview" {
  bucket = aws_s3_bucket.preview.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "preview" {
  bucket = aws_s3_bucket.preview.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "preview" {
  bucket = aws_s3_bucket.preview.id

  versioning_configuration {
    status = "Suspended"
  }
}

# Safety net: a PR whose cleanup job never ran still expires.
resource "aws_s3_bucket_lifecycle_configuration" "preview" {
  bucket = aws_s3_bucket.preview.id

  rule {
    id     = "expire-stale-previews"
    status = "Enabled"

    filter {
      prefix = var.key_prefix
    }

    expiration {
      days = var.retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.preview]
}

# One 404 page at the bucket root serves every preview; each PR's own
# 404.html lives under its prefix where CloudFront cannot select it.
resource "aws_s3_object" "not_found" {
  bucket        = aws_s3_bucket.preview.id
  key           = "404.html"
  source        = "${path.module}/files/404.html"
  etag          = filemd5("${path.module}/files/404.html")
  content_type  = "text/html; charset=utf-8"
  cache_control = "public, max-age=60"

  tags = merge(var.tags, { Name = local.names.preview_bucket })
}

data "aws_iam_policy_document" "preview_bucket" {
  statement {
    sid     = "AllowCloudFrontOAC"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.preview.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.preview.arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.preview.arn,
      "${aws_s3_bucket.preview.arn}/*",
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

resource "aws_s3_bucket_policy" "preview" {
  bucket = aws_s3_bucket.preview.id
  policy = data.aws_iam_policy_document.preview_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.preview]
}
