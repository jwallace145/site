# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Use GitHub's private vulnerability reporting instead:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Describe the issue, how to reproduce it, and its impact.

Or open the form directly:
<https://github.com/jwallace145/site/security/advisories/new>

You should get an acknowledgement within a week. Once a fix is released the
advisory is published and you are credited unless you ask otherwise.

## Scope

- The site source in this repository
- The GitHub Actions workflows under `.github/workflows/`
- The Terraform under `infra/`

Third-party dependencies should be reported to their maintainers; a heads-up
here is still welcome so the pin can be bumped quickly.

## Supported versions

Only the latest release deployed from `main` is supported.
