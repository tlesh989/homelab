---
name: new-service
description: Scaffold a new homelab service — Terraform LXC config + Ansible role skeleton
user-invocable: true
disable-model-invocation: true
arguments:
  - name: name
    description: "Service name in kebab-case (e.g. uptime-kuma)"
    required: true
---

# New Service Scaffold

When the user runs `/new-service <name>`, scaffold a complete new homelab service.

## Steps

1. **Confirm** with the user: service name, target Proxmox node (bupu/sturm/tika), IP address, and VM ID.

2. **Create `terraform/<name>.tf`** — model after `terraform/glance.tf`:
   - Resource labels in `snake_case` (e.g. `proxmox_lxc_<name>`)
   - IDs and storage references in `kebab-case`
   - Mandatory `description` on all variables and outputs
   - Pin to correct Proxmox node based on user input

3. **Create `roles/<name>/`** skeleton:
   - `tasks/main.yml` — placeholder task with mandatory `name:` field and `become: true` where appropriate
   - `defaults/main.yml` — empty defaults with a comment placeholder
   - No README (keep it simple unless asked)

4. **Add host to `hosts` file** under a new `[<name>]` group with the IP provided.

5. **Create `group_vars/<name>.yml`** stub with a comment placeholder.

6. **Remind the user** to:
   - Add `task <name>` entry to `Taskfile.yml` (copy structure from an existing task)
   - Include the new role in `main.yml` under the appropriate hosts
   - Add Doppler secrets if needed
   - Run `task check` after wiring everything up

## Conventions

- File/folder names: `kebab-case`
- Terraform resource labels: `snake_case`
- Infrastructure IDs: `kebab-case`
- 2-space indentation, max 120 char lines
- Every Ansible task must have a `name:` field
