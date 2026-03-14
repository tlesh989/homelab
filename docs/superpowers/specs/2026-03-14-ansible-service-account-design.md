# Ansible Service Account — Design Spec

**Date:** 2026-03-14
**Status:** Approved
**Beads:** TBD (new issue to be created)
**Author:** tommy

---

## Problem

Ansible currently connects as `tommy` with `--ask-become-pass` on Proxmox nodes, making
non-interactive automation (e.g. running playbooks from Claude Code) impossible. LXC hosts
already have NOPASSWD sudo for `tommy` via `geerlingguy.security`, but Proxmox nodes only
allow `su` escalation (no sudo). There is no consistent auth model across the fleet.

---

## Goals

- Single `ansible` service account across every host (Proxmox nodes + all LXC/VM instances)
- All Ansible runs fully non-interactive — no `--ask-become-pass`, no `--ask-pass`
- SSH keypair stored exclusively in Doppler; never committed to the repo
- `task setup` is the only manual step needed on a fresh Mac checkout
- Bootstrap is idempotent — safe to re-run; skips hosts already configured
- Self-healing — key rotation or sudoers drift corrected on every normal playbook run

## Non-Goals

- Removing the `tommy` human user (it stays for interactive SSH access)
- Changing the Terraform provisioning model for LXC containers
- Restricting `ansible` sudo to a specific command list (NOPASSWD:ALL is acceptable)

---

## Architecture Overview

```
Mac (Claude Code / terminal)
  │
  ├── task setup          pulls ANSIBLE_SSH_PRIVATE_KEY from Doppler
  │                       writes → ~/.ssh/ansible_ed25519 (chmod 600)
  │
  ├── task bootstrap      one-time per new host
  │   └── bootstrap.yml   connects as tommy + escalates to root
  │                       creates ansible user, deploys public key, sudoers
  │
  └── task proxmox / tailscale / plex / glance (all subsequent runs)
      └── main.yml        connects as ansible with SSH key
                          roles/ansible-user included in every play (self-healing)
```

---

## Doppler Secrets

Three new keys added to `homelab / main`:

| Key | Description |
|-----|-------------|
| `ANSIBLE_SSH_PRIVATE_KEY` | Full contents of `ansible_ed25519` private key |
| `ANSIBLE_SSH_PUBLIC_KEY` | Full contents of `ansible_ed25519.pub` |
| `BOOTSTRAP_PASS` | Root password — used for `su` escalation on Proxmox nodes during bootstrap only |

The keypair is generated once locally, uploaded to Doppler, then the local files are deleted.
The private key never touches the repo.

> **Security note:** `BOOTSTRAP_PASS` is only needed during the initial bootstrap run.
> Once all hosts are bootstrapped and verified, rotate or remove it from Doppler to reduce
> the ongoing credential exposure surface. Normal playbook runs never use it.

---

## `roles/ansible-user`

New idempotent role. Included in `bootstrap.yml` (runs as root) and in every play in
`main.yml` (runs as ansible for self-healing).

### `defaults/main.yml`

```yaml
ansible_service_user: ansible
ansible_service_group: ansible
ansible_service_shell: /bin/bash
ansible_service_home: /home/ansible
```

### `tasks/main.yml`

1. Create `ansible` group
2. Create `ansible` user (no password, locked, shell `/bin/bash`, home `/home/ansible`)
3. Deploy `ANSIBLE_SSH_PUBLIC_KEY` (from env) to `~ansible/.ssh/authorized_keys` (mode 0600)
4. Write `/etc/sudoers.d/ansible`: `ansible ALL=(ALL) NOPASSWD: ALL` (mode 0440),
   validated with `validate: visudo -cf %s` to prevent sudoers corruption

The role is side-effect-free if the account already exists and the key/sudoers are correct —
every task uses the appropriate Ansible module with idempotent semantics. The role carries
**no idempotency gate** — it relies entirely on module-level idempotency, which makes it
safe to include in `main.yml` for self-healing without any `when` guards.

### `handlers/main.yml`

No handlers needed — all tasks use declarative modules.

---

## `bootstrap.yml` Redesign

Bootstrap connects as `tommy` (SSH key auth) and escalates to root. Two plays handle the
different escalation methods across the fleet.

### Idempotency gate (bootstrap.yml only)

```yaml
- name: Check if ansible user already exists
  ansible.builtin.command: getent passwd ansible
  register: bootstrap_ansible_user_check
  failed_when: false
  changed_when: false
```

If `rc == 0`, the `roles/ansible-user` include is skipped via
`when: bootstrap_ansible_user_check.rc != 0`. This gate lives **only in bootstrap.yml**
as a skip optimisation. The same role in `main.yml` runs unconditionally — module-level
idempotency handles drift correction without a gate.

### Play 1 — Proxmox nodes

```yaml
hosts: proxmox
vars:
  ansible_user: tommy
  ansible_ssh_private_key_file: "{{ lookup('env', 'HOME') }}/.ssh/id_ed25519"
  ansible_become: true
  ansible_become_method: su
  ansible_become_exe: "su -"
  ansible_become_pass: "{{ lookup('env', 'BOOTSTRAP_PASS') }}"
```

`tommy` can `su` to root on Proxmox nodes (root password = `BOOTSTRAP_PASS`). The `su`
become method is required because `tommy` has no sudo rights on Proxmox hosts.
`ansible_become_exe: "su -"` is required — Ansible's default `su` invocation does not
allocate a login shell and may hang waiting for a prompt over non-interactive SSH.

