# AI Instructions (Claude & Gemini)

This file provides guidance to Claude Code (claude.ai/code) and Gemini CLI when working with code in this repository.

## Project Overview

This is a homelab infrastructure repo using Terraform (Proxmox provider), Ansible roles, and Doppler for secrets. Primary languages are YAML (Ansible), HCL (Terraform), and Markdown. Always check existing patterns in the repo before creating new files.

This repository contains the infrastructure-as-code and configuration management for a personal homelab.

- **Infrastructure:** Proxmox VE hosting LXC containers and VMs across nodes (e.g., `bupu`, `sturm`, `tika`).
- **Provisioning:** Terraform using the `bpg/proxmox` provider. State is managed in Terraform Cloud (`tlesh-net` organization).
- **Configuration:** Ansible playbooks and roles for setting up services like Tailscale, Plex, Pi-hole, and Glance.
- **Secret Management:** [Doppler](https://www.doppler.com/) for secret injection.
- **Automation:** [Task](https://taskfile.dev/) for orchestrating operations.
- **Environment:** Running on MacBook Air M4 (Arm64).

## Engineering Standards

- **Stability & Uptime**: Prioritize system reliability above all.
- **KISS**: Keep It Simple, Stupid. Avoid over-engineering.
- **Doppler First**: All secrets come from Doppler. Never hardcode or use local vault files.
- **Proactive SRE**: Anticipate networking, IAM, and observability needs.
- **Gitflow**:
  - **NEVER** commit directly to `dev` or `main`.
  - Always work in `feature/*`, `chore/*`, `hotfix/*`, or `bugfix/*` branches.
  - Changes must be merged into `dev` via Pull Request.
  - Automated workflows handle merging `dev` into `main`.
- **Source Control**: Do not stage or commit changes unless specifically requested. Use standard commit messages (e.g., `feat: ...`, `fix: ...`, `chore: ...`).

## Common Commands

All workflow commands use [Task](https://taskfile.dev/) (`Taskfile.yml`) and **Doppler**:

```bash
task                        # List all available tasks
task reqs                   # Install Ansible Galaxy dependencies

# Deploy to host groups (Secrets handled by Task + Doppler)
task proxmox                # Proxmox hypervisors
task tailscale              # Tailscale subnet router
task plex                   # Plex media server
task glance                 # Glance dashboard

# Dry-run / validation
task check                  # Dry-run check mode for ALL hosts
task syntax                 # Check playbook syntax
task lint                   # Run ansible-lint
task ping                   # Test connectivity to all hosts

# Bootstrap a new LXC container (first-time only — creates ansible service account)
# Doppler sets SSH_USER=tommy locally, so must override with ansible_user=root
doppler run -- ansible-playbook -b bootstrap.yml --limit <hostname> --tags bootstrap -e "ansible_user=root"

# Terraform (from terraform/ directory)
cd terraform && task        # fmt + validate + plan
cd terraform && task init   # Initialize with Doppler secrets
cd terraform && task apply  # Apply changes
cd terraform && task test   # Format and Validate
```

## Architecture & Key Directories

- **Ansible**: `main.yml` is the master playbook. `group_vars/` for hierarchy. Custom roles in `roles/`.
- **Terraform**: Located in `terraform/`. Configuration is split by service (e.g., `plex.tf`, `pi-hole.tf`).
- **Inventory**: Managed in `hosts` file.
- **Tailscale**: ACL/policy configuration in `tailscale/`.
- **Docs**: Architectural design and migration plans in `docs/plans/`.

> **Vault**: `vars/vault.yml` has been removed. Do NOT reintroduce it or use `vault_pass`, `decrypt`, or `encrypt` tasks — they have been removed. All secrets go through Doppler.

## Conventions

- **Naming**:
  - Files/Folders: `kebab-case`.
  - Terraform Resource Labels: `snake_case` (e.g., `proxmox_nfs`).
  - Infrastructure IDs: `kebab-case` (e.g., `storage_id = "proxmox-nfs"`).
  - Resource Prefixes: `sa-`, `sneg-`, `lb-`, `vpc-`, `db-`.
- **Ansible**: Mandatory `name:` fields, use `loop`, review `become: true`.
- **Terraform**: Mandatory `description` on variables/outputs, pin provider versions in `versions.tf`.
- **General**: 2-space indentation, max 120 chars line length.

## Git Workflow

- Always create a feature branch before committing changes. Never commit directly to `dev` or `main` branches.
- When creating PRs, always branch from `dev` (not `main`) unless explicitly told otherwise.
- Use Gitflow-style branch naming: `feature/*`, `bugfix/*`, `chore/*`, `hotfix/*`.
- Before making any changes: 1) check which branch you are on and create a feature branch from `dev` if needed, 2) review existing patterns in the directory you will modify, 3) list your plan and wait for explicit approval before editing files.

