# AI Instructions (Claude & Gemini)

This file provides guidance to Claude Code (claude.ai/code) and Gemini CLI when working with code in this repository.

## Project Overview

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

## Conventions

- **Naming**:
  - Files/Folders: `kebab-case`.
  - Terraform Resource Labels: `snake_case` (e.g., `proxmox_nfs`).
  - Infrastructure IDs: `kebab-case` (e.g., `storage_id = "proxmox-nfs"`).
  - Resource Prefixes: `sa-`, `sneg-`, `lb-`, `vpc-`, `db-`.
- **Ansible**: Mandatory `name:` fields, use `loop`, review `become: true`.
- **Terraform**: Mandatory `description` on variables/outputs, pin provider versions in `versions.tf`.
- **General**: 2-space indentation, max 120 chars line length.

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
  - `ci.yml`: Runs on push/PR to `dev` and `main`. Runs Terraform `task ci` and Ansible `ansible-playbook --syntax-check` without Doppler.
  - `dev-to-main-pr.yml`: Automatically creates/updates a PR from `dev` to `main` when `dev` is updated.
  - `tailscale.yml`: Syncs Tailscale ACLs.

## Model-Specific Skills & Hooks

### Claude Code

- `/deploy <target>` — dry-run first, apply on confirmation.
- `/ship [message]` — commit, push, and open a PR against `dev`.
- Hooks: Blocks edits to secrets, runs yamllint on YAML edits.

### Gemini CLI

- Uses the `Research -> Strategy -> Execution` lifecycle.
- Prioritizes `Taskfile.yml` for all execution.
- Respects `GEMINI.md` (now symlinked to this file).
