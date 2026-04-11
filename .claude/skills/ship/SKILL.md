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

- If already on `main`: STOP. Create a feature branch from `main` first. Never proceed.
- If already on a feature branch: continue.

### 2. Rebase on latest main

```bash
git fetch origin
git rebase origin/main
```

- If conflicts: resolve them file by file, then `git rebase --continue`.
- Never use `git rebase --skip` or `git rebase --abort` without telling the user.

### 3. Validate changed files

Get the list of changed files:

```bash
git diff --name-only origin/main...HEAD
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
git diff origin/main...HEAD -- <changed_files> | grep -E '^\+.*"[A-Za-z0-9+/]{20,}"|password\s*=\s*"[^{]|token\s*=\s*"[^{]|secret\s*=\s*"[^{'
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

### 6. CodeRabbit gate (blocking — runs before PR creation)

```bash
coderabbit review --plain --base main
```

- This takes ~60 seconds. Run it on committed changes before opening the PR.
- If CodeRabbit surfaces **Blocking** issues: fix them, commit, and re-run before proceeding.
- If only Advisory issues: surface them to the user and proceed if they confirm.
- If CodeRabbit is not installed or exits non-zero for tool reasons: warn the user and continue.

## Create PR

Only open the PR after the CodeRabbit gate passes.

```bash
gh pr create --base main --title "<title>" --body "<body>"
```

PR base is always `main`.

### PR Body Template

```md
## Summary

- <bullet 1>
- <bullet 2>

## Pre-Flight Checks Passed

- [x] Branch is not main
- [x] Rebased on latest origin/main
- [x] terraform validate clean (or no .tf files changed)
- [x] ansible-lint clean (or no Ansible files changed)
- [x] No hardcoded secrets detected
- [x] Gone branches cleaned up
- [x] CodeRabbit review clean (or advisory issues acknowledged)

## Test Plan

- [ ] <verification step>

🤖 Generated with [OpenCode](https://opencode.ai)
```

## Post-PR: Copilot Review

After creating the PR, poll for the Copilot review:

- Extract PR number from `gh pr create` output
- Poll `gh api repos/tlesh989/homelab/pulls/<PR>/reviews` every 15 seconds (up to 3 minutes) until a `Copilot` review appears
- Fetch inline comments: `gh api repos/tlesh989/homelab/pulls/<PR>/comments`
- Display feedback grouped by file
- Triage: apply valid issues, skip style preferences or YAGNI suggestions
- Fix, commit, and push any accepted changes before declaring done
- If no Copilot review after 3 minutes: move on

## Commit Message Format

```text
<type>: <short summary>

<bullet points of what changed>

Co-Authored-By: OpenCode Agent <noreply@opencode.ai>
```

Types: `feat`, `fix`, `chore`, `refactor`, `docs`

## Rules

- NEVER skip pre-flight checks — all 6 must pass before opening a PR
- NEVER use `--no-verify` to bypass hooks
- NEVER commit directly to `main`
- NEVER proceed if hardcoded secrets are detected — surface them to the user
- If any validate/lint loop runs more than 5 iterations without converging, stop and ask the user
