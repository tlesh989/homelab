---
name: ship
description: Use when ready to commit, push, and open a pull request in the homelab repo
user-invocable: true
arguments:
  - name: message
    description: "Optional commit message override"
    required: false
---

# Ship Skill

Commit, push, and open a PR against `dev` in one shot.

## Steps

1. Run `git diff --name-only HEAD` to see what changed
2. Stage changed files explicitly (no `git add -A` — avoids accidentally staging sensitive files)
3. Commit with `{{message}}` if provided, otherwise auto-generate from the diff
   - Pre-commit hooks run automatically (markdownlint, ansible-lint, terraform checks)
   - If hooks fail, fix the errors and retry the commit — do NOT skip hooks
4. Push branch to origin: `git push -u origin <branch>`
5. Create PR: `gh pr create --base dev --title "<title>" --body "<body>"`

## Commit Message Format

```text
<type>: <short summary>

<bullet points of what changed>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Types: `feat`, `fix`, `chore`, `refactor`, `docs`

## PR Body Template

```md
## Summary

- <bullet 1>
- <bullet 2>

## Test Plan

- [ ] <verification step>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Rules

- PR base branch is always `dev` — never open directly against `main`
- Never stage `.vault_pass`, `.envrc`, `vars/vault.yml`, `*.tfvars` (hooks block these anyway)
- Never use `--no-verify` to skip hooks — fix the failures instead
- If push is rejected (non-fast-forward), investigate before force-pushing
