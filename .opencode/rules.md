# Homelab Conventions

## Principles

- **Stability first** — prioritize reliability over cleverness.
- **Secrets via Doppler** — `doppler run -- <cmd>`. Never `.tfvars`, vault files, or hardcoded values.
- **All ops via Task** — `task <target>` (see Taskfile.yml). Don't run Ansible or Terraform directly.

## Ansible

**Commands:**

```bash
task syntax && task lint  # Always run before committing
task check               # Dry-run all hosts (confirm before deploy)
task ping               # Verify connectivity
task reqs               # Run after any requirements.yml change
```

**Standards:**

- Every task **must** have a `name:` field.
- Use `loop`, not `with_items`.
- Always include `mode:` on `file`/`copy` tasks (ansible-lint enforces this).
- Any task creating dirs/files for a service user: add `chown -R <puid>:<pgid> <path>` immediately after.
- `become: true` at task level, not play level, where possible.
- `gathering = explicit` in ansible.cfg — roles using facts **must** include an explicit `setup:` task with `gather_subset`.
- Galaxy roles (e.g. `geerlingguy.ntp`) require `gather_facts: true` at the play level instead.

## Terraform

**Commands** (run from `terraform/`):

```bash
task test   # fmt + validate
task plan   # Review before apply
task apply  # Requires task plan first
```

**Standards:**

- Resource labels: `snake_case`. Infrastructure IDs: `kebab-case`.
- All variables and outputs require `description` fields.
- State in Terraform Cloud (`tlesh-net` org).
- Pin all provider versions in `versions.tf` (TF `>= 1.10`, Google `~> 7.x`).

## Git

- Integration branch: `main`. Never commit directly to `main`.
- Branch types: `feature/*`, `bugfix/*`, `chore/*`, `hotfix/*`.
- Commit prefixes: `feat:`, `fix:`, `chore:`.
- Run `coderabbit review --plain --base main` on committed changes before opening a PR.
- **Work is not done until `git push` succeeds.**

## Definition of Done

1. `task syntax && task lint` pass (Ansible) or `task test` (Terraform).
2. `task check` dry-run shows only expected changes.
3. `coderabbit review` run if changing logic.
4. Commit, push, PR merged.