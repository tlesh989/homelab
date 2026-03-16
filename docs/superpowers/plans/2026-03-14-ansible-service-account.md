# Ansible Service Account Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a dedicated `ansible` service account across all hosts (Proxmox + LXC/VMs) so all Ansible runs are fully non-interactive with no password prompts.

**Architecture:** New `roles/ansible-user` role creates the service account idempotently and is included in both `bootstrap.yml` (initial setup, as root/tommy) and every play in `main.yml` (self-healing, as ansible). `bootstrap.yml` gains two new plays using `tommy` + `su`/`sudo` escalation for existing hosts. `all.yml` switches `ansible_user` to `ansible` after bootstrap confirms all hosts have the account.

**Tech Stack:** Ansible, Doppler (secrets), Task (orchestration), ed25519 SSH keypair, Debian Bookworm (target hosts).

**Branch:** `feature/ansible-service-account`

**Spec:** `docs/superpowers/specs/2026-03-14-ansible-service-account-design.md`

---

## Chunk 1: `roles/ansible-user`

**Files:**
- Create: `roles/ansible-user/defaults/main.yml`
- Create: `roles/ansible-user/tasks/main.yml`
- Create: `roles/ansible-user/handlers/main.yml`

---

### Task 1: Role defaults

**Files:**
- Create: `roles/ansible-user/defaults/main.yml`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p roles/ansible-user/{defaults,tasks,handlers}
```

- [ ] **Step 2: Write defaults**

Create `roles/ansible-user/defaults/main.yml`:

```yaml
---
# defaults file for ansible-user

ansible_service_user: ansible
ansible_service_group: ansible
ansible_service_shell: /bin/bash
ansible_service_home: /home/ansible
```

- [ ] **Step 3: Syntax check**

```bash
task syntax
```

Expected: `playbook: main.yml` with no errors.

---

### Task 2: Role tasks

**Files:**
- Create: `roles/ansible-user/tasks/main.yml`

- [ ] **Step 1: Write tasks**

Create `roles/ansible-user/tasks/main.yml`:

```yaml
---
# tasks file for ansible-user — create and maintain ansible service account

- name: Create ansible group
  ansible.builtin.group:
    name: "{{ ansible_service_group }}"
    state: present

- name: Create ansible user
  ansible.builtin.user:
    name: "{{ ansible_service_user }}"
    group: "{{ ansible_service_group }}"
    shell: "{{ ansible_service_shell }}"
    home: "{{ ansible_service_home }}"
    password: "!"
    create_home: true
    state: present

- name: Ensure .ssh directory exists for ansible user
  ansible.builtin.file:
    path: "{{ ansible_service_home }}/.ssh"
    state: directory
    owner: "{{ ansible_service_user }}"
    group: "{{ ansible_service_group }}"
    mode: "0700"

- name: Deploy ansible SSH public key
  ansible.posix.authorized_key:
    user: "{{ ansible_service_user }}"
    key: "{{ lookup('env', 'ANSIBLE_SSH_PUBLIC_KEY') }}"
    state: present
    exclusive: true

- name: Configure NOPASSWD sudo for ansible user
  ansible.builtin.copy:
    dest: /etc/sudoers.d/ansible
    content: "{{ ansible_service_user }} ALL=(ALL) NOPASSWD: ALL\n"
    mode: "0440"
    validate: visudo -cf %s
```

- [ ] **Step 2: Write handlers (empty — no handlers needed)**

Create `roles/ansible-user/handlers/main.yml`:

```yaml
---
# handlers file for ansible-user
```

- [ ] **Step 3: Syntax check**

```bash
task syntax
```

Expected: no errors.

- [ ] **Step 4: Lint**

```bash
task lint
```

Expected: 0 failures, 0 warnings. Fix any issues before proceeding.

- [ ] **Step 5: Commit**

```bash
git add roles/ansible-user/
git commit -m "feat: add roles/ansible-user for service account management"
```

---

## Chunk 2: `bootstrap.yml` Redesign

**Files:**
- Modify: `bootstrap.yml`

**Context:** Existing `bootstrap.yml` has one play connecting as `root` + `ROOT_PASSWORD` with `ignore_unreachable: true`. It runs `buluma.roles.bootstrap` for fresh OS setup. We append two new plays that connect as `tommy` (SSH key) and escalate via `su` (Proxmox) or `sudo` (LXC) to create the ansible user. For existing hosts where root SSH is disabled, Play 1 fails silently; Plays 2/3 handle them.

---

### Task 3: Append ansible-user bootstrap plays

**Files:**
- Modify: `bootstrap.yml`

- [ ] **Step 1: Append Proxmox play**

Add to the end of `bootstrap.yml`:

```yaml
- name: Bootstrap Proxmox nodes — create ansible service account
  hosts: proxmox
  gather_facts: false
  ignore_unreachable: true
  become: true
  vars:
    ansible_user: tommy
    ansible_ssh_private_key_file: "{{ lookup('env', 'HOME') }}/.ssh/id_ed25519"
    ansible_become: true
    ansible_become_method: su
    ansible_become_exe: "su -"
    ansible_become_pass: "{{ lookup('env', 'BOOTSTRAP_PASS') }}"
  tasks:
    - name: Check if ansible user already exists
      ansible.builtin.command: getent passwd ansible
      register: bootstrap_ansible_user_check
      failed_when: false
      changed_when: false

    - name: Create ansible service account
      ansible.builtin.include_role:
        name: ansible-user
      when: bootstrap_ansible_user_check.rc != 0

