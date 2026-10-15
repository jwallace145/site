# Infrastructure

Terraform for serving <https://jwall.engineering/> from S3 + CloudFront in the
jwall-engineering AWS account (`650503560686`, `us-east-1`). Applied by CI only, when a
Release Please release PR is merged. Nobody runs `terraform apply` locally.

## What it creates

Two module blocks from the public registry module
[`jwallace145/jwall-engineering/aws`](https://registry.terraform.io/modules/jwallace145/jwall-engineering/aws/latest),
pinned to an exact version in `context.tf` and `main.tf`:

| Module | Creates |
| --- | --- |
| `context` | Nothing. Derives the tag set for the provider's `default_tags` and the bucket name `jwall-engineering-main-site`. The `Project` tag is what the apply role's IAM policy keys on. |
| `site` (root module) | ACM certificate, CloudFront distribution, index-rewrite function and Route 53 alias for `jwall.engineering` served from `<bucket>/prod`; a wildcard certificate and distribution for `*.preview.jwall.engineering` served from `<bucket>/previews/pr-<n>`. |

The bucket, the three CI roles and the hosted zone are owned by
[`jwallace145/jwall-engineering-infra`](https://github.com/jwallace145/jwall-engineering-infra),
which registers this site under the project key `main-site` in `projects.tf`. This stack
only references them. There is no `dev` environment; the apply role is only allowed to
change the production and preview record names.

| File | Owns |
| --- | --- |
| `versions.tf`, `providers.tf` | Terraform `>= 1.11`, AWS provider `~> 6.0`, region, `default_tags` |
| `backend.tf`, `backend/prod.hcl` | State in `jwall-engineering-tfstate` at `project=main-site/env=prod/main-site-prod.tfstate`, native lockfile locking |
| `context.tf`, `main.tf` | The two module blocks |
| `variables.tf`, `terraform.tfvars` | `domain_name` and `zone_id`. The zone ID is hardcoded because the CI roles may not list hosted zones. |
| `outputs.tf` | Bucket name and production distribution ID; the deploy workflow reads them with `terraform output -raw` |
| `.terraform.lock.hcl` | Provider checksums for `linux_amd64` (CI) and `darwin_arm64` (local) |
| `.tflint.hcl` | tflint rules, same as the infra repo |

Not provided by the module, and therefore gone since the migration: the `www.` redirect
to the apex, the monthly budget alert, and the custom security-headers policy of the old
local modules.

## Bucket layout

| Prefix | Served at | Written by |
| --- | --- | --- |
| `prod/` | `https://jwall.engineering/` | the `deploy` job in `release.yml`, with the apply role |
| `previews/pr-<n>/` | `https://pr-<n>.preview.jwall.engineering/` | `preview.yml`, with the preview role; removed when the PR closes, and expired after 14 days by lifecycle rule |

## CI roles

Three IAM roles, created by the infra repo, assumed through GitHub OIDC. No long-lived
keys anywhere.

| Role | Repository variable | Trusted OIDC subject | Used by |
| --- | --- | --- | --- |
| `jwall-engineering-main-site-ci-plan` | `AWS_PLAN_ROLE_ARN` | `pull_request` | `terraform-plan` job in `ci.yml` |
| `jwall-engineering-main-site-ci-preview` | `AWS_PREVIEW_ROLE_ARN` | `pull_request` | `preview.yml` |
| `jwall-engineering-main-site-ci-apply` | `AWS_APPLY_ROLE_ARN` | `environment:prod` | `deploy` job in `release.yml` |

The plan and preview jobs must **not** declare a GitHub environment: that would change
the OIDC subject to `environment:<name>` and the role assumption would fail. The deploy
job must run in the `prod` environment for the same reason.

## Workflows

- **Pull requests** (`ci.yml`): `terraform` runs `fmt`, `validate` and `tflint` without
  credentials and always runs, so it can be a required check. `terraform-plan` runs only
  when `infra/` changed, assumes the plan role and posts the plan as a comment that is
  replaced on every push. The plan is skipped for fork PRs.
- **Pull requests** (`preview.yml`): builds the site, syncs it to `previews/pr-<n>/` and
  comments the preview URL; deletes the prefix when the PR closes.
- **Release** (`release.yml`): when a release PR is merged, the `deploy` job checks out the
  tag, runs `terraform apply`, builds the site, syncs it to `prod/` with tiered
  `Cache-Control` and invalidates `/*` on the production distribution.
  `workflow_dispatch` redeploys the latest or a given tag.

Merging to `main` does not deploy. A merged change goes live with the next release PR.

## Local commands

```sh
cd infra
terraform fmt -check -recursive
terraform init -backend=false      # fetches the registry module, no credentials
terraform validate
tflint --init && tflint
```

A real plan needs the plan role or equivalent read-only credentials:
`terraform init -backend-config=backend/prod.hcl && terraform plan`. Never apply locally.

## Upgrading the module

Dependabot's `terraform` ecosystem opens a `chore(deps)` PR when the registry module
publishes a release. The plan comment on that PR shows what the new version changes in
AWS. Read the module's
[CHANGELOG](https://github.com/jwallace145/terraform-aws-jwall-engineering/blob/main/CHANGELOG.md),
check the plan, merge; the change applies with the next release. Keep the two pins
identical.

## Owner hand-off and cutover

This site used to be managed by local Terraform modules in this directory (bucket
`jwall-engineering-site-web-bucket`, state in `jwall-engineering-site-tfstate`). The new
stack creates a fresh set of resources, and both stacks cannot own the same names, so the
old one is destroyed first. Expect a few minutes of downtime between step 4 and step 6
(ACM validation and CloudFront creation). One-time steps that need the owner's credentials
or the GitHub UI, in order:

1. **Infra repo applied** with `main-site` in `projects.tf` (it is). Confirm the bucket
   `jwall-engineering-main-site` and the three `jwall-engineering-main-site-ci-*` roles
   exist.

2. **`prod` environment and repository variables**: the `gh` commands are in
   `docs/repo-setup.md` section 5. Until they are set, previews and the plan comment on
   the migration PR fail to assume a role.

3. **Merge the migration PR.** Nothing deploys yet; Release Please opens a release PR.
   (The old stack keeps serving the site.)

4. **Destroy the old stack** from a checkout of the last commit that still has it
   (`16acbbc`), using the old admin profile:

   ```sh
   git worktree add ../site-old 16acbbc
   cd ../site-old/infra/environments/prod
   export AWS_PROFILE=prog-strength-admin
   terraform init
   terraform output resource_names                 # confirm the two bucket names below
   aws s3 rm s3://jwall-engineering-site-web-bucket --recursive
   aws s3 rm s3://jwall-engineering-site-preview-bucket --recursive
   terraform plan -destroy   # check: no hosted zone, only site and preview resources
   terraform destroy
   ```

   The zone is not in that state (it moved to the infra repo), so the destroy removes only
   the distributions, certificates, buckets, IAM roles, budget and the apex, `www` and
   `preview` records.

5. **Merge the release PR** immediately afterwards (or re-run the Release workflow with
   `workflow_dispatch`). The deploy job creates the certificates, distributions and
   records, builds the tag and syncs it to `prod/`. If it fails waiting on ACM validation,
   re-run it.

6. **Verify** <https://jwall.engineering/> and a PR preview at
   `https://pr-<n>.preview.jwall.engineering/`.

7. **Afterwards**: delete the `production` and `preview` GitHub environments and the
   repository variable `AWS_REGION` (`gh api -X DELETE repos/jwallace145/site/environments/production`,
   likewise `preview`), delete the old state bucket `jwall-engineering-site-tfstate`, and
   add `terraform` to the `main` ruleset's required checks if it is not there already.
   `www.jwall.engineering` no longer resolves; add a redirect to the registry module if
   it is wanted back.
