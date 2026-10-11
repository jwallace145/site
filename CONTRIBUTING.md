# Contributing

Thanks for your interest. This is a personal site, but the tooling is meant to
be reusable and fixes or improvements are welcome.

## Workflow

All changes land through pull requests, including the owner's.

1. Fork the repo and create a branch from `main`.
2. Make your change. Keep PRs focused on one thing.
3. Run the checks (below) and push.
4. Open a PR against `main` with a **conventional commit title** (see next
   section). Fill in the template.
5. CI must be green. The owner reviews and squash-merges.

## Commit messages: one line, nothing else

Every commit on `main` is exactly one line:

```
type(optional-scope): subject
```

- **Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `build`, `ci`, `chore`, `revert`. Breaking changes add `!`: `feat!: ...`.
- Lowercase type and scope, imperative subject, no trailing period, header at
  most 100 characters.
- **No body.** Explanations, context and screenshots go in the PR description.
- **Trailers are allowed** after a blank line, e.g.
  `Co-authored-by: Name <email>` or `Signed-off-by: Name <email>`. Anything
  that is not a `Token: value` line fails commitlint.

Good:

```
feat: add dark mode toggle
fix(blog): sort posts by published date
docs: explain release flow
chore(deps): bump astro to 6.3.0
feat!: require node 24

feat(infra): add budget alert

Co-authored-by: Someone <someone@example.com>
```

Bad:

```
Added dark mode                 # no type
feat: Add dark mode toggle.     # capitalised, trailing period
fix: sort posts

This was broken because ...     # prose body
```

The `commit-msg` hook (lefthook + commitlint) checks this locally, and CI
re-checks every commit in the PR.

### Why the PR title matters

PRs are **squash-merged** with the **PR title as the commit message** and a
blank body. Your individual commits never reach `main`; the title does. So the
title must itself be a valid one-line conventional commit. CI lints it
(`pr-title` check) and Release Please uses it to decide the next version and
write the changelog:

| Title prefix       | Effect on the next release         | In `CHANGELOG.md` |
| ------------------ | ---------------------------------- | ----------------- |
| `feat`             | minor bump                         | Features          |
| `fix`              | patch bump                         | Bug Fixes         |
| `perf`             | patch bump                         | Performance       |
| `revert`           | patch bump                         | Reverts           |
| `docs`             | patch bump                         | Documentation     |
| `type!` / breaking | minor bump while `0.x`, else major | marked breaking   |
| everything else    | no bump on its own                 | hidden            |

## Pull request templates

The default template loads automatically. Type-specific ones exist in
`.github/PULL_REQUEST_TEMPLATE/`; GitHub has no picker for them, so add
`?template=<name>` to the new-PR URL:

- [feature.md](https://github.com/jwallace145/site/compare/main...HEAD?template=feature.md)
- [fix.md](https://github.com/jwallace145/site/compare/main...HEAD?template=fix.md)
- [docs.md](https://github.com/jwallace145/site/compare/main...HEAD?template=docs.md)
- [chore.md](https://github.com/jwallace145/site/compare/main...HEAD?template=chore.md)

Replace `HEAD` with your branch (`owner:branch` from a fork).

## Local setup

```bash
nvm use                    # Node version from .nvmrc
corepack enable            # provides the pinned pnpm, or: npm i -g pnpm
pnpm install               # also installs git hooks via lefthook
cp .env.example .env       # optional: SITE_URL for local builds
pnpm dev                   # http://localhost:4321
```

### Checks that must pass

These run in CI on every PR and (where it makes sense) in the pre-commit hook:

| Command                                                                                | What it checks                                     |
| -------------------------------------------------------------------------------------- | -------------------------------------------------- |
| `pnpm format:check`                                                                    | Prettier formatting (`pnpm format` to fix)         |
| `pnpm lint`                                                                            | ESLint (`pnpm lint:fix` to fix)                    |
| `pnpm check`                                                                           | `astro check`: TypeScript and template diagnostics |
| `pnpm build`                                                                           | Static build succeeds                              |
| `pnpm test`                                                                            | commitlint rule unit tests                         |
| `terraform fmt -check` in `infra/`, `terraform validate` in `infra/environments/prod/` | only when `infra/**` changes                       |

To skip the hooks once (e.g. a WIP commit you will squash): `LEFTHOOK=0 git commit ...`.
CI still enforces everything.

## Releases

Releases are automated and human-gated:

1. Every push to `main` runs **Release Please**, which opens or updates a
   release PR (`chore(main): release X.Y.Z`). The PR bumps `package.json`,
   updates `CHANGELOG.md` from the conventional commits since the last tag,
   and shows exactly what will ship.
2. Nothing merges on its own. The owner merges the release PR when ready.
3. That merge creates the `vX.Y.Z` tag and GitHub Release, and the **deploy**
   job in the same workflow builds that tag and syncs it to S3, then
   invalidates CloudFront.

Versions start at `0.1.0`. While below `1.0.0`, breaking changes bump the
minor version. The `Release` workflow can also be run manually to redeploy
the latest (or a chosen) tag.

Contributors do not need to do anything for releases; just use the right type
in your PR title.

## Project layout

```
src/data/resume.tsx      homepage content (TODO placeholders)
src/data/config.ts       site URL, SEO, theme
src/content/blog/        MDX posts
src/components/          React islands and UI
src/pages/               Astro routes
infra/modules/           static-site Terraform module
infra/environments/prod/              root that applies it (names, tags, backend)
tools/commitlint/        custom commitlint rule + tests
.github/workflows/       ci.yml (PR checks), release.yml (release + deploy)
docs/repo-setup.md       one-time GitHub configuration
```

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). Security
issues go through [private reporting](SECURITY.md), never public issues.