- name: Bootstrap LXC and VM hosts — create ansible service account
  hosts: lxc:kaz
  gather_facts: false
  ignore_unreachable: true
  become: true
  vars:
    ansible_user: tommy
    ansible_ssh_private_key_file: "{{ lookup('env', 'HOME') }}/.ssh/id_ed25519"
    ansible_become_method: sudo
  tasks:
    - name: Check if ansible user already exists
      ansible.builtin.command: getent passwd ansible
      register: bootstrap_ansible_user_check
      failed_when: false
      changed_when: false

    - name: Create ansible service account
      ansible.builtin.include_role:
        name: ansible-user
      when: bootstrap_ansible_user_check.rc != 0
```

- [ ] **Step 2: Syntax check**

```bash
task syntax
```

Expected: no errors.

- [ ] **Step 3: Lint**

```bash
task lint
```

Expected: 0 failures, 0 warnings.

- [ ] **Step 4: Commit**

```bash
git add bootstrap.yml
git commit -m "feat: add ansible service account bootstrap plays to bootstrap.yml"
```

---

## Chunk 3: Wire Up — group_vars, main.yml, Taskfile

**Files:**
- Modify: `group_vars/all.yml`
- Modify: `main.yml`
- Modify: `Taskfile.yml`

> **Important:** These changes switch `ansible_user` to `ansible`. Do NOT merge or run
> `task proxmox` until the manual steps in the spec are complete AND `task bootstrap`
> has been run successfully against all hosts.

---

### Task 4: Update `group_vars/all.yml`

**Files:**
- Modify: `group_vars/all.yml`

- [ ] **Step 1: Switch ansible_user and add key file**

In `group_vars/all.yml`, replace:

```yaml
ansible_python_interpreter: auto_silent
ansible_user: "{{ lookup('env', 'SSH_USER') }}"
```

With:

```yaml
ansible_python_interpreter: auto_silent
ansible_user: ansible
ansible_ssh_private_key_file: ~/.ssh/ansible_ed25519
```

- [ ] **Step 2: Syntax check**

```bash
task syntax
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add group_vars/all.yml
git commit -m "feat: switch ansible_user to ansible service account"
```

---

### Task 5: Add `roles/ansible-user` to every play in `main.yml`

**Files:**
- Modify: `main.yml`

The role is added to every play for self-healing. It runs as `ansible` (which has NOPASSWD sudo) and is fully idempotent — module-level idempotency means no `when` guard is needed.

- [ ] **Step 1: Add role to proxmox play**

In `main.yml`, in the `setup proxmox hosts` play, add `role: ansible-user` immediately after `role: proxmox`:

```yaml
- name: setup proxmox hosts
  hosts: proxmox
  become: true
  roles:
    - role: proxmox
    - role: buluma.roles.bootstrap
    - role: GROG.package
    - role: users
    - role: artis3n.tailscale.machine
      when: not ansible_check_mode
    - role: install_script
    - role: r8152
      tags: [r8152]
    - role: ansible-user
```

`ansible-user` is placed last in the proxmox play so the OS baseline (`buluma.roles.bootstrap`),
packages, users, and sshd config are all settled before the service account is written.
This avoids any risk of sudoers or sshd config being reset by a subsequent hardening role.

- [ ] **Step 2: Add role to tailscale play**

In the `setup tailscale server` play, add `role: ansible-user` as the first role:

```yaml
- name: setup tailscale server
  hosts: tailscale
  become: true
  roles:
    - role: ansible-user
    - role: geerlingguy.ntp
    ...
