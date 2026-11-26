---
name: lazy-commit-single
description: Alias for `/lazy-commit --force --single-commit` — commit all changes on the current branch immediately, without the approval question, in one commit, except the paths of the config's **Fixed headers** and `graphify-out/`, which keep their own commits. Use only when the user runs /lazy-commit-single.
argument-hint: "[additional instructions]"
disable-model-invocation: true
---

Call the Skill tool with the skill `lazy-commit` and the args `--force --single-commit $ARGUMENTS`, and follow the skill it loads exactly, as if the user had typed `/lazy-commit --force --single-commit $ARGUMENTS`. Running this alias counts as the user's approval, just as passing `--force` does.

Output nothing of your own before, between or after its steps; the user sees only what that skill tells you to output.

If the Skill tool can't find `lazy-commit`, stop and say it must be installed in `~/.claude/skills/lazy-commit/`; never commit without it.
