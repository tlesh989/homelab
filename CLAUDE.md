# AI Instructions (Claude & Gemini)

This file provides guidance to Claude Code (claude.ai/code) and Gemini CLI when working with code in this repository.

## Project Overview

This is a homelab infrastructure repo using Terraform (Proxmox provider), Ansible roles, and Doppler for secrets. Primary languages are YAML (Ansible), HCL (Terraform), and Markdown. Always check existing patterns before creating new files.

- **Infrastructure:** Proxmox VE hosting LXC containers and VMs across nodes (e.g., `bupu`, `sturm`, `tika`).
- **Provisioning:** Terraform using the `bpg/proxmox` provider — see `terraform/CLAUDE.md` for Terraform-specific guidance.
- **Configuration:** Ansible playbooks and roles for services like Tailscale, Plex, Pi-hole, and Glance.
- **Secret Management:** [Doppler](https://www.doppler.com/) for secret injection.
- **Automation:** [Task](https://taskfile.dev/) for orchestrating operations.
- **Environment:** MacBook Air M4 (Arm64).

## Engineering Standards

- **Stability & Uptime**: Prioritize system reliability above all.
- **KISS**: Avoid over-engineering.
- **Doppler First**: All secrets come from Doppler. Never hardcode or use local vault files.
- **Proactive SRE**: Anticipate networking, IAM, and observability needs.
- **Source Control**: Do not stage or commit changes unless specifically requested. Use standard commit messages (`feat:`, `fix:`, `chore:`, etc.).

## Common Commands

```bash
task                        # List all available tasks
task reqs                   # Install Ansible Galaxy dependencies
task proxmox                # Deploy Proxmox hypervisors
task tailscale              # Deploy Tailscale subnet router
task plex                   # Deploy Plex media server
task glance                 # Deploy Glance dashboard
task check                  # Dry-run check mode for ALL hosts
task syntax                 # Check playbook syntax
task lint                   # Run ansible-lint
task ping                   # Test connectivity to all hosts

# Bootstrap a new LXC (first-time only — creates ansible service account)
# Doppler sets SSH_USER=tommy locally, so must override with ansible_user=root
doppler run -- ansible-playbook -b bootstrap.yml --limit <hostname> --tags bootstrap -e "ansible_user=root"
```

## Architecture & Key Directories

- **Ansible**: `main.yml` master playbook. `group_vars/` for hierarchy. Custom roles in `roles/`.
- **Inventory**: `hosts` file.
- **Tailscale**: ACL/policy in `tailscale/`.
- **Terraform**: `terraform/` — see `terraform/CLAUDE.md`.
- **Docs**: Plans in `docs/plans/`.

> **Vault removed**: `vars/vault.yml` has been removed. Do NOT reintroduce it or use `vault_pass`, `decrypt`, or `encrypt` tasks — all secrets go through Doppler.

## Conventions

- **Naming**: Files/Folders: `kebab-case`.
- **Ansible**: Mandatory `name:` fields, use `loop`, review `become: true`.
- **General**: 2-space indentation, max 120 chars line length.
- **Shell filename loops**: Always use `find -print0 | while IFS= read -r -d "" f; do ...` — never plain `while read f` (breaks on spaces/special chars). **Bash-specific; ensure Bash is used (`#!/usr/bin/env bash`, `bash -lc`, or Ansible `executable: /bin/bash`).**
- **Service user file creation**: Any task or Ansible step creating dirs/files for a service user must include `chown -R <puid>:<pgid> <path>` immediately after.

## Gitflow & CI/CD

- **Working Branch**: `dev`. **Production Branch**: `main`.
- **NEVER** commit directly to `dev` or `main`. Always use `feature/*`, `bugfix/*`, `chore/*`, or `hotfix/*` branches, merged via PR.
- Before any changes: 1) verify your branch, 2) create a feature branch from `dev` if needed, 3) review existing patterns, 4) list your plan and wait for explicit approval before editing.
- **Automation**:
  - `ci.yml`: Runs on push/PR to `dev`/`main`. Runs Terraform `task ci` and Ansible syntax check (no Doppler, no vault).
  - `dev-to-main-pr.yml`: Auto-creates/updates PR from `dev` → `main` when `dev` is updated.
  - `tailscale.yml`: Syncs Tailscale ACLs.

## Code Editing Rules

- When using Edit with `replace_all`, verify substitutions don't collide with similarly-named variables (e.g., `users` vs `users_groups` or `users_ssh_exclusive`).

## Key Files to Keep in Sync

- `.github/copilot-instructions.md` — Update when conventions or CI checks change.

## Claude Configuration

- MCP server configurations go in `.claude/settings.json` (project-level) unless the user specifies global (`~/.claude/settings.json`).

## MCP Tool Usage

- **Context7**: Use proactively for docs, API references, module options, and provider schemas — Ansible modules, Terraform providers (`bpg/proxmox`, `hashicorp/*`), Doppler, Tailscale, or any library. Don't wait to be asked.
- **GitHub**: Use the `gh` CLI (not an MCP) for all GitHub operations.

## Model-Specific Skills & Hooks

### Claude Code

- `/deploy <target>` — dry-run first, apply on confirmation.
- `/ship [message]` — commit, push, and open a PR against `dev`.
- `/new-service <name>` — scaffold Terraform LXC config + Ansible role skeleton.
- Hooks (PostToolUse): `yamllint` on `.yml/.yaml`, `terraform fmt` + `validate` on `.tf`, `ansible-lint` on `roles/**/*.yml`. PreToolUse blocks edits to `.vault_pass`, `.envrc`, `vars/vault.yml`, `*.tfvars`.
- Agents: `infra-reviewer` — pre-deploy review for Ansible/Terraform changes (idempotency, naming, secret hygiene).

## Behavior Rules

- **SSH auth failures**: Stop immediately and tell the user to unlock their SSH key via 1Password before retrying.
- **Before opening a PR**: Always run `coderabbit review --plain --base dev` on committed changes before creating a PR with `/ship`.

## Verification (Definition of Done)

- **Ansible change**: `task syntax` passes, `task lint` passes, `task check` dry-run shows expected changes only.
- **New service scaffold**: `task check` passes, `task ping` confirms connectivity.
- **PR ready**: CI passes on GitHub, `coderabbit review` clean.

### Gemini CLI

- Uses the `Research -> Strategy -> Execution` lifecycle.
- Prioritizes `Taskfile.yml` for all execution.
- Respects `GEMINI.md` (symlinked to this file).

## RTK

RTK is installed globally — prefix shell commands with `rtk` for token savings. Run `rtk gain` for analytics, `rtk discover` for missed opportunities.
