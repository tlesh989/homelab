# iSCSI Shared Storage Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect TrueNAS (ansalon, 192.168.220.6) to the Proxmox cluster (krynn) via iSCSI, creating a shared LVM storage pool usable by all three nodes for LXC/VM disks with live migration support.

**Architecture:** Ansible `roles/truenas` configures TrueNAS iSCSI portal/target/extent via REST API. Ansible `roles/proxmox` gains a `network.yml` task to set MTU 9000 on all storage bridges. After Terraform creates the Proxmox iSCSI storage backend, an Ansible task creates the LVM VG on the shared LUN (once, on sturm). Terraform then registers the LVM backend, making shared storage available cluster-wide.

**Tech Stack:** Ansible (`ansible.builtin.uri` for TrueNAS REST API), bpg/proxmox Terraform provider 0.98.1, TrueNAS SCALE 25.10.2.1 REST API v2, Proxmox VE 8.x, ifupdown2 (`ifreload -a`)

---

## Cluster/NAS State Reference (do not re-discover)

- **Pool:** `wayreth`, RAIDZ1 4×4TB, healthy
- **Zvol:** `wayreth/proxmox-iscsi`, 500GB, already exists
- **iSCSI basename:** `iqn.2005-10.org.freenas.ctl` (results in target IQN: `iqn.2005-10.org.freenas.ctl:proxmox`)
- **TrueNAS storage IP:** 192.168.220.6 (enp5s0, MTU 9000)
- **TrueNAS REST API:** `https://192.168.233.6/api/v2.0` (LAN), key from Doppler `TRUENAS_API_KEY`
- **Storage bridge MTU:** tika vmbr1=1500→9000, bupu vmbr1=1500→9000, sturm vmbr1=9000 (already correct)
- **Current iSCSI state:** portals=[], targets=[], extents=[] (nothing configured)

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `hosts` | Modify | Add `[truenas]` group |
| `group_vars/truenas.yml` | Create | TrueNAS connection variables |
| `group_vars/proxmox.yml` | Modify | Add `proxmox_storage_mtu: 9000` |
| `roles/proxmox/defaults/main.yml` | Modify | Add `proxmox_storage_mtu: 9000` default |
| `roles/proxmox/tasks/network.yml` | Create | Set vmbr1 MTU on proxmox nodes |
| `roles/proxmox/tasks/main.yml` | Modify | Include network.yml |
| `roles/truenas/defaults/main.yml` | Create | TrueNAS iSCSI variables |
| `roles/truenas/tasks/main.yml` | Create | Role entry point |
| `roles/truenas/tasks/iscsi.yml` | Create | iSCSI portal/target/extent config |
| `roles/truenas/tasks/iscsi_lvm.yml` | Create | LVM VG creation on iSCSI LUN (runs on sturm only) |
| `roles/truenas/handlers/main.yml` | Create | Reload iSCSI service |
| `terraform/iscsi.tf` | Create | Proxmox iSCSI + LVM storage backends |
| `main.yml` | Modify | Add truenas play |
| `Taskfile.yml` | Modify | Add `truenas` task |

---

## Chunk 1: Proxmox Storage Network MTU

### Task 1: Add `proxmox_storage_mtu` variable

**Files:**
- Modify: `roles/proxmox/defaults/main.yml`
- Modify: `group_vars/proxmox.yml`

- [ ] **Step 1.1: Read `roles/proxmox/defaults/main.yml`**

- [ ] **Step 1.2: Add default to `roles/proxmox/defaults/main.yml`**

Append:
```yaml
# Storage network bridge MTU — set to 9000 for jumbo frames on storage VLAN
proxmox_storage_mtu: 9000
```

- [ ] **Step 1.3: Read `group_vars/proxmox.yml`**

- [ ] **Step 1.4: Add to `group_vars/proxmox.yml`**

Append:
```yaml
proxmox_storage_mtu: 9000
```

- [ ] **Step 1.5: Commit**

```bash
git add roles/proxmox/defaults/main.yml group_vars/proxmox.yml
git commit -m "feat(proxmox): add proxmox_storage_mtu variable (9000)"
```

---

### Task 2: Create `roles/proxmox/tasks/network.yml`

