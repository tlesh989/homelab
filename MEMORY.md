# Project Memory

This file tracks architectural decisions, legacy transitions, and core tradeoffs for the `homelab` repository.

## Core Architecture

- **Hypervisor**: Proxmox VE.
- **Provisioning**: Terraform (bpg/proxmox provider) with state in Terraform Cloud.
- **Configuration**: Ansible (master-playbook pattern).
- **Secrets**: Doppler is the single provider for all environments.

## Major Decisions & Tradeoffs

### 2024-Q3: Migration to Doppler

- **Decision**: Removed `vars/vault.yml` and `.vault_pass`.
- **Reason**: Centralized secret management, easier CI integration, and rotation capabilities.

### 2024-Q4: Proxmox Provider Pivot

- **Decision**: Switched to `bpg/proxmox`.
- **Reason**: Better support for LXC and modern Proxmox features compared to older providers.

### 2025-Q1: Single Branch Flow (Current Transition)

- **Decision**: Moving from `dev/main` Gitflow to single-branch `main` strategy.
- **Reason**: Reducing friction in PR cycles and branch synchronization issues.

## Legacy Debt & Patterns

- **Ansible Galaxy**: Roles are currently a mix of local custom roles and Galaxy dependencies managed via `requirements.yml`.
- **Tailscale**: Subnet routers are deployed via Ansible but policies are managed via `tailscale/policy.hujson`.
