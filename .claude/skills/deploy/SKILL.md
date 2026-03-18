---
name: deploy
description: "Run Ansible playbook with dry-run verification first"
user-invocable: true
arguments:
  - name: target
    description: "Host group to deploy to (proxmox, tailscale, plex, glance)"
    required: true
---

# Deploy Skill

Run a safe two-step deploy: dry-run first, then apply only if the user confirms.

## Steps

1. Validate that `{{target}}` is one of: proxmox, tailscale, plex, glance
2. Run `task {{target}} -- --check` to perform a dry-run
3. Show the user the output and ask for explicit confirmation before proceeding
4. Only if the user confirms, run `task {{target}}` to apply

## Rules

- NEVER skip the dry-run step
- NEVER proceed to apply without showing dry-run output and getting user confirmation
- If the dry-run shows errors, stop and help the user fix them before retrying
- Both commands require SSH password input (`--ask-pass`), so the user must be at the terminal