**Files:**
- Create: `roles/proxmox/tasks/network.yml`
- Modify: `roles/proxmox/tasks/main.yml`

- [ ] **Step 2.1: Create `roles/proxmox/tasks/network.yml`**

```yaml
---
# tasks file for proxmox — network configuration

- name: Get vmbr1 current MTU
  ansible.builtin.shell:
    cmd: >-
      set -o pipefail &&
      pvesh get /nodes/{{ ansible_hostname }}/network/vmbr1
      --output-format json |
      python3 -c "import sys, json; print(json.load(sys.stdin).get('mtu', ''))"
    executable: /bin/bash
  register: _proxmox_vmbr1_mtu
  changed_when: false
  failed_when: false

- name: Set vmbr1 MTU to {{ proxmox_storage_mtu }}
  ansible.builtin.shell:
    cmd: >-
      pvesh set /nodes/{{ ansible_hostname }}/network/vmbr1
      -mtu {{ proxmox_storage_mtu }}
    executable: /bin/bash
  when: _proxmox_vmbr1_mtu.stdout | trim != proxmox_storage_mtu | string
  changed_when: true
  notify: Apply network config

- name: Debug vmbr1 MTU result
  ansible.builtin.debug:
    msg: "vmbr1 MTU is {{ _proxmox_vmbr1_mtu.stdout | trim }} (target: {{ proxmox_storage_mtu }})"
```

- [ ] **Step 2.2: Add handler to `roles/proxmox/handlers/main.yml`**

Read the file first, then append:
```yaml
- name: Apply network config
  ansible.builtin.command:
    cmd: ifreload -a
  changed_when: true
```

- [ ] **Step 2.3: Read `roles/proxmox/tasks/main.yml` and add include**

Add after the existing includes (before the Ceph block):
```yaml
- name: Configure network interfaces
  ansible.builtin.include_tasks: network.yml
```

- [ ] **Step 2.4: Validate syntax**

```bash
task syntax
```
Expected: no errors.

- [ ] **Step 2.5: Dry-run against proxmox hosts**

```bash
task proxmox -- --check --tags proxmox -vv
```

Verify the MTU tasks appear and would change tika/bupu (current MTU ≠ 9000) and skip sturm (already 9000).

- [ ] **Step 2.6: Commit**

```bash
git add roles/proxmox/tasks/network.yml roles/proxmox/tasks/main.yml roles/proxmox/handlers/main.yml
git commit -m "feat(proxmox): set vmbr1 MTU to 9000 for iSCSI storage network"
```

---

## Chunk 2: TrueNAS iSCSI Configuration (Ansible Role)

### Task 3: Scaffold `roles/truenas`

**Files:**
- Create: `roles/truenas/defaults/main.yml`
- Create: `roles/truenas/tasks/main.yml`
- Create: `roles/truenas/handlers/main.yml`

- [ ] **Step 3.1: Create `roles/truenas/defaults/main.yml`**

```yaml
---
# defaults file for truenas

# TrueNAS REST API base URL (LAN interface — accessible from Ansible controller)
truenas_api_url: "https://192.168.233.6/api/v2.0"
# TrueNAS API key — injected from Doppler as TRUENAS_API_KEY
truenas_api_key: "{{ lookup('env', 'TRUENAS_API_KEY') }}"

# iSCSI configuration
truenas_iscsi_portal_ip: "192.168.220.6"
truenas_iscsi_portal_port: 3260
truenas_iscsi_portal_comment: "proxmox"

truenas_iscsi_target_name: "proxmox"
# Full IQN: iqn.2005-10.org.freenas.ctl:proxmox

truenas_iscsi_extent_name: "proxmox-iscsi"
truenas_iscsi_extent_disk: "zvol/wayreth/proxmox-iscsi"
truenas_iscsi_extent_blocksize: 512
truenas_iscsi_extent_comment: "proxmox shared storage"
```

- [ ] **Step 3.2: Create `roles/truenas/tasks/main.yml`**

```yaml
---
# tasks file for truenas

- name: Configure TrueNAS iSCSI
  ansible.builtin.include_tasks: iscsi.yml
```

- [ ] **Step 3.3: Create `roles/truenas/handlers/main.yml`**

