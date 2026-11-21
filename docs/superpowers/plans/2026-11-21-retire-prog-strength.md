# Retire Prog Strength Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show Prog Strength as an archived portfolio project on this site, mark and archive every Prog-Strength repository, and redirect progstrength.fitness here until it lapses.

**Architecture:** Site changes are data plus one optional card prop. GitHub changes go through `gh api` in a fixed order (notice, homepage, archive) because archived repositories are read-only. The redirect is a standalone Vercel project holding only `vercel.json`.

**Tech Stack:** Astro, React, Vitest, sharp; `gh` CLI; Vercel CLI.

**Spec:** `docs/superpowers/specs/2026-11-21-retire-prog-strength-design.md`

## Global Constraints

- Tone: "retired on purpose to cut hosting costs", never "dead" or "discontinued".
- Card dates: `May 2026 - November 2026`. Description ≤ `PROJECT_DESCRIPTION_MAX_CHARS` (550).
- Nothing we control links to progstrength.fitness afterwards.
- Commit messages: one conventional header line, then trailers only (commitlint `body-trailers-only`).
- Every commit to a Prog-Strength repository carries `[skip ci]` in its message; `prog-strength-infra` runs `terraform apply` on push to `main`.
- `.github` is never archived.

## Review Focus

- `active` omitted (every other project) must render no badge: covered in Task 1.
- A project link or the About copy still pointing at progstrength.fitness: pinned by a test in Task 2.
- The card description growing past 550 characters: existing `resume.test.ts`.
- A `[skip ci]` missing from an infra merge would run `terraform apply`: Task 4 squashes with an explicit subject.
- Light theme on GitHub: the org logo must be the black-square PNG, not the white-only SVG (Task 5).

---

### Task 1: "Archived" badge on ProjectCard

**Files:**

- Modify: `src/components/project-card.tsx`, `src/components/section/projects-section.tsx`
- Test: `src/components/project-card.test.tsx`

**Interfaces:**

- Produces: `ProjectCard` prop `active?: boolean`; `active === false` renders a badge with text `Archived`.

- [ ] **Step 1:** Add tests `renders an Archived badge when active is false` (markup contains `>Archived<`) and `renders no badge when active is omitted` (markup lacks `Archived`).
- [ ] **Step 2:** `pnpm test` → the first fails.
- [ ] **Step 3:** Add the prop; render an outline `Badge` beside the `<time>`; pass `active={project.active}` from `projects-section.tsx`.
- [ ] **Step 4:** `pnpm test` → pass.
- [ ] **Step 5:** Commit `feat: show an Archived badge on retired projects`.

### Task 2: Prog Strength card, thumbnail, and copy

**Files:**

- Create: `public/projects/prog-strength-thumbnail.png` (1600×1000)
- Modify: `src/data/resume.tsx`
- Test: `src/data/resume.test.ts`

- [ ] **Step 1:** Add test `nothing links to progstrength.fitness`: no project `href`, no link `href`, and neither `DATA.summary` nor `DATA.description` contains `progstrength.fitness`.
- [ ] **Step 2:** `pnpm test` → fails.
- [ ] **Step 3:** Render the thumbnail with sharp from an SVG: black background, dot grid at the other thumbnails' 56px pitch in `#262626`, the P path from `prog-strength-web/public/prog-strength-icon.svg` in white, centered, about 560px tall.
- [ ] **Step 4:** Update the card per the spec (dates, `active: false`, `href` `https://github.com/Prog-Strength`, links `GitHub` → org and `Archive` → `https://github.com/Prog-Strength/prog-strength-archive`, image, past-tense description). Update `description`, `summary`, and `sections.contact.text`.
- [ ] **Step 5:** `pnpm test && pnpm lint && pnpm check && pnpm build` → pass; the built `dist/index.html` contains `Archived` and `prog-strength-thumbnail.png`.
- [ ] **Step 6:** Commit `feat: retire Prog Strength as an archived portfolio project`, plus `docs: add the Prog Strength retirement design and plan`. Push and open a PR.

### Task 3: Notices on every repository README

Repositories: `prog-strength-infra`, `-developer`, `-web`, `-docs`, `-api`, `-agent`, `-mcp`, `-tooling`, `-mobile`, `-data`, `-sdk`. (`prog-strength-archive` gets a description only.)

- [ ] **Step 1:** Unarchive `prog-strength-developer` (`PATCH archived=false`).
- [ ] **Step 2:** For each repository except infra: prepend the spec's notice to the README (create `README.md` with a title plus the notice where none exists) through `PUT /contents`, message `docs: mark the repository retired [skip ci]`.
- [ ] **Step 3:** For infra: branch, same change, PR, `gh pr merge --squash --subject "docs: mark the repository retired [skip ci]"`.
- [ ] **Step 4:** Verify each README now starts with the notice and no workflow run was created by these commits (`gh run list -L 3` per repository).

### Task 4: Homepages, descriptions, archive

- [ ] **Step 1:** Clear `homepage` on `-developer`, `-web`, `-api`, `-agent`, `-mcp`.
- [ ] **Step 2:** Set the `prog-strength-archive` description: `Cold archive of Prog Strength (retired November 2026): what is stored, where, and how to restore it.`
- [ ] **Step 3:** `PATCH archived=true` on all 12; verify with `gh repo list Prog-Strength --json name,isArchived`.

### Task 5: Org profile and settings

- [ ] **Step 1:** Copy `prog-strength-web/public/prog-strength-logo.png` to `.github/profile/prog-strength-logo.png`.
- [ ] **Step 2:** Rewrite the top of `profile/README.md` (logo, notice) and its Status section; remove "live at progstrength.fitness".
- [ ] **Step 3:** `PATCH /orgs/Prog-Strength` description and `blog` → `https://jwall.engineering/#projects` (needs the `admin:org` scope; if missing, ask the owner to run `gh auth refresh -h github.com -s admin:org`).

### Task 6: progstrength.fitness redirect

- [ ] **Step 1:** In a scratch directory, `vercel.json` with one redirect `/(.*)` → `https://jwall.engineering/#projects`, `permanent: false`.
- [ ] **Step 2:** Find the project holding the domain (`vercel domains inspect progstrength.fitness`); remove `progstrength.fitness` and `www.progstrength.fitness` from it.
- [ ] **Step 3:** `vercel deploy --prod` the scratch directory as project `progstrength-redirect`; add both domains to it.
- [ ] **Step 4:** `curl -sI https://progstrength.fitness/anything` → 307 with `location: https://jwall.engineering/#projects`; same for `www`.
