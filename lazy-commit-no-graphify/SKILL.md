---
name: lazy-commit-no-graphify
description: Alias for `/lazy-commit -f --skip-graphify` — commit all changes on the current branch immediately, without the approval question, leaving `graphify-out/` uncommitted. Use only when the user runs /lazy-commit-no-graphify.
argument-hint: "[additional instructions]"
disable-model-invocation: true
---

Call the Skill tool with the skill `lazy-commit` and the args `-f --skip-graphify $ARGUMENTS`, and follow the skill it loads exactly, as if the user had typed `/lazy-commit -f --skip-graphify $ARGUMENTS`. Running this alias counts as the user's approval, just as passing `-f` does.

Output nothing of your own before, between or after its steps; the user sees only what that skill tells you to output.

If the Skill tool can't find `lazy-commit`, stop and say it must be installed in `~/.claude/skills/lazy-commit/`; never commit without it.