```yaml
---
# handlers file for truenas

- name: Start iSCSI service
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/service/start"
    method: POST
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      service: "iscsitarget"
    status_code: [200, 201]
    validate_certs: false
  changed_when: true
```

- [ ] **Step 3.4: Commit scaffold**

```bash
git add roles/truenas/
git commit -m "feat(truenas): scaffold truenas role"
```

---

### Task 4: Create `roles/truenas/tasks/iscsi.yml`

**Files:**
- Create: `roles/truenas/tasks/iscsi.yml`

- [ ] **Step 4.1: Create `roles/truenas/tasks/iscsi.yml`**

```yaml
---
# tasks file for truenas — iSCSI portal, target, extent, and service

# ── Portal ──────────────────────────────────────────────────────────────────

- name: Get existing iSCSI portals
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/iscsi/portal"
    method: GET
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
    validate_certs: false
    status_code: 200
  register: _truenas_portals
  changed_when: false

- name: Create iSCSI portal
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/iscsi/portal"
    method: POST
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      listen:
        - ip: "{{ truenas_iscsi_portal_ip }}"
          port: "{{ truenas_iscsi_portal_port }}"
      comment: "{{ truenas_iscsi_portal_comment }}"
    validate_certs: false
    status_code: [200, 201]
  register: _truenas_portal_create
  when: >-
    _truenas_portals.json
    | selectattr('comment', 'equalto', truenas_iscsi_portal_comment)
    | list | length == 0
  changed_when: true

- name: Set portal ID fact
  ansible.builtin.set_fact:
    _truenas_portal_id: >-
      {{
        (_truenas_portals.json
        | selectattr('comment', 'equalto', truenas_iscsi_portal_comment)
        | list | first).id
        if (_truenas_portals.json
            | selectattr('comment', 'equalto', truenas_iscsi_portal_comment)
            | list | length > 0)
        else _truenas_portal_create.json.id
      }}

# ── Target ───────────────────────────────────────────────────────────────────

- name: Get existing iSCSI targets
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/iscsi/target"
    method: GET
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
    validate_certs: false
    status_code: 200
  register: _truenas_targets
  changed_when: false

- name: Create iSCSI target
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/iscsi/target"
    method: POST
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      name: "{{ truenas_iscsi_target_name }}"
      alias: "{{ truenas_iscsi_target_name }}"
      mode: "ISCSI"
    validate_certs: false
    status_code: [200, 201]
  register: _truenas_target_create
  when: >-
    _truenas_targets.json
    | selectattr('name', 'equalto', truenas_iscsi_target_name)
    | list | length == 0
  changed_when: true

- name: Set target ID fact
  ansible.builtin.set_fact:
    _truenas_target_id: >-
      {{
        (_truenas_targets.json
        | selectattr('name', 'equalto', truenas_iscsi_target_name)
        | list | first).id
        if (_truenas_targets.json
            | selectattr('name', 'equalto', truenas_iscsi_target_name)
            | list | length > 0)
        else _truenas_target_create.json.id
      }}

# ── Extent ───────────────────────────────────────────────────────────────────

- name: Get existing iSCSI extents
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/iscsi/extent"
    method: GET
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
    validate_certs: false
    status_code: 200
  register: _truenas_extents
  changed_when: false

- name: Create iSCSI extent
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/iscsi/extent"
    method: POST
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      name: "{{ truenas_iscsi_extent_name }}"
      type: "DISK"
      disk: "{{ truenas_iscsi_extent_disk }}"
      blocksize: "{{ truenas_iscsi_extent_blocksize }}"
      comment: "{{ truenas_iscsi_extent_comment }}"
    validate_certs: false
    status_code: [200, 201]
  register: _truenas_extent_create
  when: >-
    _truenas_extents.json
    | selectattr('name', 'equalto', truenas_iscsi_extent_name)
    | list | length == 0
  changed_when: true

- name: Set extent ID fact
  ansible.builtin.set_fact:
    _truenas_extent_id: >-
      {{
        (_truenas_extents.json
        | selectattr('name', 'equalto', truenas_iscsi_extent_name)
        | list | first).id
        if (_truenas_extents.json
            | selectattr('name', 'equalto', truenas_iscsi_extent_name)
            | list | length > 0)
        else _truenas_extent_create.json.id
      }}

# ── Target ↔ Extent association ───────────────────────────────────────────────

- name: Get existing iSCSI target-extent associations
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/iscsi/targetextent"
    method: GET
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
    validate_certs: false
    status_code: 200
  register: _truenas_targetextents
  changed_when: false

- name: Associate target with extent (LUN 0)
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/iscsi/targetextent"
    method: POST
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      target: "{{ _truenas_target_id }}"
      extent: "{{ _truenas_extent_id }}"
      lunid: 0
    validate_certs: false
    status_code: [200, 201]
  when: >-
    _truenas_targetextents.json
    | selectattr('target', 'equalto', _truenas_target_id | int)
    | selectattr('extent', 'equalto', _truenas_extent_id | int)
    | list | length == 0
  changed_when: true

# ── iSCSI Service ─────────────────────────────────────────────────────────────

- name: Get iSCSI service state
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/service"
    method: GET
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
    validate_certs: false
    status_code: 200
  register: _truenas_services
  changed_when: false

- name: Enable iSCSI service at boot
  ansible.builtin.uri:
    url: >-
      {{ truenas_api_url }}/service/id/{{
        (_truenas_services.json
        | selectattr('service', 'equalto', 'iscsitarget')
        | list | first).id
      }}
    method: PUT
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      enable: true
    validate_certs: false
    status_code: 200
  when: >-
    not (_truenas_services.json
    | selectattr('service', 'equalto', 'iscsitarget')
    | list | first).enable
  changed_when: true
  notify: Start iSCSI service

- name: Start iSCSI service if not running
  ansible.builtin.uri:
    url: "{{ truenas_api_url }}/service/start"
    method: POST
    headers:
      Authorization: "Bearer {{ truenas_api_key }}"
      Content-Type: "application/json"
    body_format: json
    body:
      service: "iscsitarget"
    validate_certs: false
    status_code: [200, 201]
  when: >-
    (_truenas_services.json
    | selectattr('service', 'equalto', 'iscsitarget')
    | list | first).state != "RUNNING"
  changed_when: true
```

