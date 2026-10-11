# Infrastructure

Terraform for the static site: a private S3 bucket behind CloudFront, a GitHub
Actions OIDC deploy role, and a monthly budget alert. One root module, applied
manually by the owner. CI only runs `terraform fmt -check` and
`terraform validate`; it never applies.

| File             | Contents                                                   |
| ---------------- | ---------------------------------------------------------- |
| `main.tf`        | Providers, S3 backend, site bucket, bucket policy, budget  |
| `cloudfront.tf`  | OAC, viewer-request function, headers policy, distribution, optional ACM + Route 53 |
| `iam.tf`         | GitHub OIDC provider and the least-privilege deploy role    |
| `variables.tf`   | Inputs                                                     |
| `outputs.tf`     | Values that become the GitHub `production` environment vars |
| `function/`      | CloudFront Function source                                 |

## Prerequisites

- Terraform `>= 1.11` (see `required_version` in `main.tf`)
- AWS CLI authenticated as an admin in the target account
- Optional: a Route 53 hosted zone if you want a custom domain

## 1. Bootstrap the state bucket (once)

State lives in S3 with native lockfile locking (`use_lockfile = true`), so no
DynamoDB table is needed. The bucket is created by hand, outside Terraform,
and its name is never committed.

```bash
export AWS_REGION=us-east-1
export TF_STATE_BUCKET="<unique-name>-tfstate"   # e.g. jwallace145-tfstate-<random>

aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION"
# Outside us-east-1 add: --create-bucket-configuration LocationConstraint=$AWS_REGION

aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$TF_STATE_BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$TF_STATE_BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

## 2. Configure

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # git-ignored
$EDITOR terraform.tfvars                        # at minimum: budget_alert_email
```

If the account already has an OIDC provider for
`token.actions.githubusercontent.com`, set `create_oidc_provider = false`.

## 3. Init, plan, apply

```bash
terraform init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="region=$AWS_REGION"

terraform plan -out=tfplan
terraform apply tfplan
```

The first apply takes several minutes while the CloudFront distribution
deploys. With a custom domain, ACM validation waits for the DNS record to
propagate.

## 4. Wire up GitHub

```bash
terraform output github_environment_variables
```

Create a GitHub Environment named `production` and add each key as an
environment **variable** (not a secret; none of these values are sensitive).
See `docs/repo-setup.md` for the `gh` commands.

## Cache behaviour

- `_astro/*` (content-hashed) is uploaded with `public, max-age=31536000, immutable`.
- HTML is uploaded with `public, max-age=0, must-revalidate`.
- CloudFront uses the managed `CachingOptimized` policy and every deploy
  invalidates `/*`.

## Custom domain

Set `domain_name` and `hosted_zone_id` together. Terraform issues an ACM
certificate in `us-east-1`, validates it via DNS, and creates `A` and `AAAA`
alias records in the hosted zone. Leave both unset to serve from the
CloudFront domain.

## Destroy

```bash
aws s3 rm "s3://$(terraform output -raw site_bucket_name)" --recursive
terraform destroy
```

The bucket must be empty before Terraform can delete it.
