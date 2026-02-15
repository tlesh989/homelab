# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Proxmox-based homelab managed with **Ansible** (configuration management), **Terraform** (infrastructure provisioning), and **Task** (workflow automation). Secrets are encrypted with Ansible Vault and retrieved via 1Password CLI.

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
task unifi                  # UniFi controller
task tailscale              # Tailscale subnet router
task plex                   # Plex media server

# Dry-run with check mode
task proxmox -- --check

# Terraform (from terraform/ directory)
cd terraform && terraform plan
cd terraform && terraform apply
```

## Architecture

**Hosts** (`hosts` inventory):
- Proxmox hypervisors: tika (.7), bupu (.8), sturm (.9) on 192.168.233.x
- LXC containers: unifi (.5), tailscale (.21), kaz (.10), plex (.11)
- Kubernetes VMs provisioned via Terraform on Proxmox

**Ansible structure**:
- `main.yml` — master playbook with per-group play sections
- `group_vars/` — variable hierarchy: `all.yml` (global) → `{group}.yml` (group-specific)
- `vars/vault.yml` — encrypted secrets (Ansible Vault)
- `roles/` — custom roles (proxmox, unifi_controller, network, install_script)
- `requirements.yml` — Galaxy role dependencies (geerlingguy.*, artis3n.tailscale, etc.)

**Terraform structure** (`terraform/`):
- `versions.tf` — providers (bpg/proxmox 0.69.1), Terraform Cloud backend (tlesh-net/homelab)
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

- GitHub Actions workflow syncs `tailscale/policy.hujson` ACLs: tests on PR/dev push, deploys on main push
- Branch model: `dev` → `main`
