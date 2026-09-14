# Glance LXC Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Provision a Glance dashboard LXC on Proxmox via Terraform, then configure it with a new Ansible role.

**Architecture:** A new `proxmox_virtual_environment_container.glance` Terraform resource provisions the LXC on bupu (192.168.233.22). A new `roles/glance` Ansible role downloads the Glance Go binary from GitHub, templates the config and systemd service, and enables it. The host is added to the `[glance]` inventory group under `[lxc:children]`.

**Tech Stack:** Terraform (bpg/proxmox 0.97.1), Ansible, Glance (glanceapp/glance GitHub releases), systemd

---

## Tasks

### Task 1: Add Glance container to Terraform

**Files:**

- Modify: `terraform/main.tf`

#### Step 1: Add the container resource

Append to `terraform/main.tf`:

```hcl
resource "proxmox_virtual_environment_container" "glance" {
  node_name    = "bupu"
  vm_id        = 104
  unprivileged = true

  disk {
    datastore_id = "vm_data"
    size         = 2
  }

  initialization {
    hostname = "glance"

    ip_config {
      ipv4 {
        address = "192.168.233.22/24"
        gateway = "192.168.233.1"
      }
    }
  }

  memory {
    dedicated = 512
    swap      = 0
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:A2:3C:44"
    name        = "eth0"
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.ubuntu_22_04_template.id
    type             = "ubuntu"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
    ]
  }

  tags = [
    "terraform",
  ]
}
```

#### Step 2: Validate Terraform

```bash
cd terraform && task test
```

Expected: `terraform fmt`, `validate`, and `plan` all succeed. Review plan output confirms a single new container will be created.

#### Step 3: Commit

```bash
git add terraform/main.tf
git commit -m "feat(terraform): add Glance LXC container"
```

---

### Task 2: Update Ansible inventory and Taskfile

**Files:**

- Modify: `hosts`
- Modify: `Taskfile.yml`

#### Step 1: Add glance host to inventory

In `hosts`, add a new `[glance]` group and add `glance` to `[lxc:children]`:

```ini
[glance]
glance.tlesh.xyz ansible_host=192.168.233.22
```

Change the existing `[lxc:children]` block from:

```ini
[lxc:children]
tailscale
plex
```

to:

```ini
[lxc:children]
tailscale
plex
glance
```

#### Step 2: Add glance task to Taskfile

In `Taskfile.yml`, add after the `plex` task:

```yaml
  glance:
    desc: Run Ansible playbook for Glance host
    cmds:
      - task: ansible
        vars: { PLAYBOOK: "main.yml", LIMIT: "glance", CLI_ARGS: "--ask-pass {{.CLI_ARGS}}" }
```

#### Step 3: Commit

```bash
git add hosts Taskfile.yml
git commit -m "feat(ansible): add Glance to inventory and Taskfile"
```

---

### Task 3: Create group_vars for Glance

**Files:**

- Create: `group_vars/glance.yml`

#### Step 1: Create the file

```yaml
---
# Glance LXC container
# Inherits base package list and NTP config from group_vars/lxc.yml
```

This file intentionally inherits all defaults from `group_vars/lxc.yml` and `group_vars/all.yml` via the `[lxc:children]` group membership.

#### Step 2: Commit

```bash
git add group_vars/glance.yml
git commit -m "feat(ansible): add group_vars for Glance"
```

---

### Task 4: Create glance role — defaults

**Files:**

- Create: `roles/glance/defaults/main.yml`

#### Step 1: Create defaults

```yaml
---
# roles/glance/defaults/main.yml

glance_version: latest
glance_install_dir: /opt/glance
glance_port: 8080
```

#### Step 2: Commit

```bash
git add roles/glance/defaults/main.yml
git commit -m "feat(ansible): add glance role defaults"
```

---

### Task 5: Create glance role — templates

**Files:**

- Create: `roles/glance/templates/glance.yml.j2`
- Create: `roles/glance/templates/glance.service.j2`

#### Step 1: Create the Glance config template

`roles/glance/templates/glance.yml.j2`:

```yaml
server:
  port: {{ glance_port }}

pages:
  - name: Home
    columns:
      - size: full
        widgets:
          - type: search
            search-engine: google
```

#### Step 2: Create the systemd service template

`roles/glance/templates/glance.service.j2`:

