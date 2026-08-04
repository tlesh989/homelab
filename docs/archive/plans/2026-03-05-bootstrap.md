# Bootstrap Role Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a `roles/bootstrap/` Ansible role and `bootstrap.yml` playbook that provisions a named user with sudo and SSH key access on freshly deployed servers, hardens SSH, and migrates all plays away from root login.

**Architecture:** `bootstrap.yml` runs first (via `import_playbook` in `main.yml`) connecting as root using `ROOT_PASSWORD` from Doppler. It creates the `SSH_USER` account, installs the SSH key, and disables root/password SSH access. Subsequent plays in `main.yml` connect as `SSH_USER` (set in `group_vars/all.yml`). `ignore_unreachable: true` ensures already-bootstrapped hosts are silently skipped.

**Tech Stack:** Ansible, Doppler (secret injection via `doppler run --`), Task (Taskfile.yml), `geerlingguy.security` (existing), `ansible.posix.authorized_key` (existing).

---

## Prerequisites (Manual — do before writing any code)

1. In the Doppler dashboard, rename `MKPASSWD_USER` → `SSH_USER_PASS`. Change the value from the pre-hashed string to the **plaintext** password. Ansible will hash it at runtime.
2. Confirm these secrets exist in Doppler: `SSH_USER`, `ROOT_PASSWORD`, `SSH_PUBLIC_KEY`, `SSH_USER_PASS`.

---

### Task 1: Create feature branch and role skeleton

#### Files

- Create: `roles/bootstrap/tasks/main.yml`
- Create: `roles/bootstrap/handlers/main.yml`

#### Step 1: Create the feature branch

```bash
git checkout dev
git pull
git checkout -b feature/bootstrap-role
```

#### Step 2: Create the role directory structure

```bash
mkdir -p roles/bootstrap/tasks roles/bootstrap/handlers
```

#### Step 3: Create an empty tasks file

```yaml
# roles/bootstrap/tasks/main.yml
---
```

#### Step 4: Create an empty handlers file

```yaml
# roles/bootstrap/handlers/main.yml
---
```

#### Step 5: Verify syntax (should pass on empty files)

```bash
task syntax
```

Expected: no errors.

#### Step 6: Commit

```bash
git add roles/bootstrap/
git commit -m "chore: scaffold bootstrap role structure"
```

---

### Task 2: Implement bootstrap role tasks

#### Files

- Modify: `roles/bootstrap/tasks/main.yml`

#### Step 1: Write the tasks

```yaml
# roles/bootstrap/tasks/main.yml
---
- name: Create user account
  ansible.builtin.user:
    name: "{{ lookup('env', 'SSH_USER') }}"
    shell: /bin/bash
    password: "{{ lookup('env', 'SSH_USER_PASS') | password_hash('sha512') }}"
    groups: sudo
    append: true
    state: present

- name: Configure passwordless sudo
  ansible.builtin.copy:
    dest: "/etc/sudoers.d/{{ lookup('env', 'SSH_USER') }}"
    content: "{{ lookup('env', 'SSH_USER') }} ALL=(ALL) NOPASSWD: ALL\n"
    mode: "0440"
    validate: "visudo -cf %s"

- name: Install SSH authorized key
  ansible.posix.authorized_key:
    user: "{{ lookup('env', 'SSH_USER') }}"
    key: "{{ lookup('env', 'SSH_PUBLIC_KEY') }}"
    state: present

- name: Disable SSH password authentication
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "^#?PasswordAuthentication"
    line: "PasswordAuthentication no"
    state: present
  notify: Restart sshd

- name: Disable SSH root login
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "^#?PermitRootLogin"
    line: "PermitRootLogin no"
    state: present
  notify: Restart sshd
```

#### Step 2: Implement the sshd restart handler

```yaml
# roles/bootstrap/handlers/main.yml
---
- name: Restart sshd
  ansible.builtin.service:
    name: sshd
    state: restarted
```

#### Step 3: Verify syntax

```bash
task syntax
```

Expected: no errors.

#### Step 4: Commit

```bash
git add roles/bootstrap/
git commit -m "feat: implement bootstrap role tasks and handler"
```

---

### Task 3: Create bootstrap.yml playbook

#### Files

- Create: `bootstrap.yml`

#### Step 1: Write the playbook

