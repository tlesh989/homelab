# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Proxmox-based homelab managed with **Ansible** (configuration management), **Terraform** (infrastructure provisioning), and **Task** (workflow automation). Ansible secrets are encrypted with Ansible Vault and retrieved via 1Password CLI. Terraform secrets are managed via **Doppler**.

## Common Commands

All workflow commands use [Task](https://taskfile.dev/) (`Taskfile.yml`):

```bash
task                        # List all available tasks
task reqs                   # Install Ansible Galaxy dependencies
task vault_pass             # Fetch vault password from 1Password → .vault_pass
task decrypt                # Decrypt vars/vault.yml and envrc → .envrc
task encrypt                # Encrypt vars/vault.yml and .envrc → envrc

# Deploy to host groups (all require --ask-pass for SSH)
task proxmox                # Proxmox hypervisors
task tailscale              # Tailscale subnet router
task plex                   # Plex media server

# Dry-run / validation
task check                  # Dry-run check mode for ALL hosts
task proxmox -- --check     # Dry-run for a specific group
task syntax                 # Check playbook syntax
task lint                   # Run ansible-lint
task ping                   # Test connectivity to all hosts

# Terraform (from terraform/ directory — has its own Taskfile)
cd terraform && task        # fmt + validate + plan (uses Doppler for secrets)
cd terraform && task apply  # Apply changes
cd terraform && task init   # Initialize Terraform
```

## Architecture

**Hosts** (`hosts` inventory):

- Proxmox hypervisors: tika (.7), bupu (.8), sturm (.9) on 192.168.233.x
- LXC containers (`lxc` group): tailscale (.21), plex (.11) — `ansible_ssh_user=root`
- Docker host: kaz (.10) — runs Docker + Portainer
- Kubernetes VMs provisioned via Terraform on Proxmox

**Ansible structure**:

- `main.yml` — master playbook with per-group play sections
- `group_vars/` — variable hierarchy: `all.yml` (global) → `{group}.yml` (group-specific)
- `vars/vault.yml` — encrypted secrets (Ansible Vault)
- `roles/` — custom roles: `proxmox`, `users`, `install_script`
- `requirements.yml` — Galaxy role and collection dependencies (geerlingguy.*, artis3n.tailscale, buluma.roles, etc.)

**Terraform structure** (`terraform/`):

- `versions.tf` — providers pinned: bpg/proxmox 0.69.1, linode/linode 1.30.0, cloudflare/cloudflare ~>4, amalucelli/nextdns ~>0.2, paultyng/unifi 0.41.0; Terraform Cloud backend (tlesh-net/homelab)
- `Taskfile.yml` — local task runner (fmt, validate, plan via Doppler, apply)
- `k8s.tf` — Kubernetes VM definitions
- `disabled/` — parked/experimental infrastructure code

## Conventions

**Ansible**:

- All tasks must have `name:` fields
- Use `loop` instead of `with_items` (deprecated)
- Review `become: true` usage for security implications
- Galaxy roles installed to `galaxy_roles/` (gitignored)

**Terraform**:

- snake_case for all resource, variable, data source, and output names
- All variables must have `description` fields
- Resources should include `tags`
- Provider versions pinned in `versions.tf`

**General**:

- 2-space indentation (`.editorconfig`)
- Max line length: 120 characters
- Git pre-commit hook enforces vault encryption on `vars/vault.yml` and `envrc`
- Files to never commit unencrypted: `.vault_pass`, `*.tfvars`, `.envrc`

## CI/CD

Two GitHub Actions workflows:

- **`ci.yml`** — runs on every push/PR to `main`:
  - Ansible syntax check (`task syntax`)
  - Terraform validate (`terraform -chdir=terraform init -backend=false && validate`)
  - Pre-commit vault protection check (`check-ansible-vault`)
- **`tailscale.yml`** — syncs `tailscale/policy.hujson` ACLs: tests on PR, deploys on push to main

Branch model: feature branches → `main`