```ini
[Unit]
Description=Glance Dashboard
After=network.target

[Service]
ExecStart={{ glance_install_dir }}/glance --config {{ glance_install_dir }}/glance.yml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

#### Step 3: Commit

```bash
git add roles/glance/templates/
git commit -m "feat(ansible): add glance role templates"
```

---

### Task 6: Create glance role — handlers

**Files:**

- Create: `roles/glance/handlers/main.yml`

#### Step 1: Create the handler

```yaml
---
# roles/glance/handlers/main.yml

- name: Restart glance
  ansible.builtin.systemd:
    name: glance
    state: restarted
    daemon_reload: true
```

#### Step 2: Commit

```bash
git add roles/glance/handlers/main.yml
git commit -m "feat(ansible): add glance role handlers"
```

---

### Task 7: Create glance role — tasks

**Files:**

- Create: `roles/glance/tasks/main.yml`

#### Step 1: Create the tasks

```yaml
---
# roles/glance/tasks/main.yml

- name: Get latest Glance release info from GitHub
  ansible.builtin.uri:
    url: >-
      {{ 'https://api.github.com/repos/glanceapp/glance/releases/latest'
         if glance_version == 'latest'
         else 'https://api.github.com/repos/glanceapp/glance/releases/tags/' + glance_version }}
    return_content: true
  register: glance_release

- name: Set Glance download URL
  ansible.builtin.set_fact:
    glance_download_url: >-
      {{ glance_release.json.assets
         | selectattr('name', 'equalto', 'glance-linux-amd64.tar.gz')
         | map(attribute='browser_download_url')
         | first }}

- name: Create Glance install directory
  ansible.builtin.file:
    path: "{{ glance_install_dir }}"
    state: directory
    mode: "0755"

- name: Download and extract Glance binary
  ansible.builtin.unarchive:
    src: "{{ glance_download_url }}"
    dest: "{{ glance_install_dir }}"
    remote_src: true
  notify: Restart glance

- name: Template Glance config
  ansible.builtin.template:
    src: glance.yml.j2
    dest: "{{ glance_install_dir }}/glance.yml"
    mode: "0644"
  notify: Restart glance

- name: Template Glance systemd service
  ansible.builtin.template:
    src: glance.service.j2
    dest: /etc/systemd/system/glance.service
    mode: "0644"
  notify: Restart glance

- name: Enable and start Glance service
  ansible.builtin.systemd:
    name: glance
    state: started
    enabled: true
    daemon_reload: true
```

#### Step 2: Commit

```bash
git add roles/glance/tasks/main.yml
git commit -m "feat(ansible): add glance role tasks"
```

---

### Task 8: Add glance play to main.yml

**Files:**

- Modify: `main.yml`

#### Step 1: Append the glance play

Append to `main.yml`:

```yaml
- name: setup glance server
  hosts: glance
  become: true
  vars_files:
    - vars/vault.yml
  roles:
    - role: grog.package
    - role: geerlingguy.ntp
    - role: geerlingguy.security
    - role: users
    - role: glance
```

#### Step 2: Validate syntax

```bash
task syntax
```

Expected: `playbook: main.yml` with no errors.

#### Step 3: Lint

```bash
task lint
```

Expected: no errors or warnings.

#### Step 4: Commit

```bash
git add main.yml
git commit -m "feat(ansible): add Glance play to main playbook"
```

---

### Task 9: Apply Terraform to provision the container

> Run this after all Ansible changes are committed. Requires Doppler for Proxmox credentials.

#### Step 1: Plan

```bash
cd terraform && task test
```

Review plan output: exactly one new resource (`proxmox_virtual_environment_container.glance`) will be created.

#### Step 2: Apply

```bash
cd terraform && task apply
```

Expected: container created successfully. Confirm LXC 104 appears in Proxmox UI under bupu.

#### Step 3: Verify network

```bash
ping 192.168.233.22
```

Expected: replies from the container.

---

### Task 10: Deploy Ansible to configure Glance

> The container must be running and SSH-accessible before this step.

#### Step 1: Test connectivity

```bash
ansible glance -m ping --ask-pass
```

Expected: `glance.tlesh.xyz | SUCCESS`.

#### Step 2: Deploy

```bash
task glance
```

Enter the SSH password when prompted.

#### Step 3: Verify Glance is running

```bash
curl http://192.168.233.22:8080
```

Expected: HTML response from the Glance dashboard. Also accessible in a browser at `http://192.168.233.22:8080`.
