# -----------------------------------------------------------------------------
# preview role: assumed by the pull_request preview workflow through the
# repository's `preview` GitHub Environment. Writes only the preview bucket
# and invalidates only the preview distribution.
# -----------------------------------------------------------------------------

locals {
  github_oidc_host = "token.actions.githubusercontent.com"

  github_owner = split("/", var.github_repository)[0]
  github_name  = split("/", var.github_repository)[1]

  # Plain and immutable subject shapes, as in the static-site module.
  github_subject_prefixes = compact([
    "repo:${var.github_repository}",
    var.github_owner_id != null ? "repo:${local.github_owner}@${var.github_owner_id}/${local.github_name}@${var.github_repository_id}" : null,
  ])

  preview_subjects = [for p in local.github_subject_prefixes : "${p}:environment:${var.github_environment}"]
}

data "aws_iam_policy_document" "preview_assume_role" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = local.preview_subjects
    }
  }
}

resource "aws_iam_role" "preview" {
  name                 = local.names.preview_github_role
  description          = "Assumed by GitHub Actions (${var.github_repository}, ${var.github_environment}) to publish PR previews to ${local.names.preview_cdn}"
  assume_role_policy   = data.aws_iam_policy_document.preview_assume_role.json
  max_session_duration = 3600

  tags = merge(var.tags, { Name = local.names.preview_github_role })
}

data "aws_iam_policy_document" "preview" {
  statement {
    sid       = "ListPreviewBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.preview.arn]
  }

  # Only keys under the PR prefix; the shared 404 page is Terraform's.
  statement {
    sid    = "WritePreviewObjects"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.preview.arn}/${var.key_prefix}*"]
  }

  statement {
    sid       = "InvalidatePreviewDistribution"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.preview.arn]
  }
}

resource "aws_iam_role_policy" "preview" {
  name   = local.names.preview_github_policy
  role   = aws_iam_role.preview.id
  policy = data.aws_iam_policy_document.preview.json
}

# -----------------------------------------------------------------------------
# Optional: let the read-only plan role refresh this module's resources so the
# PR terraform-plan check keeps working. CloudFront read is already account
# wide in that role.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "plan_read" {
  count = var.plan_role_name != null ? 1 : 0

  statement {
    sid       = "ReadPreviewBucketConfig"
    effect    = "Allow"
    actions   = ["s3:Get*", "s3:List*"]
    resources = [aws_s3_bucket.preview.arn]
  }

  statement {
    sid       = "ReadNotFoundObject"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectTagging"]
    resources = ["${aws_s3_bucket.preview.arn}/404.html"]
  }

  statement {
    sid    = "ReadPreviewRole"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListRoleTags",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = [aws_iam_role.preview.arn]
  }
}

resource "aws_iam_role_policy" "plan_read" {
  count = var.plan_role_name != null ? 1 : 0

  name   = local.names.preview_plan_policy
  role   = var.plan_role_name
  policy = data.aws_iam_policy_document.plan_read[0].json
}
