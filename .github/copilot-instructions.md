<!-- Source of truth: CLAUDE.md — keep this file in sync -->
# Homelab Infrastructure Management

## Core Principles (Senior SRE/DevOps)

- **Stability & Uptime**: Prioritize system reliability above all.
- **KISS**: Keep It Simple, Stupid. Avoid over-engineering.
- **Doppler First**: All secrets come from Doppler. Never hardcode or use local vault files.
- **Proactive SRE**: Anticipate networking, IAM, and observability needs.

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

# Terraform (from terraform/ directory — still requires doppler run for native commands if not using task)
cd terraform && task        # fmt + validate + plan
cd terraform && task apply  # Apply changes
```

## Architecture

- **Ansible**: `main.yml` is the master playbook. `group_vars/` for hierarchy. Custom roles in `roles/`.
- **Terraform**: Located in `terraform/`. Uses Terraform Cloud for state management.
- **Inventory**: Managed in `hosts` file.

**Hosts:**

- Proxmox hypervisors: tika (.7), bupu (.8), sturm (.9) on 192.168.233.x
- LXC containers: tailscale (.21), plex (.11), glance (.22), kaz (.10 — Docker host)
- Kubernetes VMs provisioned via Terraform on Proxmox

## Secrets Management

- **Source of Truth**: All secrets are stored in **Doppler**.
- **Usage**: `doppler run -- <command>` (handled automatically via `task` commands).
- Ansible Vault and 1Password have been decommissioned.

## Conventions

- **Naming**:
  - Files/Folders: `kebab-case`.
  - Terraform Resources: `snake_case`.
  - Resource Prefixes: `sa-`, `sneg-`, `lb-`, `vpc-`, `db-`.
- **Ansible**: Mandatory `name:` fields, use `loop`, review `become: true`.
- **Terraform**: Mandatory `description` on variables/outputs, pin provider versions in `versions.tf`.
- **General**: 2-space indentation, max 120 chars line length.

## CI/CD

- **`ci.yml`**: Runs on push/PR to `main`.
  - Uses Doppler CLI to run `task syntax`.
  - Terraform `init` and `validate`.
- **`tailscale.yml`**: Syncs Tailscale ACLs.
- Branch model: `dev` → `main`
