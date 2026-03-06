# Bootstrap Role Design

**Date:** 2026-03-05
**Status:** Approved

## Problem

All hosts currently connect via Ansible as `root`, with SSH password authentication and root login
enabled. There is no automated process for provisioning a named user account on freshly deployed
servers before handing off to the main configuration plays.

## Goals

1. Bootstrap newly deployed servers by connecting as `root` and creating the `SSH_USER` account
   with sudo access and an SSH key.
2. Harden SSH: disable password authentication and root login.
3. Ensure all subsequent Ansible plays connect as `SSH_USER`, not `root`.
4. Clean up legacy `vault_username` and `vars/vault.yml` references in favour of Doppler secrets.

## Architecture

```text
main.yml
  └── import_playbook: bootstrap.yml   ← runs first, connects as root
  └── "setup proxmox hosts" play       ← connects as SSH_USER
  └── "setup tailscale server" play    ← connects as SSH_USER
  └── ...
```

### Bootstrap Behaviour

- `bootstrap.yml` connects as `root` using `ROOT_PASSWORD` from Doppler.
- `ignore_unreachable: true` at the play level means already-hardened hosts are silently skipped
  and Ansible continues to subsequent plays.
- `gather_facts: false` prevents hangs when root is unreachable.
- `StrictHostKeyChecking=no` handles brand-new hosts not yet in `known_hosts`.

### Role: `roles/bootstrap/`

Tasks run in order, all idempotent:

1. **Create user** — `ansible.builtin.user` with username `SSH_USER`, shell `/bin/bash`,
   password hashed at runtime via `password_hash('sha512')` from plaintext `SSH_USER_PASS`.
2. **Passwordless sudo** — drop `/etc/sudoers.d/<SSH_USER>` with `NOPASSWD: ALL`, validated
   before install.
3. **Install SSH key** — `ansible.posix.authorized_key` using `SSH_PUBLIC_KEY` from env.
4. **Harden sshd** — `lineinfile` tasks set `PasswordAuthentication no` and `PermitRootLogin no`.
5. **Restart sshd** — handler triggered only when sshd config changes.

`geerlingguy.security` remains in `main.yml` plays only (not bootstrap) because:

- It requires gathered facts for OS detection.
- Its broader scope (fail2ban, unattended upgrades) belongs in full configuration, not bootstrap.
- The `group_vars/all.yml` security vars are updated to `"no"` so it enforces the same hardened
  state on every subsequent run.

## Doppler Secrets

| Secret          | Value type | Used by                          |
|-----------------|------------|----------------------------------|
| `ROOT_PASSWORD` | plaintext  | bootstrap play connection        |
| `SSH_USER`      | plaintext  | bootstrap + `group_vars/all.yml` |
| `SSH_PUBLIC_KEY`| plaintext  | bootstrap role                   |
| `SSH_USER_PASS` | plaintext  | bootstrap + users role (hashed at runtime) |

`SSH_USER_PASS` replaces `MKPASSWD_USER`. Store the plaintext password in Doppler; Ansible applies
`password_hash('sha512')` at runtime.

## Files Changed

| File                                | Change                                                                    |
|-------------------------------------|---------------------------------------------------------------------------|
| `bootstrap.yml`                     | New — runs `roles/bootstrap/` as root against all hosts                   |
| `roles/bootstrap/tasks/main.yml`    | New — user, sudoers, SSH key, sshd hardening tasks                        |
| `roles/bootstrap/handlers/main.yml` | New — restart sshd handler                                                |
| `main.yml`                          | Prepend `import_playbook: bootstrap.yml`; remove all `vars_files` blocks  |
| `group_vars/all.yml`                | Replace `vault_username` refs; rename `MKPASSWD_USER`; add `ansible_ssh_user`; flip SSH security vars to `"no"` |
| `hosts`                             | Remove `ansible_ssh_user=root` from `[proxmox:vars]` and `[lxc:vars]`    |
| `vars/vault.yml`                    | Delete                                                                    |
| `Taskfile.yml`                      | Add `bootstrap` task (no `-b` flag)                                       |

## Taskfile

```yaml
bootstrap:
  desc: Bootstrap new servers (run once on fresh deployments)
  cmds:
    - doppler run -- ansible-playbook bootstrap.yml {{.CLI_ARGS}}
```

## Doppler Setup Required

Before running bootstrap on any host:

1. Rename `MKPASSWD_USER` → `SSH_USER_PASS` in the Doppler dashboard (store plaintext value).
2. Ensure `SSH_USER`, `ROOT_PASSWORD`, and `SSH_PUBLIC_KEY` are present in Doppler.
