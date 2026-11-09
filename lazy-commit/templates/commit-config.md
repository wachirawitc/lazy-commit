---
description: Repository settings for the /lazy-commit skill — commit grouping, the path-to-scope table, fixed headers, diff exclusions, secret patterns and deploy rules
---

# Commit Config

Repository settings for `/lazy-commit`. The skill reads the sections below by name, so keep the headings. A section with no content uses the skill's default.

<!-- Text inside HTML comments is guidance for whoever edits this file; the skill ignores it. Replace a section's comment with your settings, or leave the comment to keep the default. -->

## Message rules

<!-- The file with your commit message rules: allowed types, which types release, subject rules, header length limit. Example: `.agents/rules/git/lint-rules.md`.
Default: Conventional Commits 1.0.0 types; `feat`, `fix`, `perf` and `revert` release; lowercase imperative subject without a final period; header of at most 100 characters. -->

## Grouping

<!-- Atomic paths, whose changes always go into one commit, with the reason, and the outside paths that join that commit. Example:
- Atomic path: `src/`. Every path under it goes into one commit, because a shared library change and the apps that depend on it are built and released together.
- A path outside `src/` joins the `src/` commit when the `src/` change needs it to build or run, e.g. a `package.json` dependency bump that changes compiled output under `src/`.
Default: no atomic paths. -->

## Scopes

<!-- The path-to-scope table; Release `yes` marks the scopes your release tooling releases. When several rows match a path, the most specific one wins. Below the table, list forbidden scopes (with the reason and what to use instead) and adjustments to the scope list, checked in order. Example:

| Path | Scope | Release |
|---|---|---|
| `apps/web/**` | `web` | yes |
| `apps/api/**` | `api` | yes |
| `libs/**` | `shared` | no |
| any other root-level file | none | no |
| any other area | a short lowercase kebab-case name for that area; later commits to the area reuse it | no |

Forbidden scopes:
- `all`: it hides which apps changed. List each affected app's scope instead.

| When | Scope list |
|---|---|
| Shared library changed | `shared` only; never add app scopes for it |
| Header over the length limit | shorten the subject, then drop the scopes without Release `yes`; still too long → `git reset -q` and stop, listing the scopes |

Default: a short lowercase kebab-case name per area (the top-level folder, or the package or project folder inside it), in the scope style of `git log`; no scope for root-level files. -->

## Fixed headers

<!-- Paths whose commits always get a fixed header, or a fixed type and scope. Example:

| When all of a commit's paths are under | Header |
|---|---|
| `db/schema/**` | `chore(db-schema): refresh schema backup` |
| `docs/**` | `docs(docs): <subject>`, with only the subject derived from the diff |

Default: none. -->

## Diff exclusions

<!-- Generated paths whose content diff is never read, as git pathspecs. Example: `':!dist' ':!**/generated/**'`.
Default: none; the skill always excludes `graphify-out`, `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `*.min.js` and `*.min.css`. -->

## Secrets

<!-- Extra secret path patterns, and whether secrets inside file contents may be committed. Example:
- `*.Secrets.json`
Passwords inside file contents are allowed only in local development connection strings.
Default: none; the skill always blocks `.env`, `.env.*` (except `.env.example`), `*.pfx`, `*.p12`, `*.key` and `*.pem`, by path only. -->

## AI files

<!-- The scope whose commits may name the agent, skill or rule files they change. Example: `ai-agents` (`.claude/**`, `AGENTS.md`, `CLAUDE.md`).
Default: commits that change only AI agent files (`AGENTS.md`, `CLAUDE.md`, `.claude/**`, `.agents/**`). -->

## QA

<!-- Project guidance and an example item for the `QA:` body (`--qa-guideline`). Example: `1) web, Orders page: filter by "Status" and check that only orders with that status are listed`.
Default: none. -->

## Deploy

<!-- How to find a commit's deployable projects and database scripts (`--deploy-guideline`), and the item format. Example:
- A path under `apps/<app>/` → that app.
- A path under `libs/**` → every app that depends on the changed library.
- A `db/migrations/**` path → an item to run that script on the target environment's database before deploying the apps.
Default: each deployable app or service that contains a commit path, plus those that depend on a changed shared library; database migration scripts first. -->

## Collapse

<!-- The directory unit for collapsing a commit's file list when it has more than 20 files. Example: the project folder directly under `src/`.
Default: the top-level directory; under an atomic path, the project folder directly inside it. -->
