---
name: lazy-commit-force
description: Alias for `/lazy-commit --force` — commit all changes on the current branch immediately, as Conventional Commits grouped by scope, without the approval question. Use only when the user runs /lazy-commit-force.
argument-hint: "[additional instructions]"
disable-model-invocation: true
---

Call the Skill tool with the skill `lazy-commit` and the args `--force $ARGUMENTS`, and follow the skill it loads exactly, as if the user had typed `/lazy-commit --force $ARGUMENTS`. Running this alias counts as the user's approval, just as passing `--force` does.

Output nothing of your own before, between or after its steps; the user sees only what that skill tells you to output.

If the Skill tool can't find `lazy-commit`, stop and say it must be installed in `~/.claude/skills/lazy-commit/`; never commit without it.
