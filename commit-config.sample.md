---
description: Repository settings for the /lazy-commit skill — commit grouping, the path-to-scope table, fixed headers, diff exclusions, secret patterns and deploy rules
---

# Commit Config

Repository settings for `/lazy-commit`. The skill reads the sections below by name, so keep the headings. A section with no content uses the skill's default.

<!-- Sample: a filled-in config for an example monorepo with two apps (`apps/web`, `apps/api`), an admin app (`apps/admin`), shared libraries under `libs/`, and SQL migrations under `db/migrations/`. To use it, copy it to `.agents/rules/git/commit-config.md` (the only path the skill reads) and replace the paths, scopes and rules with your repository's. Blank template: `lazy-commit/templates/commit-config.md`, or run `/lazy-commit --init`. -->

## Message rules

`.agents/rules/git/lint-rules.md`

## Grouping

- Atomic path: `libs/`. Every path under it goes into one commit, because the shared libraries are versioned and released together.
- A path outside `libs/` joins the `libs/` commit when the library change needs it to build or run, e.g. a root `package.json` or `tsconfig.base.json` change for a new library dependency.

## Scopes

| Path | Scope | Release |
|---|---|---|
| `apps/web/**` | `web` | yes |
| `apps/api/**` | `api` | yes |
| `apps/admin/**` | `admin` | yes |
| `libs/**` | `shared` | no |
| `db/**` | `db` | no |
| `.github/**`, `.gitlab-ci.yml` | `ci` | no |
| `.claude/**`, `.agents/**`, `AGENTS.md`, `CLAUDE.md` | `ai-agents` | no |
| any other root-level file | none | no |
| any other area | a short lowercase kebab-case name for that area; later commits to the area reuse it | no |

Forbidden scopes:
- `all`: it hides which apps changed. List each affected app's scope instead.
- `frontend`, `backend`: too broad. Use the app scope (`web`, `admin`, `api`).

| When | Scope list |
|---|---|
| Shared library changed | `shared` only; never add app scopes for it |
| Header over the length limit | shorten the subject, then drop the scopes without Release `yes`; still too long → `git reset -q` and stop, listing the scopes |

## Fixed headers

| When all of a commit's paths are under | Header |
|---|---|
| `db/schema/**` | `chore(db): refresh schema backup` |
| `docs/**` | `docs(docs): <subject>`, with only the subject derived from the diff |
| `apps/web/public/locales/**` | `chore(web): update translations` |

## Diff exclusions

`':!dist' ':!**/generated/**' ':!**/__snapshots__/**' ':!db/schema/**'`

## Secrets

- `*.Secrets.json`
- `appsettings.*.local.json`
- `**/credentials.json`

Passwords inside file contents are allowed only in local development connection strings (`localhost` or `127.0.0.1`).

## AI files

`ai-agents` (`.claude/**`, `.agents/**`, `AGENTS.md`, `CLAUDE.md`)

## QA

Write each item as `<app>, <page or endpoint>: <action> and check that <expected result>`. Name the page or endpoint a tester can open, not the source file. For `api`, give the HTTP method and route.

Example: `1) web, Orders page: filter by "Status" and check that only orders with that status are listed`

## Deploy

- A path under `apps/<app>/` → that app.
- A path under `libs/**` → every app whose `package.json` depends on the changed library.
- A `db/migrations/**` path → an item to run that script on the target environment's database before deploying the apps; list it first.

Item format: `<app> ("apps/<app>")`, or for a script: `run "db/migrations/<file>.sql" on the database`.

## Collapse

The project folder directly under `apps/` or `libs/` (e.g. `apps/web/`, `libs/ui/`).