## Gitflow & CI/CD

- **Working Branch**: `dev`. This is the default branch for all active development.
- **Production Branch**: `main`. This branch represents the current production state.
- **Branch Naming**:
  - `feature/*` — New features or improvements.
  - `bugfix/*` — Fixes for bugs in `dev`.
  - `chore/*` — Maintenance tasks, dependencies, etc.
  - `hotfix/*` — Urgent fixes aimed at `main` (but still merged through `dev`).
- **Workflow**:
  1. Create a branch from `dev` (e.g., `feature/my-cool-feature`).
  2. Commit changes to the feature branch.
  3. Open a PR to merge into `dev`.
  4. Never commit directly to `dev` or `main`.
- **Automation**:
  - `ci.yml`: Runs on push/PR to `dev` and `main`. Runs Terraform `task ci` and Ansible `ansible-playbook --syntax-check` without Doppler. (Ansible Vault is decommissioned — CI does not run any vault checks.)
  - `dev-to-main-pr.yml`: Automatically creates/updates a PR from `dev` to `main` when `dev` is updated.
  - `tailscale.yml`: Syncs Tailscale ACLs.

## Code Editing Rules

- When using the Edit tool with `replace_all` or broad replacements, verify that variable name substitutions don't collide with similarly-named variables (e.g., replacing `users` should not affect `users_groups` or `users_ssh_exclusive`).

## Key Files to Keep in Sync

- `.github/copilot-instructions.md` — PR-review-focused summary for GitHub Copilot. Update it when conventions or CI checks change.

## Claude Configuration

- For MCP server configurations, use `.claude/settings.json` (project-level) not `~/.claude/settings.json` (global) unless the user specifies otherwise.

## MCP Tool Usage

- **Context7**: Always use the `context7` MCP to look up documentation, API references, module options, provider schemas, and configuration examples — for Ansible modules, Terraform providers (`bpg/proxmox`, `hashicorp/*`), Doppler, Tailscale, or any library. Do this proactively without waiting to be asked.
- **GitHub**: Use the `gh` CLI (not an MCP) for all GitHub operations — reading issues, checking CI status, viewing PR comments, and managing pull requests.

## Model-Specific Skills & Hooks

### Claude Code

- `/deploy <target>` — dry-run first, apply on confirmation.
- `/ship [message]` — commit, push, and open a PR against `dev`.
- `/new-service <name>` — scaffold Terraform LXC config + Ansible role skeleton.
- Hooks (PostToolUse): `yamllint` on `.yml/.yaml`, `terraform fmt` + `validate` on `.tf`, `ansible-lint` on `roles/**/*.yml`. PreToolUse blocks edits to `.vault_pass`, `.envrc`, `vars/vault.yml`, `*.tfvars`.

## Behavior Rules

- **SSH auth failures**: If SSH authentication fails, stop immediately and tell the user to unlock their SSH key via 1Password before retrying.
- **Before opening a PR**: Always run `coderabbit review --plain --base dev` on committed changes before creating a PR with `/ship`.

## Verification (Definition of Done)

- **Ansible change**: `task syntax` passes, `task lint` passes, `task check` dry-run shows expected changes only.
- **Terraform change**: `cd terraform && task test` (fmt + validate) passes, `task plan` reviewed before apply.
- **New service scaffold**: `task check` passes for the new host group, `task ping` confirms connectivity.
- **PR ready**: CI passes on GitHub, `coderabbit review` clean.

### Gemini CLI

- Uses the `Research -> Strategy -> Execution` lifecycle.
- Prioritizes `Taskfile.yml` for all execution.
- Respects `GEMINI.md` (now symlinked to this file).

## RTK (Rust Token Killer)

Always prefix shell commands with `rtk` for 60-90% token savings — it passes through unchanged if no filter exists, so it's always safe. Works with `&&` chains too: `rtk git add . && rtk git commit -m "msg" && rtk git push`.

Key meta commands: `rtk gain` (savings analytics), `rtk discover` (missed opportunities), `rtk proxy <cmd>` (raw output). Run `rtk --help` for the full command reference.
