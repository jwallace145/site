# Infrastructure

Terraform for the site, split into a reusable module and one thin root per
environment that applies it with this project's standards. Only `prod` exists
today; a `dev` or `staging` environment would be a sibling directory with its
own committed `terraform.tfvars` and state key
(`environment=<env>/terraform.tfstate`). Applied manually by the owner; CI
runs `terraform fmt -check`, `terraform validate` and a read-only plan.

```
infra/
  modules/static-site/   the module: S3 + CloudFront (OAC), OIDC deploy role, budget
    naming.tf            <prefix>-<domain>-<resource> naming standard, all names in one place
    main.tf              web: site bucket
    cloudfront.tf        web: distribution, headers, function, optional ACM + Route 53
    iam.tf               deploy: deploy role (release) and read-only plan role (PRs)
    budget.tf            billing: monthly cost alert
    variables.tf  outputs.tf  versions.tf  function/
  modules/preview-site/  PR previews: preview bucket + CloudFront, OIDC preview role, shared 404 page
    naming.tf  main.tf  cloudfront.tf  iam.tf  variables.tf  outputs.tf  versions.tf  files/
  environments/prod/     the root you run terraform in; dev/staging would be siblings
    main.tf              computes names + tags, calls the module
    variables.tf         the interface: validated variables, environment-neutral defaults
    terraform.tfvars     the prod environment's values (committed; nothing secret)
    providers.tf         default_tags carry the standard tags
    backend.tf           S3 backend: jwallace145-site-tfstate, key environment=prod/terraform.tfstate
    outputs.tf           values for the GitHub `production` and `preview` environments
  scripts/
    bootstrap-state-bucket.sh   creates the state bucket with the standard tags
```

## Standards

**Names** follow `<project>-<domain>-<resource>`, where `domain` is the logical
area (`web`, `deploy`, `billing`). With the default `project = "jwallace145-site"`:

| Resource                      | Name                                          |
| ----------------------------- | --------------------------------------------- |
| S3 bucket                     | `jwallace145-site-web-bucket-<aws suffix>`     |
| Origin access control         | `jwallace145-site-web-oac`                     |
| CloudFront distribution       | `jwallace145-site-web-cdn` (comment + Name tag) |
| Response headers policy       | `jwallace145-site-web-security-headers`        |
| CloudFront function           | `jwallace145-site-web-rewrite-index`           |
| ACM certificate (optional)    | `jwallace145-site-web-certificate` (Name tag)  |
| IAM role (deploy)             | `jwallace145-site-deploy-github-role`          |
| IAM role policy (deploy)      | `jwallace145-site-deploy-github-policy`        |
| IAM role (plan, read-only)    | `jwallace145-site-deploy-github-plan-role`     |
| IAM role policy (plan)        | `jwallace145-site-deploy-github-plan-policy`   |
| OIDC provider                 | `jwallace145-site-deploy-github-oidc` (Name tag) |
| Budget                        | `jwallace145-site-billing-monthly`             |
| S3 bucket (previews)          | `jwallace145-site-preview-bucket-<aws suffix>` |
| Origin access control (previews) | `jwallace145-site-preview-oac`              |
| CloudFront distribution (previews) | `jwallace145-site-preview-cdn`            |
| Response headers policy (previews) | `jwallace145-site-preview-security-headers` |
| IAM role (previews)           | `jwallace145-site-preview-github-role`         |
| IAM role policy (previews)    | `jwallace145-site-preview-github-policy`       |
| IAM role policy (plan → previews) | `jwallace145-site-preview-github-plan-policy` |

`terraform output resource_names` prints the full list.

**Tags** on every taggable resource, via provider `default_tags`:

| Tag           | Default value               |
| ------------- | --------------------------- |
| `Project`     | `jwallace145-site`          |
| `Owner`       | `jwallace145`               |
| `Environment` | `prod`                      |
| `ManagedBy`   | `terraform`                 |
| `Repository`  | `github.com/jwallace145/site` |
| `Name`        | the resource's name above   |

Add more with `extra_tags`.

## Prerequisites

- Terraform `>= 1.11`
- AWS CLI authenticated as an admin in the target account (`aws sts get-caller-identity`)
- Optional: a Route 53 hosted zone, only if you want a custom domain now

## 1. Bootstrap the state bucket (once)