### Play 2 — LXC/VM hosts

```yaml
hosts: lxc:kaz
vars:
  ansible_user: tommy
  ansible_ssh_private_key_file: "{{ lookup('env', 'HOME') }}/.ssh/id_ed25519"
  ansible_become: true
  ansible_become_method: sudo
```

`tommy` already has NOPASSWD sudo on LXC hosts — no password needed.

Both plays include `roles/ansible-user` after the idempotency gate.

---

## `group_vars/all.yml` Changes

| Variable | Before | After |
|----------|--------|-------|
| `ansible_user` | `"{{ lookup('env', 'SSH_USER') }}"` | `ansible` |
| `ansible_ssh_private_key_file` | *(not set)* | `~/.ssh/ansible_ed25519` |

`SSH_USER`, `SSH_USER_PASS`, `SSH_PUBLIC_KEY` remain in Doppler and continue to be used
by the `users` role to manage the `tommy` human account. Only the Ansible connection
variables change.

---

## `main.yml` Changes

`roles/ansible-user` is added to every play, running as the `ansible` user itself
(which has NOPASSWD sudo). This ensures key rotation or sudoers drift is corrected
automatically on the next normal playbook run.

```yaml
# proxmox play
roles:
  - role: proxmox
  - role: ansible-user   # ← added (self-healing)
  - role: buluma.roles.bootstrap
  ...

# tailscale, kaz, plex, glance plays — same pattern
roles:
  - role: ansible-user   # ← added first in each play
  ...
```

---

## `Taskfile.yml` Changes

### New: `setup` task

```yaml
setup:
  desc: Provision local Ansible SSH key from Doppler (run once on fresh checkout)
  cmds:
    - doppler run -- sh -c 'mkdir -p ~/.ssh && echo "$ANSIBLE_SSH_PRIVATE_KEY" > ~/.ssh/ansible_ed25519 && chmod 600 ~/.ssh/ansible_ed25519'
```

`mkdir -p ~/.ssh` ensures the directory exists on a fresh Mac before the key is written.

### New: `bootstrap` task

```yaml
bootstrap:
  desc: Bootstrap new hosts — creates ansible service account (idempotent)
  cmds:
    - doppler run -- ansible-playbook bootstrap.yml {{.CLI_ARGS}}
```

The existing `bootstrap` task in the Taskfile already exists but uses a different form —
this replaces it with Doppler injection so `BOOTSTRAP_PASS` is available to the playbook.

---

## Manual Steps (operator todo list)

> **Order matters.** Steps 1–6 must complete before the code change is deployed (step 7),
> otherwise `all.yml` will reference `ansible_user: ansible` before the account exists
> and the SSH key is local — causing playbook failures across the fleet.

1. **Generate the ansible SSH keypair** on your Mac:
   ```bash
   ssh-keygen -t ed25519 -C "ansible service account" -f /tmp/ansible_ed25519 -N ""
   ```

2. **Add three secrets to Doppler** (`homelab / main`):
   - `ANSIBLE_SSH_PRIVATE_KEY` → paste contents of `/tmp/ansible_ed25519`
   - `ANSIBLE_SSH_PUBLIC_KEY` → paste contents of `/tmp/ansible_ed25519.pub`
   - `BOOTSTRAP_PASS` → the root password on your Proxmox nodes

3. **Delete local key files** — they now live only in Doppler:
   ```bash
   rm /tmp/ansible_ed25519 /tmp/ansible_ed25519.pub
   ```

4. **Run `task setup`** to write the private key to `~/.ssh/ansible_ed25519`

5. **Run `task bootstrap`** — creates the `ansible` user on all existing hosts

6. **Verify** all hosts respond as the `ansible` user:
   ```bash
   task ping
   # Expected: ansible@<host> | SUCCESS
   ```

7. **Deploy the code change** (new branch → PR → merge to dev):
   ```bash
   task ship "feat: add ansible service account with non-interactive auth"
   ```

8. **Run a full dry-run** to confirm normal playbook flow works end-to-end:
   ```bash
   task check
   ```

9. **Remove `BOOTSTRAP_PASS` from Doppler** — it is no longer needed after all hosts
   are bootstrapped. Rotate or delete it to reduce the credential exposure surface.

---

## Rollback

If something goes wrong after bootstrap but before verification:

```bash
# SSH as tommy (still works — tommy's key is unchanged)
ssh tommy@<host>

# Manually remove ansible user if needed
sudo deluser --remove-home ansible 2>/dev/null || su -c "deluser --remove-home ansible"
sudo rm -f /etc/sudoers.d/ansible
```

The `all.yml` change (`ansible_user: ansible`) can be reverted to
`"{{ lookup('env', 'SSH_USER') }}"` to restore the previous behaviour.

---

## Testing & Verification

| Check | Command |
|-------|---------|
| Key written locally | `ls -la ~/.ssh/ansible_ed25519` |
| Ping all hosts as ansible | `task ping` |
| Dry-run all plays | `task check` |
| Verify NOPASSWD sudo works | `ssh ansible@bupu.tlesh.xyz sudo whoami` → `root` |
| Validate sudoers syntax | `ssh ansible@bupu.tlesh.xyz sudo visudo -c` → `parsed OK` |
| Confirm tommy still works | `ssh tommy@bupu.tlesh.xyz` |
| Idempotency (re-run bootstrap) | `task bootstrap` — role tasks should show `skipped` |
| Self-healing (re-run proxmox) | `task proxmox` — ansible-user tasks should show `ok` (no change) |