```yaml
# bootstrap.yml
---
- name: Bootstrap new servers
  hosts: all
  gather_facts: false
  ignore_unreachable: true
  vars:
    ansible_user: root
    ansible_password: "{{ lookup('env', 'ROOT_PASSWORD') }}"
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
  roles:
    - role: bootstrap
```

Key decisions:

- `gather_facts: false` — avoids hanging when root is already disabled on a host.
- `ignore_unreachable: true` — already-bootstrapped hosts fail silently; `main.yml` continues to subsequent plays.
- `ansible_user: root` / `ansible_password` — overrides the `SSH_USER` set in `group_vars/all.yml` for this play only.
- `StrictHostKeyChecking=no` — allows connecting to brand-new hosts not yet in `~/.ssh/known_hosts`.

#### Step 2: Verify syntax

```bash
doppler run -- ansible-playbook bootstrap.yml --syntax-check
```

Expected: `playbook: bootstrap.yml` with no errors.

#### Step 3: Commit

```bash
git add bootstrap.yml
git commit -m "feat: add bootstrap.yml playbook"
```

---

### Task 4: Update main.yml

#### Files

- Modify: `main.yml`

Two changes: prepend `import_playbook` and remove all `vars_files` blocks.

#### Step 1: Add import_playbook as the first entry

The file currently starts with:

```yaml
---
- name: initial setup
  ...
```

Change it to:

```yaml
---
- import_playbook: bootstrap.yml

- name: initial setup
  ...
```

#### Step 2: Remove all `vars_files` blocks

Find and remove every occurrence of:

```yaml
  vars_files:
    - vars/vault.yml
```

This appears in the following plays: `setup proxmox hosts`, `setup tailscale server`, `setup docker server`, `setup plex server`, `setup glance server`.

#### Step 3: Verify syntax

```bash
task syntax
```

Expected: no errors.

#### Step 4: Commit

```bash
git add main.yml
git commit -m "feat: import bootstrap playbook in main.yml, remove vault vars_files"
```

---

### Task 5: Update group_vars/all.yml

#### Files

- Modify: `group_vars/all.yml`

This is the largest change. Make each substitution carefully.

#### Step 1: Add ansible_ssh_user at the top

After `ansible_python_interpreter: auto_silent`, add:

```yaml
ansible_ssh_user: "{{ lookup('env', 'SSH_USER') }}"
```

#### Step 2: Update users_list

Replace the entire `users_list` block:

```yaml
# Before
users_list:
  - username: "{{ vault_username }}"
    password: "{{ lookup('env', 'MKPASSWD_USER') }}"
    shell: /bin/bash
    users_group: "{{ vault_username }}"
    authorized_keys:
      - "{{ lookup('file', my_home ~ '/.ssh/id_ed25519_tlesh.pub') }}"
```

```yaml
# After
users_list:
  - username: "{{ lookup('env', 'SSH_USER') }}"
    password: "{{ lookup('env', 'SSH_USER_PASS') | password_hash('sha512') }}"
    shell: /bin/bash
    users_group: "{{ lookup('env', 'SSH_USER') }}"
    authorized_keys:
      - "{{ lookup('env', 'SSH_PUBLIC_KEY') }}"
```

#### Step 3: Update security_sudoers_passwordless

```yaml
# Before
security_sudoers_passwordless:
  - "{{ vault_username }}"
```

```yaml
# After
security_sudoers_passwordless:
  - "{{ lookup('env', 'SSH_USER') }}"
```

#### Step 4: Flip SSH security vars

```yaml
# Before
security_ssh_permit_root_login: "yes"
security_ssh_password_authentication: "yes"
```

```yaml
# After
security_ssh_permit_root_login: "no"
security_ssh_password_authentication: "no"
```

#### Step 5: Update docker_compose_generator_output_path

```yaml
# Before
docker_compose_generator_output_path: "/home/{{ vault_username }}"
```

```yaml
# After
docker_compose_generator_output_path: "/home/{{ lookup('env', 'SSH_USER') }}"
```

#### Step 6: Verify no remaining vault_username references

```bash
grep -r "vault_username" .
```

Expected: no output.

#### Step 7: Verify no remaining MKPASSWD_USER references

```bash
grep -r "MKPASSWD_USER" .
```

Expected: no output.

#### Step 8: Verify syntax

```bash
task syntax
```

Expected: no errors.

#### Step 9: Commit