State lives in `s3://jwallace145-site-tfstate` with native lockfile locking,
so no DynamoDB table is needed. The key is `environment=prod/terraform.tfstate`;
Terraform writes `environment=prod/terraform.tfstate.tflock` beside it while a
write is in flight and removes it afterwards.

The bucket is created outside Terraform by a script that applies the same
standard tags, plus versioning, encryption, public-access block and a
90-day retention for old state versions. Re-running it is safe.

```bash
infra/scripts/bootstrap-state-bucket.sh
```

## 2. Configure

`infra/environments/prod/terraform.tfvars` is committed and describes the
whole environment; edit it in a PR like any other code. Nothing in it is
secret. If a sensitive input is ever needed, declare it in `variables.tf`
with `sensitive = true` and no default, and pass it at plan/apply time
(`TF_VAR_<name>=... terraform apply` or `-var`); CI would read it from a
repository secret the same way. Personal overrides go in a git-ignored
`*.local.tfvars` passed with `-var-file`.

The account already has an OIDC provider for
`token.actions.githubusercontent.com`, so `create_oidc_provider = false` and
the module looks it up. Confirm it accepts the `sts.amazonaws.com` audience
the deploy role trusts:

```bash
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn "$(aws iam list-open-id-connect-providers \
    --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text)" \
  --query ClientIDList
```

## 3. Init, plan, apply

```bash
terraform init                  # backend is fully configured in backend.tf
terraform plan -out=tfplan      # review names and tags here
terraform apply tfplan
```

The first apply takes several minutes while CloudFront deploys. With a custom
domain it also waits for ACM DNS validation.

## 4. Wire up GitHub

```bash
terraform output github_environment_variables   # -> `production` environment variables
terraform output github_repository_variables    # -> repository variables (PR plan check)
```

The first set goes on the GitHub Environment `production` as environment
**variables**. The second set goes on the repository itself for the `terraform-plan` PR
check.
`docs/repo-setup.md` section 5 has the `gh` commands.

## GitHub OIDC trust

Both roles trust the account's existing `token.actions.githubusercontent.com`
provider (owned by another project; this stack only reads it). The repository
has GitHub's **immutable OIDC subject** enabled, so tokens carry
`repo:jwallace145@<user id>/site@<repo id>:...`. The trust policies accept
both that and the plain `repo:jwallace145/site:...` form, so toggling the
setting never breaks deploys. The IDs are plain variables in
`environments/prod/variables.tf`.

| Role                                      | Trusts                                   | Can                                                    |
| ----------------------------------------- | ---------------------------------------- | ------------------------------------------------------ |
| `jwallace145-site-deploy-github-role`      | jobs in the `production` environment     | write the site bucket, invalidate CloudFront           |
| `jwallace145-site-deploy-github-plan-role` | `pull_request` workflows in this repo    | read state and the stack's resources (`terraform plan`) |
| `jwallace145-site-preview-github-role`     | jobs in the `preview` environment        | write `pr-*/` in the preview bucket, invalidate the preview CDN |

## PR plan check

The `terraform-plan` job in `.github/workflows/ci.yml` runs when a PR touches
`infra/**`, assumes the plan role, runs `terraform plan -lock=false` against
prod, and posts the result as a sticky PR comment. It is informational, not a
required check: PRs from forks get no OIDC token, so it only runs for branches
in this repository.

## PR previews

`modules/preview-site` is applied from the prod root when
`preview_enabled = true` (default). One private bucket and one distribution
host every open PR under `pr-<n>/`; a lifecycle rule expires those keys after
`preview_retention_days`. The shared `404.html` at the bucket root is
uploaded by Terraform. Every knob (`preview_*` in
`environments/prod/variables.tf`) is set in the committed `terraform.tfvars`.

After apply: `terraform output github_preview_environment_variables` goes on
the GitHub `preview` environment (`docs/repo-setup.md` section 5c).

## Adding a custom domain later

1. Create the hosted zone in Route 53 and point the registrar at it.
2. Set `domain_name` and `hosted_zone_id` in the committed `terraform.tfvars`, then
   `terraform apply`.
3. Update `SITE_URL` in the GitHub `production` environment and run the
   Release workflow manually to redeploy.

## Cache behaviour

- `_astro/*` (content-hashed): `public, max-age=31536000, immutable`
- HTML: `public, max-age=0, must-revalidate`
- Managed `CachingOptimized` policy; every deploy invalidates `/*`.

## Destroy

```bash
aws s3 rm "s3://$(terraform output -raw site_bucket_name)" --recursive
terraform destroy
```
