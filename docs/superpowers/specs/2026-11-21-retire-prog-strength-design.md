# Retire Prog Strength

**Date:** 2026-11-21
**Status:** approved and implemented

## Why

Prog Strength is retired only to stop paying for hosting while I work on
other projects. Nothing was wrong with it. It is one of four public projects
and one I am proud of, so it stays in the portfolio. Everywhere a visitor
might land (this site, the GitHub org, any repo, and progstrength.fitness
until it lapses) should say plainly that it is offline on purpose and where
the code and data live.

## Goals

- The project card shows Prog Strength as archived, with its own branding,
  and keeps the technical pitch.
- The GitHub org page and every repository say it was retired on purpose and
  point to `prog-strength-archive` for the data.
- Every repository except `.github` is archived (read-only).
- progstrength.fitness redirects to this site's projects section until the
  domain expires on 2027-05-08. It will not be renewed.

## Non-goals

- Tearing down infrastructure. `api.progstrength.fitness` still answers
  (v0.118.1, "service is healthy") at the time of writing; that is the
  owner's to shut down.
- Changing the archive bucket (storage class, lifecycle).
- Rewriting repository READMEs beyond the notice at the top.

## Anti-goals

- Reading as abandoned or failed. The wording is "retired on purpose to cut
  hosting costs", never "dead" or "discontinued".
- Losing the code. `prog-strength-web` keeps its real app on `main`; the
  redirect is a separate deploy.
- Leaving links we control pointing at progstrength.fitness after it lapses,
  when anyone could register it.

## Approaches: showing "archived" on the card

1. **An "Archived" badge beside the dates**, driven by the existing (unused)
   `active` flag on each project. Visible at a glance and matches the word
   GitHub shows on archived repos. Small component change plus a test.
   **Chosen** (my call; not explicitly picked).
2. "Archived" written into the dates string. No code change, easy to miss.

## Design

### This site (one PR from `feat/retire-prog-strength`)

- **Thumbnail** `public/projects/prog-strength-thumbnail.png`: 1600×1000 like
  the others, black background, a faint dot grid matching the other
  thumbnails' spacing, and the white P mark from
  `Prog-Strength/prog-strength-web/public/prog-strength-icon.svg` centered.
  Rendered from an SVG with `sharp` (already a dependency).
- **Card** in `src/data/resume.tsx`: dates `May 2026 - November 2026`,
  `active: false`, `href` the GitHub org, links `GitHub` (org) and `Archive`
  (`prog-strength-archive`), the thumbnail, and the description in the past
  tense ending with one line on why it is offline. The website link goes.
  The description stays within `PROJECT_DESCRIPTION_MAX_CHARS`.
- **ProjectCard** takes an optional `active` prop; `active === false` renders
  an "Archived" badge beside the dates. `projects-section.tsx` passes it. A
  test in `project-card.test.tsx` covers badge and no badge.
- **Other copy**: the tagline drops "Founder of Prog Strength"; the About
  summary names JAWS and Braveheart as current side projects and Prog
  Strength as past work; the Contact blurb drops "or Prog Strength".

### GitHub

Order matters: archived repositories are read-only, so notices go in first.

1. **Notice** at the top of every repository's README except `.github`
   (12 repositories: the 11 public ones plus the private
   `prog-strength-data`). `prog-strength-developer` is already archived, so
   it is unarchived, given the notice, and archived again. A repository with
   no README gets one holding the notice. `prog-strength-archive` already
   explains itself and gets a repository description only. The notice:

   > [!NOTE]
   > **Prog Strength was retired in November 2026.** It is offline on
   > purpose, to cut hosting costs, and this repository is archived as
   > read-only. progstrength.fitness no longer serves the app. The database,
   > media, and infrastructure state are kept in cold storage; see
   > [prog-strength-archive](https://github.com/Prog-Strength/prog-strength-archive).

   Committed straight to `main` with `[skip ci]` in the message, so no
   release or deploy workflow runs against torn-down infrastructure.

2. **Homepage fields** that point at progstrength.fitness are cleared.
3. **Archive** all 12.
4. **Org profile** (`.github/profile/README.md`, not archived): the logo at
   the top (the black-square PNG from `prog-strength-web`, copied into
   `profile/` so it renders in light and dark themes), the retirement notice,
   a rewritten Status section, and the "live at progstrength.fitness" line
   removed.
5. **Org settings**: description says it was retired in November 2026 and
   where the code and data are; the website link moves from
   progstrength.fitness to `https://jwall.engineering/#projects`.

### progstrength.fitness

A redirect-only Vercel project (a `vercel.json`, no app) takes
`progstrength.fitness` and `www.progstrength.fitness` off the
`prog-strength-web` project and sends every path to
`https://jwall.engineering/#projects` with a temporary redirect. Needs a
one-time `vercel login`. After the domain lapses in May 2027 the Vercel
project can be deleted; nothing else depends on it.

## Left to the builder

- Exact wording of the card description, About summary, notice, and org
  description, within the tone above.
- Thumbnail dot spacing and logo size.
