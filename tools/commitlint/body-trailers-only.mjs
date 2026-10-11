/**
 * commitlint rule: everything after the header must be a git trailer.
 *
 * A trailer is a line of the form `Token: value`, e.g.
 *   Co-authored-by: Name <email>
 *   Signed-off-by: Name <email>
 *
 * Blank lines and comment lines (`#`, left by `git commit` editors) are
 * ignored. Any other line fails the rule, so free-form bodies are rejected.
 */
export const TRAILER_PATTERN = /^[A-Za-z][A-Za-z-]*: .+$/;

/**
 * @param {{ raw?: string | null }} parsed
 * @param {'always' | 'never'} [when]
 * @returns {[boolean, string]}
 */
export default function bodyTrailersOnly(parsed, when = "always") {
  const raw = parsed.raw ?? "";
  const [, ...rest] = raw.split(/\r?\n/);

  const offending = rest
    .map((line) => line.trimEnd())
    .filter((line) => line.trim() !== "" && !line.startsWith("#"))
    .filter((line) => !TRAILER_PATTERN.test(line));

  const passes = offending.length === 0;
  const negated = when === "never";

  return [
    negated ? !passes : passes,
    negated
      ? "body must contain something other than trailers"
      : `commit message must be a single line; only trailers (e.g. "Co-authored-by: Name <email>") may follow it. Offending line(s): ${offending
          .map((l) => JSON.stringify(l))
          .join(", ")}`,
  ];
}
