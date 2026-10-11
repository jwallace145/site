<!--
Thanks for contributing! A few things to know:

- PRs are squash-merged and the PR TITLE becomes the commit message on main.
  It must be a one-line conventional commit: `type(scope): subject`
  e.g. `feat: add dark mode toggle`, `fix(blog): correct date formatting`
- Put all explanation in this description, not in commit bodies.
- Type-specific templates: append `?template=feature.md`, `fix.md`, `docs.md`
  or `chore.md` to the new-PR URL. See CONTRIBUTING.md.
-->

## Type

- [ ] `feat` – new feature
- [ ] `fix` – bug fix
- [ ] `docs` – documentation only
- [ ] `style` / `refactor` / `perf` – no behaviour change
- [ ] `test` / `build` / `ci` / `chore` – tooling and maintenance
- [ ] Breaking change (`type!:` in the title)

## Summary

<!-- What does this change and why? -->

## Linked issue

<!-- Closes #123 -->

## Testing

<!-- How did you verify this? `pnpm build`, `pnpm check`, manual steps... -->

## Screenshots

<!-- For UI changes: before/after, light and dark mode. Delete if not applicable. -->

## Checklist

- [ ] PR title is a valid one-line conventional commit
- [ ] `pnpm lint`, `pnpm format:check`, `pnpm check` and `pnpm build` pass locally
- [ ] No secrets, account IDs or personal data were added
