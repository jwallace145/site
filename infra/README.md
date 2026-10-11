# Infrastructure

Terraform for the site, split into a reusable module and a thin root that
applies it with this project's standards. Applied manually by the owner; CI
runs `terraform fmt -check` and `terraform validate` only.

```
infra/
  modules/static-site/   the module: S3 + CloudFront (OAC), OIDC deploy role, budget
    naming.tf            <prefix>-<domain>-<resource> naming standard, all names in one place
    main.tf              web: site bucket
    cloudfront.tf        web: distribution, headers, function, optional ACM + Route 53
    iam.tf               deploy: OIDC provider and role
    budget.tf            billing: monthly cost alert
    variables.tf  outputs.tf  versions.tf  function/
  live/                  the root you run terraform in
    main.tf              computes names + tags, calls the module
    variables.tf         the simple interface (one required input)
    providers.tf         default_tags carry the standard tags
    backend.tf           S3 backend: jwallace145-site-tfstate, key prod/live/terraform.tfstate
    outputs.tf           values for the GitHub `production` environment
    terraform.tfvars.example
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
| IAM role                      | `jwallace145-site-deploy-github-role`          |
| IAM role policy               | `jwallace145-site-deploy-github-policy`        |
| OIDC provider                 | `jwallace145-site-deploy-github-oidc` (Name tag) |
| Budget                        | `jwallace145-site-billing-monthly`             |

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
so no DynamoDB table is needed. Keys are `<environment>/<stack>/terraform.tfstate`
(this root uses `prod/live/terraform.tfstate`), so one bucket holds every
stack of the project.

The bucket is created outside Terraform by a script that applies the same
standard tags, plus versioning, encryption, public-access block and a
90-day retention for old state versions. Re-running it is safe.

```bash
infra/scripts/bootstrap-state-bucket.sh
```

## 2. Configure

```bash
cd infra/live
cp terraform.tfvars.example terraform.tfvars   # git-ignored
$EDITOR terraform.tfvars                        # set budget_alert_email
```

Everything else defaults to the project standards. Set
`create_oidc_provider = false` if the account already has a provider for
`token.actions.githubusercontent.com`:

```bash
aws iam list-open-id-connect-providers
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
terraform output github_environment_variables
```

Create the GitHub Environment `production` and add each key as an environment
**variable** (none are secret). `docs/repo-setup.md` section 5 has the `gh`
commands.

## Adding a custom domain later

1. Create the hosted zone in Route 53 and point the registrar at it.
2. Set `domain_name` and `hosted_zone_id` in `terraform.tfvars`, then
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
