# lazy-commit

Claude Code skills that commit every change on the current branch as [Conventional Commits](https://www.conventionalcommits.org/), grouped by scope. You see the proposed commits and approve them before anything is committed. Pass `-f` to skip the approval step.

## Skills

| Skill | What it does |
|---|---|
| `/lazy-commit` | The main skill. It groups the changes into commits, writes the messages, asks for approval, then commits. |
| `/lazy-commit-no-graphify` | Alias for `/lazy-commit -f --skip-graphify` |
| `/lazy-commit-guidelines` | Alias for `/lazy-commit -f --qa-guideline --deploy-guideline --skip-graphify` |

The two aliases run only when you type them. Claude never picks them on its own.

## Installation

Copy the three skill folders into your personal Claude Code skills directory:

```bash
# macOS / Linux / Git Bash
cp -r lazy-commit lazy-commit-no-graphify lazy-commit-guidelines ~/.claude/skills/
```

```powershell
# PowerShell
Copy-Item -Recurse lazy-commit, lazy-commit-no-graphify, lazy-commit-guidelines "$env:USERPROFILE\.claude\skills\"
```

The aliases call `lazy-commit` and need it installed at `~/.claude/skills/lazy-commit/`. The skill needs git 2.25 or later and bash (on Windows, the Git Bash that Claude Code uses).

## Usage

```
/lazy-commit [--init [path]] [-f] [--skip-graphify] [--qa-guideline] [--deploy-guideline] [additional instructions]
```

| Option | Effect |
|---|---|
| `--init` | Creates `.agents/rules/git/commit-config.md` from the template and exits without committing |
| `-f` | Commits right away without asking. Passing it counts as your approval |
| `--skip-graphify` | Leaves changes under `graphify-out/` uncommitted |
| `--qa-guideline` | Adds a `QA:` list of test checks to the body of each releasing commit |
| `--deploy-guideline` | Adds a `Deploy:` list of projects and database scripts to the body of each releasing commit |

Anything else you type is passed to the skill as extra instructions, for example `/lazy-commit put the docs changes in one commit`.

### How it works

1. **Propose.** Stages all changes and stops if any staged path looks like a secret. Groups the changes into commits by scope and writes each header from the paths and line counts, reading a capped content diff only when they aren't enough. Before you see the proposal, the helper script checks that every file is in exactly one commit and that every header fits the length limit.
2. **Ask.** Shows every commit message and file list and asks "Use these commits?". If you answer **No**, give a reason and the skill revises the proposal.
3. **Commit.** Stages and commits each group in order, using the exact message you approved. If the changes differ from what you approved, nothing is committed and you get a new proposal.

The git steps run through `lazy-commit/scripts/lazy-commit.sh` (`stage`, `plan`, `commit`, `init`), so the whole commit step is a single tool call.

### Grouping rules

- Changes under an *atomic path*, set in the config, always go into one commit.
- All other changes are grouped by scope. Groups that form one logical change are merged.
- `graphify-out/` always gets its own last commit, `chore(graphify): refresh knowledge graph`.
- Commit order: atomic commits first, then the rest sorted alphabetically by header, then `graphify-out/`.

### Safety

- Refuses to commit on `main` or `master`, on a detached HEAD, or while a merge, rebase, cherry-pick or revert is unfinished.
- Blocks secret-looking paths: `.env`, `.env.*` (except `.env.example`), `*.pfx`, `*.p12`, `*.key`, `*.pem`, plus any patterns in the config.
- Never uses `--no-verify`, `--amend`, `push`, `reset --hard`, `checkout -- .` or `clean`.
- Never adds trailers such as `Co-Authored-By` or `Signed-off-by`, and never mentions AI in commit messages.
- If a hook such as commitlint rejects a commit, the skill doesn't retry silently. It shows the hook output and proposes a fixed message.

## Project config

Run `/lazy-commit --init` to create `.agents/rules/git/commit-config.md` from [`lazy-commit/templates/commit-config.md`](lazy-commit/templates/commit-config.md). Every section is optional. A section you leave as its HTML comment keeps the default.

| Section | Sets | Default |
|---|---|---|
| Message rules | Rules file: types, which types release, subject rules, header length | `@commitlint/config-conventional` with a 100-character limit; `feat`, `fix`, `perf` and `revert` release |
| Grouping | Atomic paths, and the outside paths that join their commit | None |
| Scopes | Path-to-scope table, release scopes, forbidden scopes | Kebab-case name per top-level area |
| Fixed headers | Paths that always get a fixed header | None |
| Diff exclusions | Generated paths whose content diff is never read | Lockfiles, minified files, `graphify-out` |
| Secrets | Extra secret patterns; whether secrets inside file contents may be committed | Built-in patterns only |
| AI files | Scope whose commits may name agent or skill files | Commits that change only `AGENTS.md`, `CLAUDE.md`, `.claude/**` or `.agents/**` |
| QA | Guidance and an example item for `QA:` bodies | None |
| Deploy | How to find deployable projects, and the item format | Apps containing the changed paths, plus apps that depend on changed shared libraries |
| Collapse | Directory unit for collapsing file lists longer than 20 files | Top-level directory |

The config can add rules but can't loosen the safety rules or the approval step.

For a filled-in example covering every section, see [`commit-config.sample.md`](commit-config.sample.md). It is written for a monorepo with apps under `apps/`, shared libraries under `libs/` and migrations under `db/migrations/`.

## Example

```
Proposed commits (2):

1. feat(api,web): add order status filter
   Files (3):
   M  apps/api/src/orders.ts
   M  apps/web/src/OrdersPage.tsx
   A  apps/web/src/StatusFilter.tsx

2. chore(graphify): refresh knowledge graph
   Files (1):
   M  graphify-out/graph.json
```

With `--qa-guideline --deploy-guideline`, a releasing commit's message looks like this:

```
feat(web): add order status filter

QA:
1) web, Orders page: filter by "Status" and check that only orders with that status are listed

Deploy:
1) web ("apps/web")
```

## Layout

```
lazy-commit/
├── lazy-commit/
│   ├── SKILL.md                  # main workflow
│   ├── scripts/
│   │   └── lazy-commit.sh        # git helper: stage, plan, commit, init
│   ├── references/
│   │   └── guidelines.md         # QA and Deploy body rules, read only with those options
│   └── templates/
│       └── commit-config.md      # template written by --init
├── lazy-commit-guidelines/
│   └── SKILL.md                  # alias: -f --qa-guideline --deploy-guideline --skip-graphify
└── lazy-commit-no-graphify/
    └── SKILL.md                  # alias: -f --skip-graphify
```
