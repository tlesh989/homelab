---
name: fix-pr
description: Use when a PR has review comments to address — fetches Copilot/Coderabbit/human reviewer feedback for the current branch's PR, fixes valid issues, and pushes
user-invocable: true
arguments:
  - name: pr
    description: "Optional PR number override (defaults to PR for current branch)"
    required: false
---

# Fix PR Skill

Fetch review comments on the current branch's PR, fix valid issues, re-validate, and push.

## Step 1 — Identify the PR

If `{{pr}}` is provided, use that number. Otherwise, detect from the current branch:

```bash
gh pr view --json number,title,baseRefName,headRefName
```

- If no open PR for this branch: STOP and tell the user.
- If on `main`: STOP.

## Step 2 — Fetch All Review Feedback

Run in parallel:

```bash
gh api repos/tlesh989/homelab/pulls/<PR>/reviews
gh api repos/tlesh989/homelab/pulls/<PR>/comments
```

**Reviews** (`/reviews`): top-level review bodies from Copilot, Coderabbit, or human reviewers.

**Comments** (`/comments`): inline comments attached to specific file+line.

Group and display:

```
### <reviewer> (<state>)
[review body if present]

  roles/glance/templates/glance.yml.j2 +42
  > "suggestion text"
  Comment: "explanation"
```

## Step 3 — Triage Comments

For each comment, decide:

| Apply | Skip |
|-------|------|
| Bug or correctness issue | Pure style preference with no clear win |
| Security concern | "Consider using X" with no clear reason |
| Broken convention (vs CLAUDE.md) | Contradicts existing project patterns |
| Clear improvement | Subjective opinion ("I prefer...") |

If unsure: apply it — reviewer feedback is usually worth taking.

## Step 4 — Fix Issues

Apply fixes file by file. After editing each file:

- For `.tf` files: `cd terraform && terraform validate && terraform fmt -recursive`
- For `roles/`, `group_vars/`, `main.yml`, `bootstrap.yml`: `ansible-lint <file>`

Fix all lint/validate errors before moving to the next comment.

## Step 5 — Commit and Push

Stage only the files you changed:

```bash
git add <file1> <file2> ...
git commit -m "fix: address PR review comments"
```

Commit message body: one bullet per issue fixed, e.g.:

```
- Fix monitor widget allow-insecure syntax (Copilot)
- Add cache directive to custom-api widget (Coderabbit)
```

Push:

```bash
git push
```

## Step 6 — Report

Print a summary:

```
Fixed N issues:
  ✓ <issue 1>
  ✓ <issue 2>

Skipped N comments:
  – <reason why skipped>
```

If you skipped any comments, explain briefly so the user can decide whether to override.

## Rules

- NEVER use `--no-verify`
- NEVER push directly to `main`
- NEVER apply a fix that contradicts the project's established patterns without flagging it
- If a reviewer's suggestion would introduce a hardcoded secret, skip it and tell the user
- If lint/validate loops more than 5 iterations without converging, stop and ask
