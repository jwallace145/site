import bodyTrailersOnly from "./tools/commitlint/body-trailers-only.mjs";

// Commit messages are exactly one line: `type(optional-scope): subject`.
// The only thing allowed after the header is git trailers such as
// `Co-authored-by: Name <email>`. Longer explanations belong in the PR.
export default {
  extends: ["@commitlint/config-conventional"],
  plugins: [{ rules: { "body-trailers-only": bodyTrailersOnly } }],
  // Dependabot writes multi-line bodies it can't be configured out of. Only
  // the PR title reaches main (squash merge), and pr-title checks that.
  ignores: [(message) => /^Signed-off-by: dependabot\[bot\] <support@github\.com>$/m.test(message)],
  rules: {
    "header-max-length": [2, "always", 100],
    "type-enum": [
      2,
      "always",
      [
        "feat",
        "fix",
        "docs",
        "style",
        "refactor",
        "perf",
        "test",
        "build",
        "ci",
        "chore",
        "revert",
      ],
    ],
    "body-trailers-only": [2, "always"],
    // Trailers and the one-line rule make these redundant.
    "body-max-line-length": [0],
    "footer-max-line-length": [0],
  },
};