- [ ] **Step 4.2: Validate syntax**

```bash
task syntax
```
Expected: no errors.

- [ ] **Step 4.3: Commit**

```bash
git add roles/truenas/tasks/
git commit -m "feat(truenas): configure iSCSI portal, target, extent, and service via REST API"
```

---

## Chunk 3: Inventory, Playbook, and Taskfile Wiring

### Task 5: Add TrueNAS to inventory and wire into main.yml

**Files:**
- Modify: `hosts`
- Create: `group_vars/truenas.yml`
- Modify: `main.yml`
- Modify: `Taskfile.yml`

- [ ] **Step 5.1: Add truenas group to `hosts`**

Append to `hosts`:
```ini
[truenas]
ansalon ansible_host=192.168.233.6 ansible_connection=local
```

Note: `ansible_connection=local` — the truenas role uses `ansible.builtin.uri` to call the REST API from the Ansible controller. No SSH into TrueNAS is needed.

- [ ] **Step 5.2: Create `group_vars/truenas.yml`**

```yaml
---
# group_vars for truenas host
# All connection variables are in roles/truenas/defaults/main.yml
# Override here if needed (e.g., different API URL)
```

- [ ] **Step 5.3: Read `main.yml` and add truenas play**

Add after the `setup proxmox hosts` play:
```yaml
- name: configure truenas
  hosts: truenas
  roles:
    - role: truenas
```

- [ ] **Step 5.4: Add `truenas` task to `Taskfile.yml`**

Add after the `proxmox` task:
```yaml
  truenas:
    desc: Configure TrueNAS (iSCSI targets, NFS shares)
    cmds:
      - task: ansible
        vars: { PLAYBOOK: "main.yml", LIMIT: "truenas", CLI_ARGS: "{{.CLI_ARGS}}" }
```

- [ ] **Step 5.5: Validate syntax**

```bash
task syntax
```

- [ ] **Step 5.6: Dry-run truenas play**

```bash
task truenas -- --check -v
```

Expected: tasks show as would-change (portals/targets/extents all empty). No actual changes made.

