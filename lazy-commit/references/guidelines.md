# QA and Deploy bodies

Read this only with `--qa-guideline` or `--deploy-guideline`. A commit gets a body only when its type releases (**Message rules**; by default `feat`, `fix`, `perf`, `revert`). Every other commit, including the `graphify-out/` commit, keeps a header-only message.

The body goes in the plan between the commit's `=== <header>` line and its `--- files` line. With both options, it is the `QA:` list, one blank line, then the `Deploy:` list. `plan` shows it in the proposal and `commit` writes it after one blank line below the header, with nothing after it:

```
=== feat(web): add order status filter
QA:
1) web, Orders page: filter by "Status" and check that only orders with that status are listed
2) web, Orders page: clear the "Status" filter and check that all orders are listed again

Deploy:
1) web ("apps/web")
--- files
apps/web/src/OrdersPage.tsx
```

## QA body (`--qa-guideline`)

List what QA must test for the commit, numbered from 1 under a `QA:` line.

- Analyze the commit before writing it: read its capped content diff (`git diff --cached -U1 -- <paths> <exclusions> | head -300`) even when the paths alone decided the header, and read further only for a file whose user-visible effect is still unclear, again capped.
- Each item is one line: a concrete check a tester can run against the deployed app — where (app, page, dialog, API endpoint, scheduled job or report), what to do or send, and the expected result. Example: `1) web, Orders page: filter by "Status" and check that only orders with that status are listed`.
- List the checks for the new or changed behaviour first, including validation, permissions and edge cases the diff handles, then regression checks for features that share the changed code. For `refactor` and `perf`, list regression checks of the affected features (and, for `perf`, what should now be faster).
- When the commit affects several apps, or a shared library, name the affected app in each item; for a shared library, find the affected apps from the projects that use the changed code.
- Write plain English for a tester, not a developer: name screens, fields, buttons and messages as the user sees them, quoting their labels (e.g. `"Save"`); avoid class, method and file names unless a tester sees them (e.g. an API route). Include only what the diff supports; never invent behaviour. Keep it to at most 10 items, merging related checks. Also follow the config's **QA**.

## Deploy body (`--deploy-guideline`)

List what must be deployed for the commit, numbered from 1 under a `Deploy:` line.

- Derive the items from the commit's paths, not from its header scopes, with the config's **Deploy** rules. Without them: a path under a deployable project (an app or service that is run or published on its own) → that project; a path under a shared library → every deployable project that depends on it, directly or through other libraries; a database migration script → an item to run it before deploying the apps; other paths (build, test, tooling) add no item by themselves.
- Each item is one line, in the config's item format, or by default: database scripts first, in file-name order, as `run "<script path>" on the target environment's database`; then one project per item, in alphabetical order of its scope, as `<scope> ("<project folder>")`, adding ` — via shared "<library>"` (every changed library it depends on, comma-separated) when only a shared change makes it deployable.
- If the commit has no item, write no `Deploy:` body for it.
