---
name: implement
description: "Full infrastructure implementation workflow: branch → design doc → implement → validate → PR"
user-invocable: true
arguments:
  - name: feature
    description: "Brief description of what you are implementing"
    required: true
---

# Implement Skill

Full design-to-PR workflow for infrastructure changes.

## Steps

1. **Branch** — create a feature branch from `dev` with an appropriate prefix (`feat/`, `fix/`, `chore/`)
2. **Design doc** — write a brief doc in `docs/decisions/` summarizing what is changing and why
3. **Plan** — break the work into an implementation task list and confirm with the user before proceeding
4. **Implement** — make changes across Terraform and/or Ansible files following existing patterns
5. **Validate** — run `terraform validate` (if `.tf` files changed) and `ansible-lint` (if roles/playbooks changed)
6. **Commit** — commit with a conventional commit message (`feat:`, `fix:`, `chore:`, etc.)
7. **PR** — open a pull request to `dev` with the design doc linked in the description

## Rules

- NEVER commit directly to `dev` or `main`
- Always check existing patterns in the directory before creating new files
- Do not proceed past the plan step without user confirmation
- Fix all validation errors before committing
- The PR description must reference the design doc created in step 2
