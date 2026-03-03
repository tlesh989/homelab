# Homelab Infrastructure Management

## Core Operating Principles (Senior SRE/DevOps)

- **Get Things Done**: Optimize for velocity without sacrificing stability. Take decisive action and iterate.
- **Proactivity**: Anticipate side effects. Check IAM, networking, and observability requirements immediately when adding resources.
- **KISS Method**: Avoid over-engineering. Choose the simplest, most maintainable solution.
- **SRE Focus**: Every change must consider **Uptime**, **Stability**, and **Latency**.
- **Concise Communication**: Keep explanations brief and technical.

## Architecture Overview

This repository manages a Proxmox-based homelab using Ansible for configuration management and Terraform for infrastructure provisioning.

**Infrastructure Components:**

- **Proxmox hosts** (tika, bupu, sturm): Physical servers running VMs and LXC containers
- **LXC containers**: tailscale (subnet router), plex (media server), kaz (Docker host)
- **VMs**: Kubernetes cluster nodes managed via Terraform

## Secrets Management (Doppler)

- **Source of Truth**: All secrets are stored in **Doppler**.
- **No Local Files**: Ansible Vault and 1Password integration have been decommissioned.
- **Usage**: Use `doppler run -- <command>` to inject secrets into the environment.

## Critical Workflows

**Environment Setup:**

```bash
# Install Ansible dependencies
task reqs

# Secrets are handled automatically via Doppler
# Ensure you have 'doppler' CLI installed and configured
```

**Deployment Commands:**

```bash
# Deploy to specific host groups (secrets handled by Task + Doppler)
task proxmox
task tailscale
task plex

# Run with check mode
task proxmox -- --check
```

## Project Conventions

**Ansible Patterns:**

- All tasks MUST have descriptive `name:` fields.
- Use `become: true` judiciously - review security implications.
- Use `loop` instead of `with_items` (deprecated).
- Custom roles in `roles/`, Galaxy roles in `galaxy_roles/` (gitignored).

**Terraform Patterns:**

- **Naming**: Use `snake_case` for resource names. Use `kebab-case` for file/folder names.
- **Resource Prefixes**: `sa-` (Service Account), `sneg-` (Serverless NEG), `lb-` (Load Balancer), `vpc-` (VPC), `db-` (Database).
- **Environment Suffixes**: `{name}-{env}` (e.g., `api-v3-dev`).
- **Descriptions**: All variables and outputs MUST have descriptions.
- **Architecture**: Always use Shared VPC architecture where applicable.

**General:**

- 2-space indentation.
- Max line length: 120 characters.

## Development Workflow

1. **Test first**: Use `--check` mode for Ansible or `terraform plan`.
2. **KISS**: If a solution feels complex, simplify it.
3. **Proactive**: If you add a host, ensure it's in the inventory and documented.
