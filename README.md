# site

Personal website of Jimmy Wallace. A static [Astro](https://astro.build) site
served from AWS S3 + CloudFront, released with Release Please and deployed by
GitHub Actions.

**Live:** <!-- TODO: live URL --> `https://example.com`

[![CI](https://github.com/jwallace145/site/actions/workflows/ci.yml/badge.svg)](https://github.com/jwallace145/site/actions/workflows/ci.yml)
[![Release](https://github.com/jwallace145/site/actions/workflows/release.yml/badge.svg)](https://github.com/jwallace145/site/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Stack

| Layer   | Choice                                                                                                  |
| ------- | ------------------------------------------------------------------------------------------------------- |
| Site    | Astro (static output), TypeScript, React islands, Tailwind CSS v4, MDX                                  |
| Tooling | pnpm (pinned via `packageManager`), Node LTS (`.nvmrc`), ESLint, Prettier, commitlint, lefthook, Vitest |
| Hosting | S3 (private, OAC) + CloudFront, Terraform module in [`infra/`](infra/)                                  |
| CI/CD   | GitHub Actions: PR checks, Release Please, OIDC deploy                                                  |

## Local development

```bash
nvm use
corepack enable          # or: npm i -g pnpm
pnpm install             # installs git hooks too
pnpm dev                 # http://localhost:4321
```

| Command                     | Action                            |
| --------------------------- | --------------------------------- |
| `pnpm build`                | Static build into `dist/`         |
| `pnpm preview`              | Serve `dist/` locally             |
| `pnpm check`                | `astro check` (types + templates) |
| `pnpm lint` / `pnpm format` | ESLint / Prettier                 |
| `pnpm test`                 | commitlint rule tests             |

Content lives in three places; search for `TODO:` to find every placeholder.

| File                     | Controls                                                   |
| ------------------------ | ---------------------------------------------------------- |
| `src/data/resume.tsx`    | Name, bio, work, education, projects, skills, social links |
| `src/data/config.ts`     | Site URL, SEO, theme colours, font size                    |
| `src/content/blog/*.mdx` | Blog posts (`example-post.mdx` is a template)              |

The public URL comes from the `SITE_URL` environment variable (see
`.env.example`); it falls back to the placeholder in `src/data/config.ts`.

## Release and deploy flow

Every change is a PR, squash-merged into `main` as a single one-line
[conventional commit](https://www.conventionalcommits.org). From there:

```
  PR merged into main
          │
          ▼
  release.yml: Release Please
  opens / updates "chore(main): release X.Y.Z"
  (version bump + CHANGELOG.md)
          │
          │  owner reviews and merges the release PR   ◄── the only manual gate
          ▼
  release.yml on that merge:
    tag vX.Y.Z + GitHub Release
          │
          ▼
  deploy job (environment: production)
    checkout tag → pnpm build → OIDC → aws s3 sync → CloudFront invalidation
          │
          ▼
  live site
```

- Release PRs are never auto-merged. Merging one _is_ the release.
- The deploy job assumes an AWS role via OIDC; there are no long-lived keys.
- `workflow_dispatch` on the Release workflow redeploys the latest (or a given) tag.
- Details: [CONTRIBUTING.md](CONTRIBUTING.md), [infra/README.md](infra/README.md),
  [docs/repo-setup.md](docs/repo-setup.md).

## Repository layout

```
src/                 Astro site
infra/modules/       static-site Terraform module (S3, CloudFront, OIDC role, budget)
infra/live/          thin root that applies the module with this project's names and tags
tools/commitlint/    custom "one-line commit" rule and its tests
.github/             workflows, composite setup action, templates, dependabot
docs/repo-setup.md   one-time GitHub configuration (gh commands)
```

## Credits

Built from the [Starfolio](https://github.com/webrating/starfolio) Astro
template by [webrating](https://github.com/webrating), itself a port of the
[dillionverma/portfolio](https://github.com/dillionverma/portfolio) design.
Both are MIT licensed; their notices are retained in [NOTICE](NOTICE).

## License

[MIT](LICENSE) © 2026 Jimmy Wallace. See [NOTICE](NOTICE) for upstream notices.