```bash
git add group_vars/all.yml
git commit -m "feat: migrate vault_username and MKPASSWD_USER to Doppler env vars"
```

---

### Task 6: Update hosts file

#### Files

- Modify: `hosts`

#### Step 1: Remove ansible_ssh_user=root from both var sections

```ini
# Before
[proxmox:vars]
ansible_ssh_user=root

[lxc:vars]
ansible_ssh_user=root
```

```ini
# After
# (remove both [proxmox:vars] and [lxc:vars] sections entirely,
#  or leave empty if other vars exist — currently they don't)
```

Since `ansible_ssh_user=root` is the only content in both `[proxmox:vars]` and `[lxc:vars]`, remove those section headers and their contents entirely.

#### Step 2: Verify syntax

```bash
task syntax
```

Expected: no errors.

#### Step 3: Commit

```bash
git add hosts
git commit -m "chore: remove root ansible_ssh_user from hosts, now in group_vars/all.yml"
```

---

### Task 7: Add bootstrap task to Taskfile.yml

#### Files

- Modify: `Taskfile.yml`

#### Step 1: Add the bootstrap task

Add after the `reqs` task:

```yaml
  bootstrap:
    desc: Bootstrap new servers (run once on fresh deployments)
    cmds:
      - doppler run -- ansible-playbook bootstrap.yml {{.CLI_ARGS}}
```

Note: no `-b` flag. Bootstrap connects directly as root — `become` is not used.

#### Step 2: Verify task appears in listing

```bash
task
```

Expected: `bootstrap` appears in the task list with its description.

#### Step 3: Commit

```bash
git add Taskfile.yml
git commit -m "chore: add bootstrap task to Taskfile"
```

---

### Task 8: Delete vars/vault.yml

#### Files

- Delete: `vars/vault.yml`

#### Step 1: Confirm nothing references vault.yml

```bash
grep -r "vault.yml" .
```

Expected: no output (we removed all `vars_files` references in Task 4).

#### Step 2: Delete the file

```bash
git rm vars/vault.yml
```

#### Step 3: Verify syntax one final time

```bash
task syntax
```

Expected: no errors.

#### Step 4: Commit

```bash
git commit -m "chore: delete legacy vars/vault.yml"
```

---

### Task 9: Lint and dry-run validation

#### Step 1: Run ansible-lint

```bash
task lint
```

Fix any warnings before continuing. Common issues: `name:` casing, `no-free-form`, FQCN module names.

#### Step 2: Run syntax check

```bash
task syntax
```

Expected: clean pass.

#### Step 3: Run dry-run against all hosts

```bash
task check
```

Note: bootstrap play will show tasks as changed (since it connects as root and hosts are already running). Subsequent plays will connect as `SSH_USER` — if SSH keys are already installed on your hosts, this should pass. If not, the check will fail on connection for those plays (expected — they need to be bootstrapped first for real).

#### Step 4: Commit design docs

```bash
git add docs/plans/
git commit -m "docs: add bootstrap design and implementation plan"
```

---

### Task 10: Live test on a single host

#### Step 1: Run bootstrap against one host only

Pick a non-critical host (e.g., `glance`):

```bash
task bootstrap -- --limit glance.tlesh.xyz
```

Expected: user created, SSH key installed, sshd hardened, handler fires to restart sshd.

#### Step 2: Verify SSH access as SSH_USER

```bash
ssh tommy@glance.tlesh.xyz
```

Expected: login succeeds without password prompt (key auth).

#### Step 3: Verify sudo works

```bash
ssh tommy@glance.tlesh.xyz "sudo whoami"
```

Expected: `root` (no password prompt).

#### Step 4: Verify root login is disabled

```bash
ssh root@glance.tlesh.xyz
```

Expected: `Permission denied` or `Connection refused`.

#### Step 5: Run main.yml against the same host to verify normal plays work

```bash
task glance
```

Expected: all tasks pass connecting as `SSH_USER` with `become: true`.

#### Step 6: Run bootstrap again to verify idempotency

```bash
task bootstrap -- --limit glance.tlesh.xyz
```

Expected: all tasks show `ok` (no changes). No errors.

---

### Task 11: Ship

Once all hosts are bootstrapped and validated:

```bash
/ship "feat: add bootstrap role for new server provisioning, migrate from root to SSH_USER"
```
