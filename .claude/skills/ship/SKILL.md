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

Autonomous pre-flight → commit → push → PR workflow. Runs all checks and fixes before touching the remote.

## Pre-Flight Checks (run before any commit)

### 1. Branch guard
```bash
git branch --show-current
```
- If on `dev` or `main`: STOP. Create a feature branch from `dev` first. Never proceed.
- If already on a feature branch: continue.

### 2. Rebase on latest dev
```bash
git fetch origin
git rebase origin/dev
```
- If conflicts: resolve them file by file, then `git rebase --continue`.
- Never use `git rebase --skip` or `git rebase --abort` without telling the user.

### 3. Validate changed files
Get the list of changed files:
```bash
git diff --name-only origin/dev...HEAD
```

For any `.tf` files in the list:
```bash
cd terraform && terraform validate
```
Fix all errors. Re-run until exit 0. Then `terraform fmt -recursive`.

For any files under `roles/`, `group_vars/`, `main.yml`, `bootstrap.yml`:
```bash
ansible-lint <file>
```
Fix all errors. Re-run until exit 0.

Repeat validate → fix → validate loop until both pass cleanly.

### 4. Hardcoded secret scan
Check changed files for plaintext values that should be Doppler references:
```bash
git diff origin/dev...HEAD -- <changed_files> | grep -E '^\+.*"[A-Za-z0-9+/]{20,}"|password\s*=\s*"[^{]|token\s*=\s*"[^{]|secret\s*=\s*"[^{'
```
- If any matches: flag them to the user and stop. Do NOT create the PR.
- Doppler-injected values via `doppler run --` or `{{ lookup('env', ...) }}` are fine.

### 5. Clean up gone branches
```bash
git fetch --prune
git branch -vv | grep ': gone]'
```
Delete any local branches whose remote is gone:
```bash
git branch -d <branch>
```
Use `-D` only if `-d` fails and the branch is clearly merged.

## Commit & Push

Once all pre-flight checks pass:

1. Stage changed files explicitly (no `git add -A`):
   ```bash
   git diff --name-only HEAD
   git add <file1> <file2> ...
   ```
   Never stage: `.vault_pass`, `.envrc`, `vars/vault.yml`, `*.tfvars`

2. Commit:
   ```bash
   git commit -m "<type>: <summary>"
   ```
   Use `{{message}}` if provided, otherwise auto-generate from the diff.
   - If hooks fail: fix errors and retry. Never use `--no-verify`.

3. Push:
   ```bash
   git push -u origin <branch>
   ```
   If rejected (non-fast-forward): investigate before force-pushing.

## Create PR

```bash
gh pr create --base dev --title "<title>" --body "<body>"
```

PR base is always `dev`. Never open directly against `main`.

### PR Body Template

```md
## Summary

- <bullet 1>
- <bullet 2>

## Pre-Flight Checks Passed

- [x] Branch is not dev or main
- [x] Rebased on latest origin/dev
- [x] terraform validate clean (or no .tf files changed)
- [x] ansible-lint clean (or no Ansible files changed)
- [x] No hardcoded secrets detected
- [x] Gone branches cleaned up

## Test Plan

- [ ] <verification step>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Post-PR: Copilot Review

After creating the PR:
- Extract PR number from `gh pr create` output
- Poll `gh api repos/tlesh989/homelab/pulls/<PR>/reviews` every 15 seconds (up to 3 minutes) until a `Copilot` review appears
- Fetch inline comments: `gh api repos/tlesh989/homelab/pulls/<PR>/comments` — display grouped by file
- If Copilot raises valid issues: fix them and push before declaring done
- If no review after 3 minutes: report it and move on

## Commit Message Format

```text
<type>: <short summary>

<bullet points of what changed>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Types: `feat`, `fix`, `chore`, `refactor`, `docs`

## Rules

- NEVER skip pre-flight checks — all 5 must pass before commit
- NEVER use `--no-verify` to bypass hooks
- NEVER open a PR against `main`
- NEVER proceed if hardcoded secrets are detected — surface them to the user
- If any validate/lint loop runs more than 5 iterations without converging, stop and ask the user
