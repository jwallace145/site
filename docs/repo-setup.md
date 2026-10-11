# Repository setup

One-time GitHub configuration for `jwallace145/site`, as `gh` commands. Run
them as the repository owner (`gh auth status` should show `jwallace145`).
Everything here is idempotent; re-running is safe.

```bash
export REPO=jwallace145/site
```

## 1. Create the repo and push

```bash
gh repo create "$REPO" --public --source=. --remote=origin \
  --description "Personal website. Astro, deployed to S3 + CloudFront." \
  --disable-wiki
git push -u origin main
```

## 2. Repository settings

Squash-only merging with the PR title as the commit message, so `main` stays a
linear history of one-line conventional commits.

```bash
gh repo edit "$REPO" \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge=false \
  --squash-merge-commit-message pr-title \
  --delete-branch-on-merge \
  --allow-update-branch \
  --enable-discussions \
  --enable-issues

# "Allow GitHub Actions to create and approve pull requests", with the
# default GITHUB_TOKEN otherwise read-only (workflows request what they need).
gh api -X PUT "repos/$REPO/actions/permissions/workflow" \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=true

# Private vulnerability reporting (used by SECURITY.md).
gh api -X PUT "repos/$REPO/private-vulnerability-reporting"

# Dependabot security updates on top of the version updates in dependabot.yml.
gh api -X PUT "repos/$REPO/vulnerability-alerts"
gh api -X PUT "repos/$REPO/automated-security-fixes"
```

> `--squash-merge-commit-message pr-title` sets the squash commit title to the
> PR title and leaves the message blank. The other options would append the
> squashed commit list or PR body, which the one-line commit rule forbids.

## 3. Ruleset on `main`

Pull requests required (0 approvals; sole maintainer), linear history, the six
CI checks, up-to-date branches, no force pushes or deletions. The repository
admin role can bypass for emergencies only.

```bash
gh api -X POST "repos/$REPO/rulesets" --input - <<'JSON'
{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] }
  },
  "bypass_actors": [
    { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
  ],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "build" },
          { "context": "check" },
          { "context": "lint" },
          { "context": "pr-title" },
          { "context": "commitlint" },
          { "context": "terraform" }
        ]
      }
    }
  ]
}
JSON
```

`actor_id: 5` is GitHub's fixed ID for the **Repository admin** role. The
status check contexts match the job names in `.github/workflows/ci.yml`.

To update the ruleset later, find its ID and `PUT` the same body:

```bash
gh api "repos/$REPO/rulesets" --jq '.[] | "\(.id) \(.name)"'
gh api -X PUT "repos/$REPO/rulesets/<id>" --input ruleset.json
```

## 4. GitHub App for Release Please

Release PRs opened with the default `GITHUB_TOKEN` do not trigger workflows, so
the required checks would never run on them. A GitHub App token behaves like a
normal user.

1. Open <https://github.com/settings/apps/new>.
2. **Name:** anything unique, e.g. `jwallace145-release-bot`.
   **Homepage URL:** the repo URL. **Webhook:** uncheck _Active_.
3. **Repository permissions:** `Contents: Read and write`,
   `Pull requests: Read and write`. Nothing else.
4. **Where can this app be installed?** Only on this account. Create the app.
5. Note the **Client ID**. Under _Private keys_, **Generate a private key** and
   download the `.pem`.
6. **Install App** (left sidebar) → your account → _Only select repositories_
   → `site`.

Then add the secrets:

```bash
gh secret set RELEASE_BOT_CLIENT_ID --repo "$REPO" --body "<client id>"
gh secret set RELEASE_BOT_PRIVATE_KEY --repo "$REPO" < /path/to/private-key.pem
```

Delete the local `.pem` once stored.

## 5. `production` environment

Created after `terraform apply` in `infra/environments/prod/` (see `infra/README.md`). The values are not
secret, so they are environment **variables**.

```bash
gh api -X PUT "repos/$REPO/environments/production" --input - <<'JSON'
{
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
JSON

# The policy applies to the ref the workflow RUN was triggered from, not to
# what the job checks out. The Release workflow runs from main (push and
# workflow_dispatch); release tags are also allowed for manual dispatch.
gh api -X POST "repos/$REPO/environments/production/deployment-branch-policies" \
  -f name='main' -f type=branch
gh api -X POST "repos/$REPO/environments/production/deployment-branch-policies" \
  -f name='v*' -f type=tag

# From infra/environments/prod/: terraform output github_environment_variables
gh variable set AWS_ROLE_ARN               --env production --repo "$REPO" --body "arn:aws:iam::<account>:role/jwallace145-site-github-deploy"
gh variable set AWS_REGION                 --env production --repo "$REPO" --body "us-east-1"
gh variable set S3_BUCKET                  --env production --repo "$REPO" --body "<site bucket name>"
gh variable set CLOUDFRONT_DISTRIBUTION_ID --env production --repo "$REPO" --body "<distribution id>"
gh variable set SITE_URL                   --env production --repo "$REPO" --body "https://<domain or cloudfront domain>"
```

Optional: add yourself as a required reviewer on the environment for a second
human gate before deploys. Merging the release PR is already the gate, so this
is off by default.

## 5b. Repository variables for the PR plan check

The `terraform-plan` CI job assumes a read-only role on pull requests. These
are **repository** variables (not environment):

```bash
# From infra/environments/prod/: terraform output github_repository_variables
gh variable set AWS_PLAN_ROLE_ARN --repo "$REPO" --body "arn:aws:iam::<account>:role/jwallace145-site-deploy-github-plan-role"
gh variable set AWS_REGION        --repo "$REPO" --body "us-east-1"
```

> This repository has GitHub's immutable OIDC subject enabled
> (`gh api repos/$REPO/actions/oidc/customization/sub`). The IAM trust
> policies in `infra/` accept both the immutable and the plain subject.

## 5c. `preview` environment (PR previews)

Created after `terraform apply` with `preview_enabled = true`. No branch
policy: any PR from this repository may deploy a preview.

```bash
gh api -X PUT "repos/$REPO/environments/preview" --input - <<'JSON'
{ "deployment_branch_policy": null }
JSON

# From infra/environments/prod/: terraform output github_preview_environment_variables
gh variable set AWS_ROLE_ARN               --env preview --repo "$REPO" --body "arn:aws:iam::<account>:role/jwallace145-site-preview-github-role"
gh variable set AWS_REGION                 --env preview --repo "$REPO" --body "us-east-1"
gh variable set S3_BUCKET                  --env preview --repo "$REPO" --body "<preview bucket name>"
gh variable set CLOUDFRONT_DISTRIBUTION_ID --env preview --repo "$REPO" --body "<preview distribution id>"
gh variable set SITE_URL                   --env preview --repo "$REPO" --body "https://<preview cloudfront domain>"
gh variable set PREVIEW_KEY_PREFIX         --env preview --repo "$REPO" --body "pr-"
```

## 6. Verify

```bash
gh repo view "$REPO" --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed,deleteBranchOnMerge
gh api "repos/$REPO/rulesets" --jq '.[].name'
gh secret list --repo "$REPO"
gh variable list --env production --repo "$REPO"
gh variable list --env preview --repo "$REPO"
gh variable list --repo "$REPO"
```

Open a trivial PR (e.g. `docs: test pr checks`) and confirm all six checks
appear and pass, then merge it. Release Please opens the first release PR
(`chore(main): release 0.1.0`); merging it tags `v0.1.0` and deploys.
