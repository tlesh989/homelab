---
name: vault
description: "Safely decrypt, edit, and re-encrypt Ansible Vault files"
user-invocable: true
---

# Vault Skill

Safely work with encrypted Ansible Vault files. Ensures files are always re-encrypted before finishing.

## Steps

1. Run `task vault_pass` to ensure `.vault_pass` exists (fetches from 1Password)
2. Run `task decrypt` to decrypt `vars/vault.yml` and `.envrc`
3. Make the requested edits to `vars/vault.yml` or `.envrc`
4. Run `task encrypt` to re-encrypt both files
5. Verify encryption: `head -1 vars/vault.yml` should show `$ANSIBLE_VAULT;`

## Rules

- NEVER leave vault files decrypted — always re-encrypt before finishing
- NEVER commit decrypted vault files
- If any step fails, attempt to re-encrypt before reporting the error
- The PreToolUse hook blocks direct edits to these files — you MUST use `task decrypt` first and `task encrypt` after
