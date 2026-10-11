# -----------------------------------------------------------------------------
# deploy: GitHub Actions OIDC. Two roles, both assumed with short-lived tokens:
#   deploy  - the release workflow (environment: production) writes the bucket
#             and invalidates CloudFront
#   plan    - pull_request workflows read state and live resources to run
#             `terraform plan`; it can change nothing
# No long-lived AWS keys exist anywhere.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  github_oidc_url  = "https://token.actions.githubusercontent.com"
  github_oidc_host = "token.actions.githubusercontent.com"

  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  # GitHub can issue the `sub` claim in two shapes:
  #   plain:     repo:owner/name:...
  #   immutable: repo:owner@<owner id>/name@<repo id>:...   (repo setting
  #              "use immutable subject", on for this repository)
  # Both are accepted when the IDs are supplied, so toggling the setting does
  # not break deploys.
  github_owner = split("/", var.github_repository)[0]
  github_name  = split("/", var.github_repository)[1]

  github_subject_prefixes = compact([
    "repo:${var.github_repository}",
    var.github_owner_id != null ? "repo:${local.github_owner}@${var.github_owner_id}/${local.github_name}@${var.github_repository_id}" : null,
  ])

  deploy_subjects = [for p in local.github_subject_prefixes : "${p}:environment:${var.github_environment}"]
  plan_subjects   = [for p in local.github_subject_prefixes : "${p}:pull_request"]

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

# An account holds one provider per URL. With create_oidc_provider = false the
# existing one is looked up instead.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = local.github_oidc_url
  client_id_list = ["sts.amazonaws.com"]

  # AWS validates GitHub's issuer against its trusted root CAs; these
  # well-known thumbprints are kept for compatibility.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = merge(var.tags, { Name = local.names.deploy_oidc_provider })
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = local.github_oidc_url
}

# -----------------------------------------------------------------------------
# deploy role
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "deploy_assume_role" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only jobs in this repository's named environment may assume the role.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = local.deploy_subjects
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = local.names.deploy_github_role
  description          = "Assumed by GitHub Actions (${var.github_repository}, ${var.github_environment}) to deploy ${local.names.web_cdn}"
  assume_role_policy   = data.aws_iam_policy_document.deploy_assume_role.json
  max_session_duration = 3600

  tags = merge(var.tags, { Name = local.names.deploy_github_role })
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "ListWebBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.web.arn]
  }

  statement {
    sid    = "WriteWebObjects"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.web.arn}/*"]
  }

  statement {
    sid       = "InvalidateWebDistribution"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.web.arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = local.names.deploy_github_policy
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# -----------------------------------------------------------------------------
# plan role (read-only). Trusts pull_request workflows from this repository.
# Fork PRs never receive an OIDC token, so only branches in the repo can plan.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "plan_assume_role" {
  count = var.plan_role ? 1 : 0

  statement {
    sid     = "GitHubActionsPullRequestOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = local.plan_subjects
    }
  }
}

resource "aws_iam_role" "plan" {
  count = var.plan_role ? 1 : 0

  name                 = local.names.plan_github_role
  description          = "Read-only role for terraform plan in ${var.github_repository} pull requests"
  assume_role_policy   = data.aws_iam_policy_document.plan_assume_role[0].json
  max_session_duration = 3600

  tags = merge(var.tags, { Name = local.names.plan_github_role })
}

data "aws_iam_policy_document" "plan" {
  count = var.plan_role ? 1 : 0

  # State: read the one state object. `terraform plan -lock=false` never
  # writes, so no Put/Delete on the lockfile.
  statement {
    sid       = "ReadStateObject"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["arn:${local.partition}:s3:::${var.terraform_state_bucket}/${var.terraform_state_key}"]
  }

  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${local.partition}:s3:::${var.terraform_state_bucket}"]
  }

  # Refresh needs bucket-level configuration of the web bucket. Bucket-level
  # Get*/List* cannot read objects; that requires the /* resource.
  statement {
    sid       = "ReadWebBucketConfig"
    effect    = "Allow"
    actions   = ["s3:Get*", "s3:List*"]
    resources = [aws_s3_bucket.web.arn]
  }

  statement {
    sid    = "ReadCloudFront"
    effect = "Allow"
    actions = [
      "cloudfront:Get*",
      "cloudfront:List*",
      "cloudfront:Describe*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadIamRoles"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListRoleTags",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = [
      aws_iam_role.deploy.arn,
      "arn:${local.partition}:iam::${local.account_id}:role/${local.names.plan_github_role}",
    ]
  }

  statement {
    sid       = "ReadOidcProvider"
    effect    = "Allow"
    actions   = ["iam:GetOpenIDConnectProvider"]
    resources = [local.oidc_provider_arn]
  }

  # The aws_iam_openid_connect_provider data source lists providers to find
  # the one matching the URL. List has no resource-level scope.
  statement {
    sid       = "ListOidcProviders"
    effect    = "Allow"
    actions   = ["iam:ListOpenIDConnectProviders"]
    resources = ["*"]
  }

  statement {
    sid    = "ReadBudget"
    effect = "Allow"
    actions = [
      "budgets:ViewBudget",
      "budgets:DescribeBudget*",
      "budgets:ListTagsForResource",
    ]
    resources = ["arn:${local.partition}:budgets::${local.account_id}:budget/${local.names.billing_monthly}"]
  }

  # Only exercised when a custom domain is configured.
  statement {
    sid    = "ReadDns"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:GetChange",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "plan" {
  count = var.plan_role ? 1 : 0

  name   = local.names.plan_github_policy
  role   = aws_iam_role.plan[0].id
  policy = data.aws_iam_policy_document.plan[0].json
}
