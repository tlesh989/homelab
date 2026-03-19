<!-- Single source of truth: CLAUDE.md — this file is a PR-review-focused summary -->
# Homelab — Copilot PR Review Guide

> For full project context, architecture, and conventions, read **[CLAUDE.md](../CLAUDE.md)** at the repo root.

## What This Repo Is

Personal homelab IaC and configuration management. Proxmox VE hypervisors (`tika`, `bupu`, `sturm`) hosting LXC containers and VMs, provisioned with Terraform (`bpg/proxmox` provider, Terraform Cloud state) and configured with Ansible. Secrets are managed exclusively via **Doppler**.

---

## PR Review Checklist

When reviewing a pull request, flag anything that violates the following:

### Secrets & Security

- **No hardcoded secrets** — credentials, tokens, IPs, passwords must come from Doppler, never inline
- No `.envrc`, `.tfvars`, or `vars/vault.yml` files with secret values committed
- Ansible `no_log: true` on tasks that print sensitive output

### Gitflow

- PRs must target `dev`, **never `main`**
- Branch names must follow: `feature/*`, `bugfix/*`, `chore/*`, `hotfix/*`
- Commits must use conventional prefixes: `feat:`, `fix:`, `chore:`, `refactor:`, etc.

### Ansible

- Every task must have a `name:` field
- Shell/command tasks must use `set -o pipefail` and `executable: /bin/bash`
- Prefer `failed_when:` over `ignore_errors: true`
- Use `ansible.builtin.*` FQCNs (not short module names)
- `become: true` only where strictly necessary — flag unexpected privilege escalation
- Handlers should be used for service restarts and initramfs updates, not inline tasks

### Terraform

- All `variable` and `output` blocks must have a `description`
- Provider versions must be pinned in `versions.tf`
- Resource labels: `snake_case`; infrastructure IDs: `kebab-case`
- No inline sensitive values; use `var.*` referencing Doppler-injected variables

### General Code Quality

- 2-space indentation, 120-char line limit
- File and folder names: `kebab-case`
- No dead code, unused variables, or commented-out blocks left in
- KISS — flag over-engineering or unnecessary abstraction

### CI Compatibility

- YAML changes must be valid (`yamllint`)
- Ansible changes must pass `ansible-lint` and `ansible-playbook --syntax-check`
- Terraform changes must pass `terraform fmt -check` and `terraform validate`
- These checks run automatically in `ci.yml` — PRs must not break them

---

## What to Approve Without Concern

- Dependency bumps via Renovate (automated, tested by CI)
- `docs/` and `tailscale/policy.hujson` changes (low blast radius)
- Formatting-only commits that pass lint

## What to Flag / Block

- Any secret or credential in plaintext
- Direct commits or merges targeting `main`
- Tasks that reboot, reinitialize, or wipe state without a guard condition
- Removing idempotency protections (e.g., dropping `when:` guards, `creates:`, `stat` checks)
- DKMS or kernel module changes without a `failed_when:` on the running kernel