- [ ] **Step 5.7: Commit**

```bash
git add hosts group_vars/truenas.yml main.yml Taskfile.yml
git commit -m "feat(truenas): add to inventory and main.yml playbook"
```

---

## Chunk 4: Terraform — Proxmox iSCSI + LVM Storage Backends

### Task 6: Create `terraform/iscsi.tf`

**Files:**
- Create: `terraform/iscsi.tf`

**Important:** Before writing, use Context7 to look up the exact bpg/proxmox resources:
- Search for `proxmox_virtual_environment_storage_iscsi`
- Search for `proxmox_virtual_environment_storage_lvm`

If the provider does NOT have these resources in 0.98.1, use `pvesh` via Ansible instead (documented at end of this task).

- [ ] **Step 6.1: Use Context7 to verify provider resources**

```
mcp__context7__resolve-library-id: bpg/proxmox terraform provider
mcp__context7__query-docs: proxmox_virtual_environment_storage_iscsi
mcp__context7__query-docs: proxmox_virtual_environment_storage_lvm
```

- [ ] **Step 6.2: Create `terraform/iscsi.tf` (if provider supports both resources)**

```hcl
# iSCSI storage backend — connects Proxmox to TrueNAS iSCSI target
# This provides the raw block device; LVM is layered on top.
resource "proxmox_virtual_environment_storage_iscsi" "truenas_iscsi" {
  nodes  = ["bupu", "sturm", "tika"]
  id     = "truenas-iscsi"
  portal = "192.168.220.6"
  target = "iqn.2005-10.org.freenas.ctl:proxmox"

  # No content types — this storage is used as LVM backing only
  content_types = []
}

# LVM storage backend — thin-provisioned shared storage on top of iSCSI LUN
# Requires the LVM VG to exist (see Task 7).
resource "proxmox_virtual_environment_storage_lvm" "truenas_lvm" {
  nodes        = ["bupu", "sturm", "tika"]
  id           = "truenas-lvm"
  volume_group = "pve-iscsi"
  shared       = true

  content_types = ["rootdir", "images"]

  depends_on = [proxmox_virtual_environment_storage_iscsi.truenas_iscsi]
}
```

**Fallback if provider lacks iSCSI/LVM resources:** Add these storage backends via Ansible `pvesh` commands in a new `roles/proxmox/tasks/storage.yml`. Skip the Terraform approach and document the pvesh commands:
```bash
# iSCSI backend
pvesh create /storage --storage truenas-iscsi --type iscsi \
  --portal 192.168.220.6 --target iqn.2005-10.org.freenas.ctl:proxmox \
  --nodes bupu,sturm,tika

# LVM backend (after VG exists)
pvesh create /storage --storage truenas-lvm --type lvm \
  --vgname pve-iscsi --shared 1 --content rootdir,images \
  --nodes bupu,sturm,tika
```

- [ ] **Step 6.3: Validate Terraform**

```bash
cd terraform && task
```
Expected: format check passes, validate passes, plan shows new storage resources.

- [ ] **Step 6.4: Commit**

```bash
git add terraform/iscsi.tf
git commit -m "feat(terraform): add iSCSI and LVM storage backends for TrueNAS shared storage"
```

---

## Chunk 5: LVM VG Creation on iSCSI LUN

This task runs **after** `task truenas` (TrueNAS iSCSI configured) and **after** `cd terraform && task apply` (Proxmox iSCSI backend registered). At that point, the iSCSI LUN will appear as a block device on each Proxmox node.

### Task 7: Create LVM VG on the shared iSCSI LUN

**Files:**
- Create: `roles/truenas/tasks/iscsi_lvm.yml`
- Modify: `roles/truenas/tasks/main.yml`

The LVM VG needs to be created **once**, on one node (sturm). Other nodes auto-discover it via LVM metadata on the shared disk.

- [ ] **Step 7.1: Discover the iSCSI device path on sturm**

SSH in to verify the LUN is visible after iSCSI backend is applied:
```bash
ssh -i ~/.ssh/ansible_ed25519 ansible@sturm \
  'sudo ls /dev/disk/by-path/ | grep iqn.2005-10.org.freenas'
```
Expected: something like `ip-192.168.220.6:3260-iscsi-iqn.2005-10.org.freenas.ctl:proxmox-lun-0`