```

- [ ] **Step 3: Add role to kaz play**

In the `setup docker server` play, add `role: ansible-user` as the first role:

```yaml
- name: setup docker server
  hosts: kaz
  become: true
  roles:
    - role: ansible-user
    - role: GROG.package
    ...
```

- [ ] **Step 4: Add role to plex play**

In the `setup plex server` play, add `role: ansible-user` as the first role:

```yaml
- name: setup plex server
  hosts: plex
  become: true
  roles:
    - role: ansible-user
    - role: GROG.package
    ...
```

- [ ] **Step 5: Add role to glance play**

In the `setup glance server` play, add `role: ansible-user` as the first role:

```yaml
- name: setup glance server
  hosts: glance
  become: true
  roles:
    - role: ansible-user
    - role: GROG.package
    ...
```

- [ ] **Step 6: Syntax check**

```bash
task syntax
```

Expected: no errors.

- [ ] **Step 7: Lint**

```bash
task lint
```

Expected: 0 failures, 0 warnings.

- [ ] **Step 8: Commit**

```bash
git add main.yml
git commit -m "feat: add ansible-user role to all plays for self-healing"
```

---

### Task 6: Update `Taskfile.yml`

**Files:**
- Modify: `Taskfile.yml`

- [ ] **Step 1: Add `setup` task**

In `Taskfile.yml`, add the `setup` task after the `reqs` task:

```yaml
  setup:
    desc: Write ansible SSH private key from Doppler to ~/.ssh/ansible_ed25519 (run once per machine)
    cmds:
      - doppler run -- sh -c 'mkdir -p ~/.ssh && printf "%s" "$ANSIBLE_SSH_PRIVATE_KEY" > ~/.ssh/ansible_ed25519 && chmod 600 ~/.ssh/ansible_ed25519'
```

Note: `printf "%s"` is used instead of `echo` to avoid appending a trailing newline that would corrupt the key file.

- [ ] **Step 2: Replace `bootstrap` task**

Replace the existing `bootstrap` task:

```yaml
  bootstrap:
    desc: Bootstrap new servers (run once on fresh deployments)
    cmds:
      - doppler run -- ansible-playbook bootstrap.yml {{.CLI_ARGS}}
```

The `doppler run --` wrapper injects `ROOT_PASSWORD`, `BOOTSTRAP_PASS`, and `ANSIBLE_SSH_PUBLIC_KEY` into the environment so bootstrap.yml can access them.

- [ ] **Step 3: Syntax check and lint**

```bash
task syntax && task lint
```

Expected: no errors, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add Taskfile.yml
git commit -m "feat: add task setup for ansible SSH key provisioning, update bootstrap task"
```

---

## Post-Implementation Verification

> **Before pushing the PR**, confirm the spec's manual steps have been completed by the operator
> and bootstrap has run. These verification steps require a live environment.

- [ ] **Verify key is written locally**

```bash
ls -la ~/.ssh/ansible_ed25519
```

Expected: `-rw------- 1 tommy staff ... ansible_ed25519`

- [ ] **Ping all hosts**

```bash
task ping
```

Expected: all hosts `SUCCESS` — confirms ansible user SSH auth works.

- [ ] **Dry-run all plays**

```bash
task check
```

Expected: no failures. ansible-user tasks should show `ok` (no change).

- [ ] **Verify NOPASSWD sudo**

```bash
ssh ansible@bupu.tlesh.xyz sudo whoami
```

Expected: `root` with no password prompt.

- [ ] **Validate sudoers syntax on each Proxmox node**

```bash
for h in bupu.tlesh.xyz tika.tlesh.xyz sturm.tlesh.xyz; do
  echo "=== $h ===" && ssh ansible@$h sudo visudo -c
done
```

Expected: `>>> /etc/sudoers: parsed OK` for each host.

- [ ] **Confirm tommy still works**

```bash
ssh tommy@bupu.tlesh.xyz echo "tommy ok"
```

Expected: `tommy ok` — human access unaffected.

- [ ] **Re-run bootstrap (idempotency)**

```bash
task bootstrap
```

Expected: ansible-user tasks show `skipped` for all hosts where user already exists.

- [ ] **Push branch and open PR**

```bash
git push -u origin feature/ansible-service-account
gh pr create --base dev --title "feat: dedicated ansible service account for non-interactive automation" \
  --body "Adds roles/ansible-user, redesigns bootstrap.yml, switches ansible_user to dedicated service account. See docs/superpowers/specs/2026-03-14-ansible-service-account-design.md for operator manual steps."
```
