# Terraform Instructions

See root `CLAUDE.md` for general project conventions, gitflow rules, and shared standards.

## Overview

- Provider: `bpg/proxmox`. State managed in Terraform Cloud (`tlesh-net` org).
- Configs split by service (e.g., `plex.tf`, `pi-hole.tf`).
- Provider versions pinned in `versions.tf`.
- Secrets injected via Doppler — never use `.tfvars` or hardcode values.

## Commands

Run from the `terraform/` directory:

```bash
task        # fmt + validate (same as task test)
task init   # Initialize with Doppler secrets
task plan   # Generate execution plan (requires init)
task apply  # Apply plan (requires task plan first)
task test   # Format and validate only
task ci     # CI check (no Doppler)
```

## Conventions

- **Resource Labels**: `snake_case` (e.g., `proxmox_nfs`).
- **Infrastructure IDs**: `kebab-case` (e.g., `storage_id = "proxmox-nfs"`).
- **Resource Prefixes**: `sa-`, `sneg-`, `lb-`, `vpc-`, `db-`.
- Mandatory `description` on all variables and outputs.
- Pin all provider versions in `versions.tf`.

## Verification (Definition of Done)

- `task test` (fmt + validate) passes.
- `task plan` reviewed and approved before apply.
- CI passes on GitHub after push.
