---
name: vault
description: "DEPRECATED: Ansible Vault and 1Password have been decommissioned. All secrets are now managed via Doppler."
user-invocable: true
---

# Vault Skill — DEPRECATED

Ansible Vault and 1Password CLI integration have been decommissioned.

All secrets are now managed via **Doppler**. The `task` commands automatically inject secrets via `doppler run`.

**To delete this skill:** `rm -rf .claude/skills/vault`