- [ ] **Step 7.2: Create `roles/truenas/tasks/iscsi_lvm.yml`**

```yaml
---
# tasks file for truenas — LVM VG on iSCSI LUN
# Runs on the LVM primary node (sturm) only; other nodes discover the VG automatically.

- name: Find iSCSI LUN device path
  ansible.builtin.shell:
    cmd: >-
      set -o pipefail &&
      ls /dev/disk/by-path/ |
      grep "{{ truenas_iscsi_target_name }}" |
      grep -- "-lun-0$" |
      head -1
    executable: /bin/bash
  register: _truenas_iscsi_device
  changed_when: false
  failed_when: false
  delegate_to: "{{ truenas_lvm_primary_node }}"

- name: Skip LVM setup — iSCSI LUN not visible yet (run after terraform apply)
  ansible.builtin.debug:
    msg: >-
      iSCSI device not found on {{ truenas_lvm_primary_node }}.
      Run 'cd terraform && task apply' first, then re-run 'task truenas'.
  when: _truenas_iscsi_device.stdout == ""

- name: End play if iSCSI LUN not available
  ansible.builtin.meta: end_play
  when: _truenas_iscsi_device.stdout == ""

- name: Set iSCSI device path fact
  ansible.builtin.set_fact:
    _truenas_iscsi_dev: "/dev/disk/by-path/{{ _truenas_iscsi_device.stdout | trim }}"
  delegate_to: "{{ truenas_lvm_primary_node }}"

- name: Check if LVM VG already exists
  ansible.builtin.shell:
    cmd: "vgdisplay {{ truenas_lvm_vg_name }} 2>/dev/null"
    executable: /bin/bash
  register: _truenas_vg_check
  changed_when: false
  failed_when: false
  delegate_to: "{{ truenas_lvm_primary_node }}"

- name: Create LVM PV and VG on iSCSI LUN
  ansible.builtin.shell:
    cmd: >-
      set -o pipefail &&
      pvcreate "{{ _truenas_iscsi_dev }}" &&
      vgcreate "{{ truenas_lvm_vg_name }}" "{{ _truenas_iscsi_dev }}"
    executable: /bin/bash
  when: _truenas_vg_check.rc != 0
  changed_when: true
  delegate_to: "{{ truenas_lvm_primary_node }}"
```

- [ ] **Step 7.3: Add LVM variables to `roles/truenas/defaults/main.yml`**

Append:
```yaml
# LVM configuration
# Node that creates the VG (other nodes discover it via shared LVM metadata)
truenas_lvm_primary_node: "sturm"
truenas_lvm_vg_name: "pve-iscsi"
```

- [ ] **Step 7.4: Add include to `roles/truenas/tasks/main.yml`**

```yaml
---
# tasks file for truenas

- name: Configure TrueNAS iSCSI
  ansible.builtin.include_tasks: iscsi.yml

- name: Create LVM VG on iSCSI LUN
  ansible.builtin.include_tasks: iscsi_lvm.yml
```

Note: `iscsi_lvm.yml` tasks use `delegate_to: sturm`. The play runs against `localhost` (truenas host), but the LVM tasks delegate to the Proxmox node.

- [ ] **Step 7.5: Validate syntax**

```bash
task syntax
```

- [ ] **Step 7.6: Commit**

```bash
git add roles/truenas/
git commit -m "feat(truenas): create LVM VG on shared iSCSI LUN via delegated task"
```

---

## End-to-End Apply Order

After all code is merged, apply in this order:

```bash
# 1. MTU changes on Proxmox storage bridges
task proxmox

# 2. TrueNAS iSCSI configuration + LVM VG creation
task truenas

# 3. Proxmox iSCSI + LVM storage backends
cd terraform && task apply

# 4. Verify storage visible in Proxmox
ssh -i ~/.ssh/ansible_ed25519 ansible@tika 'sudo pvesh get /storage --output-format json | python3 -m json.tool | grep -E "storage|type"'
```

Expected result: `truenas-iscsi` (type: iscsi) and `truenas-lvm` (type: lvm) visible on all three nodes.
