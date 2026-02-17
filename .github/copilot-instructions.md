# Homelab Infrastructure Management

## Architecture Overview

This repository manages a Proxmox-based homelab using Ansible for configuration management and Terraform for infrastructure provisioning.

**Infrastructure Components:**

- **Proxmox hosts** (tika, bupu, sturm): Physical servers running VMs and LXC containers
- **LXC containers**: tailscale (subnet router), plex (media server), kaz (Docker host)
- **VMs**: Kubernetes cluster nodes managed via Terraform

**Key Services:**

- Tailscale (zero-trust networking)
- Plex Media Server
- Docker containers on kaz host
- Kubernetes cluster for container orchestration

## Critical Workflows

**Environment Setup:**

```bash
# Install Ansible dependencies
task reqs

# Get vault password from 1Password
task vault_pass

# Decrypt secrets (requires .vault_pass file)
task decrypt
```

**Deployment Commands:**

```bash
# Deploy to specific host groups
task proxmox    # Proxmox hypervisor configuration
task tailscale  # Tailscale subnet router
task plex       # Plex media server

# Run with check mode
task proxmox -- --check
```

**Secret Management:**

- Use `ansible-vault` for encrypting sensitive data in `vars/vault.yml`
- Environment variables managed via direnv (.envrc)
- 1Password CLI integration for vault passwords

## Project Conventions

**Ansible Patterns:**

- All tasks must have descriptive `name:` fields
- Use `become: true` judiciously - review security implications
- Group variables in `group_vars/` override defaults
- Custom roles in `roles/` directory, Galaxy roles auto-installed

**Terraform Patterns:**

- Resources use snake_case naming
- All variables must have `description` fields
- Resources should include `tags` for organization
- State managed in Terraform Cloud workspace "homelab"
- Provider versions pinned in `versions.tf`

**File Organization:**

- `main.yml`: Main Ansible playbook with host-specific role assignments
- `group_vars/all.yml`: Global configuration shared across all hosts
- `terraform/k8s.tf`: VM definitions for Kubernetes cluster
- `Taskfile.yml`: Workflow automation (preferred over direct ansible-playbook calls)

## Integration Points

**Authentication Flow:**

1. SSH key-based access initially (root user)
2. Ansible creates service accounts with sudo access
3. Tailscale provides zero-trust networking overlay

**Network Architecture:**

- Proxmox hosts: 192.168.233.7-9
- LXC containers: DHCP on Proxmox bridge
- Tailscale: Subnet routing for 192.168.233.0/24

**External Dependencies:**

- 1Password CLI for secret retrieval
- Terraform Cloud for state management
- Ansible Galaxy for role dependencies
- Proxmox API for VM/container management

## Development Workflow

**Making Changes:**

1. Edit playbooks in `main.yml` or role tasks
2. Update variables in `group_vars/` or role defaults
3. Test with `--check` mode: `task proxmox -- --check`
4. Commit changes (git hooks auto-encrypt vault files)

**Adding New Services:**

1. Define host in `hosts` inventory
2. Add host group in `main.yml` playbook
3. Create group_vars file if needed
4. Add roles and collections from Ansible Galaxy or create custom roles

**Infrastructure Changes:**

1. Modify Terraform files in `terraform/` directory
2. Plan changes: `cd terraform && terraform plan`
3. Apply: `terraform apply`
4. Update Ansible inventory if new hosts added
