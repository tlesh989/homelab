# Claude Code LXC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a dedicated Ubuntu 24.04 LXC on tika with Claude Code, the Ansible SSH key on disk, and `gh` CLI for remote homelab management over Tailscale.

**Architecture:** New Ansible role `roles/claude-code` applied to a manually-created LXC. Role installs Node.js 20 + Claude Code + gh CLI + Doppler, creates the `tommy` user with passwordless sudo, writes the Ansible SSH private key from Doppler to disk, and clones the homelab repo. A new play in `main.yml` and task in `Taskfile.yml` wire it into the standard deploy workflow.

**Tech Stack:** Ansible, Ubuntu 24.04 LXC, Node.js 20 (NodeSource), Claude Code CLI, gh CLI, Doppler CLI

## Global Constraints

- All secrets sourced from Doppler — never hardcoded
- `mode:` required on all file/copy tasks (ansible-lint enforces this)
- Every task must have a descriptive `name:` field
- `task syntax` and `task lint` must pass after every commit
- Use `become: true` at task level, not play level

---

### Task 1: Provision LXC and add to inventory

**Files:**
- Modify: `hosts`
- Modify: `main.yml`

**Note:** LXC creation is a manual Proxmox UI step. This task covers that plus wiring the new host into Ansible.

- [ ] **Step 1: Create LXC in Proxmox UI on tika**

  In the Proxmox web UI on tika:
  - Click **Create CT**
  - Template: Ubuntu 24.04
  - Hostname: `claude-code`
  - Password: (set something, won't be used after bootstrap)
  - CPU: 1 core
  - Memory: 1024 MB
  - Disk: 10 GB on local-lvm
  - Network: DHCP first, then set static — bridge `vmbr0`, IP `192.168.233.25/24`, gateway `192.168.233.1`
  - DNS: `192.168.233.3` (pi-hole)
  - Start after creation: yes

- [ ] **Step 2: Add host to inventory**

  In `hosts`, add the host declaration near the top with other `.tlesh.xyz` hosts:
  ```
  claude-code.tlesh.xyz ansible_host=192.168.233.25
  ```

  Add a group at the bottom of `hosts` (follow the pattern of existing single-host groups like `[arr]`):
  ```ini
  [claude-code]
  claude-code.tlesh.xyz
  ```

- [ ] **Step 3: Bootstrap the LXC**

  ```bash
  task bootstrap-lxc -- claude-code.tlesh.xyz
  ```

  Expected: playbook runs, creates `ansible` user, installs SSH key. Should complete with 0 failures.

- [ ] **Step 4: Verify SSH connectivity**

  ```bash
  task ping
  ```

  Expected: `claude-code.tlesh.xyz | SUCCESS` in output.

- [ ] **Step 5: Add play to main.yml**

  Add this play to `main.yml` after the existing `uptime-kuma` play (line ~176), following the same pattern as neighboring plays:

  ```yaml
  - name: Configure claude-code LXC
    hosts: claude-code
    gather_facts: true
    roles:
      - role: claude-code
  ```

- [ ] **Step 6: Verify syntax**

  ```bash
  task syntax
  ```

  Expected: no errors.

- [ ] **Step 7: Commit**

  ```bash
  rtk git add hosts main.yml
  rtk git commit -m "feat(claude-code): add host to inventory and main.yml play"
  ```

---

### Task 2: Role — package installation

**Files:**
- Create: `roles/claude-code/defaults/main.yml`
- Create: `roles/claude-code/tasks/main.yml`
- Create: `roles/claude-code/tasks/packages.yml`

- [ ] **Step 1: Create role directory structure**

  ```bash
  mkdir -p roles/claude-code/tasks roles/claude-code/defaults
  ```

- [ ] **Step 2: Create defaults/main.yml**

  ```yaml
  ---
  claude_code_repo_dest: /home/tommy/homelab
  ```

- [ ] **Step 3: Create tasks/packages.yml**

  ```yaml
  ---
  - name: Add NodeSource GPG key
    ansible.builtin.get_url:
      url: https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key
      dest: /usr/share/keyrings/nodesource.gpg
      mode: '0644'
    become: true

  - name: Add NodeSource apt repository
    ansible.builtin.apt_repository:
      repo: "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main"
      state: present
      filename: nodesource
    become: true

  - name: Install Node.js
    ansible.builtin.apt:
      name: nodejs
      state: present
      update_cache: true
    become: true

  - name: Install Claude Code CLI
    ansible.builtin.command:
      cmd: npm install -g @anthropic-ai/claude-code
      creates: /usr/local/bin/claude
    become: true

  - name: Add GitHub CLI GPG key
    ansible.builtin.get_url:
      url: https://cli.github.com/packages/githubcli-archive-keyring.gpg
      dest: /usr/share/keyrings/githubcli-archive-keyring.gpg
      mode: '0644'
    become: true

  - name: Add GitHub CLI apt repository
    ansible.builtin.apt_repository:
      repo: "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"
      state: present
      filename: github-cli
    become: true

  - name: Add Doppler GPG key
    ansible.builtin.get_url:
      url: https://packages.doppler.com/public/cli/gpg.DE8DF2F2C3EB2B8B.key
      dest: /usr/share/keyrings/doppler.gpg
      mode: '0644'
    become: true

  - name: Add Doppler apt repository
    ansible.builtin.apt_repository:
      repo: "deb [signed-by=/usr/share/keyrings/doppler.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main"
      state: present
      filename: doppler
    become: true

  - name: Install gh, git, and doppler
    ansible.builtin.apt:
      name:
        - gh
        - git
        - doppler
      state: present
      update_cache: true
    become: true
  ```

- [ ] **Step 4: Create tasks/main.yml**

  ```yaml
  ---
  - name: Install packages
    ansible.builtin.import_tasks: packages.yml

  - name: Configure user
    ansible.builtin.import_tasks: user.yml

  - name: Configure SSH
    ansible.builtin.import_tasks: ssh.yml

  - name: Clone repository
    ansible.builtin.import_tasks: repo.yml
  ```

- [ ] **Step 5: Run syntax and lint**

  ```bash
  task syntax && task lint
  ```

  Expected: both pass with 0 errors.

- [ ] **Step 6: Commit**

  ```bash
  rtk git add roles/claude-code/
  rtk git commit -m "feat(claude-code): add role with package installation tasks"
  ```

---

### Task 3: Role — user and SSH setup

**Files:**
- Create: `roles/claude-code/tasks/user.yml`
- Create: `roles/claude-code/tasks/ssh.yml`

- [ ] **Step 1: Create tasks/user.yml**

  ```yaml
  ---
  - name: Create tommy user
    ansible.builtin.user:
      name: tommy
      shell: /bin/bash
      groups: sudo
      append: true
      create_home: true
    become: true

  - name: Allow tommy passwordless sudo
    ansible.builtin.copy:
      content: "tommy ALL=(ALL) NOPASSWD:ALL\n"
      dest: /etc/sudoers.d/tommy
      owner: root
      group: root
      mode: '0440'
      validate: 'visudo -cf %s'
    become: true

  - name: Add SSH authorized key for tommy
    ansible.posix.authorized_key:
      user: tommy
      key: "{{ lookup('env', 'SSH_PUBLIC_KEY') }}"
      state: present
    become: true
  ```

- [ ] **Step 2: Create tasks/ssh.yml**

  ```yaml
  ---
  - name: Ensure .ssh directory exists for tommy
    ansible.builtin.file:
      path: /home/tommy/.ssh
      state: directory
      owner: tommy
      group: tommy
      mode: '0700'
    become: true

  - name: Write ansible SSH private key
    ansible.builtin.copy:
      content: "{{ lookup('env', 'ANSIBLE_SSH_PRIVATE_KEY') }}"
      dest: /home/tommy/.ssh/ansible_ed25519
      owner: tommy
      group: tommy
      mode: '0600'
    become: true
    no_log: true

  - name: Write SSH config for homelab hosts
    ansible.builtin.blockinfile:
      path: /home/tommy/.ssh/config
      create: true
      owner: tommy
      group: tommy
      mode: '0600'
      block: |
        Host *.tlesh.xyz 192.168.233.*
          IdentityFile ~/.ssh/ansible_ed25519
          IdentitiesOnly yes
          StrictHostKeyChecking no
          User ansible
    become: true
  ```

- [ ] **Step 3: Run syntax and lint**

  ```bash
  task syntax && task lint
  ```

  Expected: both pass with 0 errors.

- [ ] **Step 4: Commit**

  ```bash
  rtk git add roles/claude-code/tasks/user.yml roles/claude-code/tasks/ssh.yml
  rtk git commit -m "feat(claude-code): add user creation and SSH key setup tasks"
  ```

---

### Task 4: Role — clone homelab repo

**Files:**
- Create: `roles/claude-code/tasks/repo.yml`

- [ ] **Step 1: Create tasks/repo.yml**

  ```yaml
  ---
  - name: Clone homelab repository
    ansible.builtin.git:
      repo: https://github.com/tlesh989/homelab.git
      dest: "{{ claude_code_repo_dest }}"
      version: main
      update: false
    become: true
    become_user: tommy
  ```

- [ ] **Step 2: Run syntax and lint**

  ```bash
  task syntax && task lint
  ```

  Expected: both pass with 0 errors.

- [ ] **Step 3: Commit**

  ```bash
  rtk git add roles/claude-code/tasks/repo.yml
  rtk git commit -m "feat(claude-code): add homelab repo clone task"
  ```

---

### Task 5: Taskfile task + deploy

**Files:**
- Modify: `Taskfile.yml`

- [ ] **Step 1: Add claude-code task to Taskfile.yml**

  Add after the `arr:` task block (around line where other LXC deploys live), following the identical pattern:

  ```yaml
    claude-code:
      desc: Deploy Claude Code LXC
      cmds:
        - task: ansible
          vars: { PLAYBOOK: "main.yml", LIMIT: "claude-code", CLI_ARGS: "{{.CLI_ARGS}}" }
  ```

- [ ] **Step 2: Commit**

  ```bash
  rtk git add Taskfile.yml
  rtk git commit -m "feat(claude-code): add Taskfile deploy task"
  ```

- [ ] **Step 3: Dry-run deploy**

  ```bash
  task claude-code -- --check
  ```

  Expected: all tasks show `ok` or `changed` with no failures. The `Install Claude Code CLI` task will show `skipped` in check mode (command module with `creates`), that's expected.

- [ ] **Step 4: Deploy**

  ```bash
  task claude-code
  ```

  Expected: completes with 0 failures.

- [ ] **Step 5: Verify Claude Code is installed**

  ```bash
  ssh tommy@192.168.233.25 'claude --version'
  ```

  Expected: prints the Claude Code version string.

- [ ] **Step 6: Verify ansible key and SSH connectivity from the LXC**

  ```bash
  ssh tommy@192.168.233.25 'ssh -o BatchMode=yes ansible@arr.tlesh.xyz hostname'
  ```

  Expected: prints `arr` with no passphrase prompt.

- [ ] **Step 7: First-time auth (manual, one-time)**

  SSH in and run each in sequence, completing the browser flow for each:

  ```bash
  ssh tommy@192.168.233.25
  claude auth login
  gh auth login
  doppler login
  ```

---

## Post-Deploy Notes

- **Tailscale access:** `ssh tommy@claude-code.tlesh.xyz` works over Tailscale via subnet routing — no additional setup needed.
- **Running playbooks from the LXC:** `cd ~/homelab && doppler run -- ansible-playbook -b main.yml --limit <target>`
- **Re-running deploy after updates:** `task claude-code` is idempotent — safe to re-run anytime.
