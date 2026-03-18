# Proxmox + TrueNAS Optimization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Validate TrueNAS storage, get Plex working with hardware transcoding, add observability, and enable HA for pi-hole.

**Architecture:** Three sequential phases — Phase 1 (storage validation + NFS + Netdata), Phase 2 (Plex software + VAAPI), Phase 3 (HA for pi-hole). Each phase is independently deployable. Phases 2 and 3 depend on Phase 1 completing successfully.

**Tech Stack:** Proxmox VE 9.x, TrueNAS SCALE 25.x, Ansible (`bpg/proxmox` provider), Terraform (HCP backend), Doppler secrets. All commands run via `task <target>` (Doppler-injected). Deploy pattern: `task check` (dry-run) → confirm → `task <target>`.

---

## File Map

### New files
- `roles/netdata/tasks/main.yml` — install and configure Netdata parent LXC
- `roles/netdata/defaults/main.yml` — Netdata role defaults
- `roles/plex/tasks/main.yml` — install Plex, configure NFS mount, VAAPI passthrough
- `roles/plex/defaults/main.yml` — Plex role defaults
- `terraform/netdata.tf` — provision Netdata LXC (vm_id 105, IP .23)
- `group_vars/netdata.yml` — Netdata host vars
- `group_vars/plex.yml` — Plex host vars

### Modified files
- `roles/proxmox/tasks/storage.yml` — add local `vm_data` verification task, multipath.conf deployment
- `roles/proxmox/tasks/nfs-mounts.yml` — new: NFS fstab mounts on Proxmox host (not inside LXCs)
- `group_vars/sturm.yml` — new: NFS mount vars for sturm only
- `roles/proxmox/tasks/main.yml` — include softdog module task (Phase 3)
- `roles/proxmox/tasks/hardware.yml` — add softdog `/etc/modules-load.d/softdog.conf`
- `roles/truenas/tasks/main.yml` — include new `nfs.yml` task file
- `roles/truenas/tasks/nfs.yml` — new: create NFS dataset + share for Plex media
- `terraform/pi-hole.tf` — update `datastore_id` to `truenas-lvm` post-migration; add `lifecycle.ignore_changes` during migration
- `main.yml` — add `netdata` and `plex` role includes under appropriate host groups
- `hosts` — add `[netdata]` and `[plex]` host groups
- `Taskfile.yml` — add `plex` and `netdata` task entries

---

## Phase 1: Storage Validation + NFS + Observability

---

### Task 1: Verify `vm_data` storage pool is on 512GB data disk (not OS disk)

**Context:** All existing LXCs (plex 100GB, pi-hole 8GB, glance 8GB) use `vm_data`. Before adding more workloads, confirm `vm_data` maps to the 512GB data disk on each node, not the OS SSD.

**Files:** No code changes — verification only.

- [ ] **Step 1: Check vm_data backing device on sturm**

  ```bash
  doppler run -- ansible sturm -m shell \
    -a "pvs --noheadings -o pv_name,vg_name | grep vm_data || pvesm status | grep vm_data" \
    -i hosts -b
  ```
  Expected: output shows the LVM VG backing `vm_data` and which physical device it's on.

- [ ] **Step 2: Confirm device is NOT the OS disk on each node**

  ```bash
  doppler run -- ansible proxmox -m shell \
    -a "lsblk -o NAME,SIZE,MOUNTPOINT,TYPE | head -30" \
    -i hosts -b
  ```
  Cross-reference the device backing `vm_data` against `/` mount — they must be different devices.

- [ ] **Step 3: If vm_data is on OS disk — stop and resolve manually**

  If the backing device is the same as `/`, create a new LVM-thin pool on the 512GB disk:
  ```bash
  # Run on each affected node (replace /dev/sdX with actual 512GB disk device)
  pvcreate /dev/sdX
  vgcreate vm_data_vg /dev/sdX
  lvcreate -l 100%FREE --thin vm_data_vg/vm_data_thin
  pvesm add lvmthin vm_data --vgname vm_data_vg --thinpool vm_data_thin \
    --content images,rootdir
  ```
  Then migrate existing LXC disks to the new pool before continuing.

- [ ] **Step 4: Document the device mapping**

  Record the 512GB disk device name for each node (e.g., `/dev/sdb`, `/dev/nvme1n1`) in a comment at the top of `roles/proxmox/tasks/storage.yml` for future reference.

---

### Task 2: Verify iSCSI visibility on all nodes + configure multipath

**Context:** `pve-iscsi` LVM VG (and `truenas-lvm` storage pool) must be accessible from all three nodes for Proxmox HA to work. Also deploy an explicit `multipath.conf` to prevent path thrashing.

**Files:**
- Modify: `roles/proxmox/tasks/storage.yml`
- Modify: `group_vars/proxmox.yml` (add multipath vars)

- [ ] **Step 1: Verify iSCSI storage is visible on all nodes**

  ```bash
  doppler run -- ansible proxmox -m shell \
    -a "pvesh get /storage/truenas-lvm --output-format json 2>&1 | head -5" \
    -i hosts -b
  ```
  Expected: JSON output on all three nodes (tika, bupu, sturm). If any node returns an error, run `task truenas` first to register the iSCSI target, then `task proxmox` to register the storage backend.

- [ ] **Step 2: Check multipathd status on all nodes**

  ```bash
  doppler run -- ansible proxmox -m shell \
    -a "multipath -ll 2>&1 | head -20" \
    -i hosts -b
  ```
  Note whether multipath is managing devices. If duplicate device nodes appear for the TrueNAS LUN, proceed to Step 3. If multipath is clean or disabled, skip to Task 3.

- [ ] **Step 3: Add multipath.conf deployment to roles/proxmox/tasks/storage.yml**

  Append to `roles/proxmox/tasks/storage.yml`:
  ```yaml
  - name: Deploy multipath configuration
    ansible.builtin.copy:
      dest: /etc/multipath.conf
      owner: root
      group: root
      mode: "0644"
      content: |
        defaults {
          path_grouping_policy failover
          failback immediate
        }
        blacklist {
          devnode "^(sd[a-z]|nvme[0-9]+n[0-9]+)$"
        }
        blacklist_exceptions {
          property "SCSI_IDENT_.*"
        }
    notify: Restart multipathd

  - name: Ensure multipathd is enabled and running
    ansible.builtin.systemd:
      name: multipathd
      enabled: true
      state: started
  ```

  Add handler to `roles/proxmox/handlers/main.yml` (create if missing):
  ```yaml
  - name: Restart multipathd
    ansible.builtin.systemd:
      name: multipathd
      state: restarted
  ```

- [ ] **Step 4: Apply and verify**

  ```bash
  task check   # dry-run first
  task proxmox
  doppler run -- ansible proxmox -m shell -a "multipath -ll 2>&1" -i hosts -b
  ```
  Expected: TrueNAS LUN managed with `failover` policy; local NVMe/SATA drives blacklisted.

---

### Task 3: Run fio benchmarks on iSCSI storage

**Context:** Validate `truenas-lvm` storage meets baseline performance before Phase 3 depends on it.

**Files:** No code changes — manual validation only.

- [ ] **Step 1: Install fio on sturm**

  ```bash
  doppler run -- ansible sturm -m apt -a "name=fio state=present" -i hosts -b
  ```

- [ ] **Step 2: Run sequential write benchmark**

  ```bash
  doppler run -- ansible sturm -m shell -a \
    "fio --name=seq-write --ioengine=libaio --rw=write --bs=128k --numjobs=1 \
     --iodepth=32 --size=1G --direct=1 --filename=/dev/truenas-lvm/vm-999-disk-0 \
     --output-format=json 2>&1 | python3 -c 'import json,sys; d=json.load(sys.stdin); \
     print(\"seq_write_MBs:\", round(d[\"jobs\"][0][\"write\"][\"bw_bytes\"]/1024/1024, 1))'" \
    -i hosts -b
  ```
  Replace `/dev/truenas-lvm/vm-999-disk-0` with the actual iSCSI LUN device path (check `ls /dev/truenas-lvm/`). If no LVM volume exists yet, create a temporary one: `lvcreate -L 2G truenas-lvm -n benchmark-tmp`.

- [ ] **Step 3: Run random 4K IOPS benchmark**

  ```bash
  doppler run -- ansible sturm -m shell -a \
    "fio --name=rand-read --ioengine=libaio --rw=randread --bs=4k --numjobs=1 \
     --iodepth=32 --size=1G --direct=1 --filename=/dev/truenas-lvm/benchmark-tmp \
     --output-format=json 2>&1 | python3 -c 'import json,sys; d=json.load(sys.stdin); \
     print(\"rand_read_iops:\", round(d[\"jobs\"][0][\"read\"][\"iops\"]))'" \
    -i hosts -b
  ```

- [ ] **Step 4: Check latency**

  ```bash
  doppler run -- ansible sturm -m shell -a \
    "fio --name=latency --ioengine=libaio --rw=randread --bs=4k --numjobs=1 \
     --iodepth=1 --size=512M --direct=1 --filename=/dev/truenas-lvm/benchmark-tmp \
     --output-format=json 2>&1 | python3 -c 'import json,sys; d=json.load(sys.stdin); \
     p99=d[\"jobs\"][0][\"read\"][\"clat_ns\"][\"percentile\"][\"99.000000\"]; \
     print(\"p99_latency_ms:\", round(p99/1e6, 2))'" \
    -i hosts -b
  ```

- [ ] **Step 5: Evaluate results against pass criteria**

  | Metric | Target (1GbE) | Action if below |
  |--------|--------------|-----------------|
  | Sequential write | ≥ 100 MB/s | Check TrueNAS iSCSI config, enable jumbo frames |
  | Random 4K IOPS | ≥ 500 | Check TrueNAS ARC cache, iSCSI queue depth |
  | p99 latency | < 10ms | Check network path, Corosync contention |

  If all pass, continue. **If any fail, stop — do not proceed to Phase 3 until resolved.**

- [ ] **Step 6: Clean up benchmark volume**

  ```bash
  doppler run -- ansible sturm -m shell \
    -a "lvremove -f truenas-lvm/benchmark-tmp 2>/dev/null || true" \
    -i hosts -b
  ```

---

### Task 4: TrueNAS NFS share for Plex media

**Context:** Create a TrueNAS NFS dataset for Plex media. This is mounted on the Proxmox host (sturm) and passed as a bind mount into the Plex LXC.

**Files:**
- Create: `roles/truenas/tasks/nfs.yml`
- Modify: `roles/truenas/tasks/main.yml`
- Modify: `group_vars/truenas.yml`

- [ ] **Step 1: Add NFS vars to group_vars/truenas.yml**

  Check existing `group_vars/truenas.yml` for current vars, then add:
  ```yaml
  # NFS shares
  truenas_nfs_shares:
    - dataset: "tank/media/plex"
      comment: "Plex media library"
      hosts:
        - "192.168.233.7"  # tika
        - "192.168.233.8"  # bupu
        - "192.168.233.9"  # sturm
      maproot_user: "root"
      maproot_group: "wheel"
  ```

- [ ] **Step 2: Create roles/truenas/tasks/nfs.yml**

  ```yaml
  ---
  # tasks file for truenas — NFS share management

  - name: Create media dataset
    ansible.builtin.uri:
      url: "https://{{ ansible_host }}/api/v2.0/pool/dataset"
      method: POST
      headers:
        Authorization: "Bearer {{ truenas_api_key }}"
      body_format: json
      body:
        name: "{{ item.dataset }}"
        type: "FILESYSTEM"
        comments: "{{ item.comment }}"
      status_code: [200, 422]  # 422 = already exists
      validate_certs: false
    loop: "{{ truenas_nfs_shares }}"
    loop_control:
      label: "{{ item.dataset }}"

  - name: Create NFS share
    ansible.builtin.uri:
      url: "https://{{ ansible_host }}/api/v2.0/sharing/nfs"
      method: POST
      headers:
        Authorization: "Bearer {{ truenas_api_key }}"
      body_format: json
      body:
        path: "/mnt/{{ item.dataset }}"
        comment: "{{ item.comment }}"
        hosts: "{{ item.hosts }}"
        maproot_user: "{{ item.maproot_user }}"
        maproot_group: "{{ item.maproot_group }}"
        enabled: true
      status_code: [200, 422]
      validate_certs: false
    loop: "{{ truenas_nfs_shares }}"
    loop_control:
      label: "{{ item.dataset }}"

  - name: Ensure NFS service is running
    ansible.builtin.uri:
      url: "https://{{ ansible_host }}/api/v2.0/service/start"
      method: POST
      headers:
        Authorization: "Bearer {{ truenas_api_key }}"
      body_format: json
      body:
        service: "nfs"
      status_code: [200]
      validate_certs: false
  ```

- [ ] **Step 3: Include nfs.yml in roles/truenas/tasks/main.yml**

  Append to `roles/truenas/tasks/main.yml`:
  ```yaml
  - name: Configure NFS shares
    ansible.builtin.include_tasks: nfs.yml
  ```

- [ ] **Step 4: Add TRUENAS_API_KEY to Doppler and verify**

  Check if `truenas_api_key` is already available in `group_vars/truenas.yml` via Doppler lookup. If not, add `TRUENAS_API_KEY` to Doppler and reference it:
  ```yaml
  truenas_api_key: "{{ lookup('env', 'TRUENAS_API_KEY') }}"
  ```

- [ ] **Step 5: Apply and verify**

  ```bash
  task check
  task truenas
  # Verify share is visible from sturm
  doppler run -- ansible sturm -m shell \
    -a "showmount -e 192.168.233.6 2>&1" -i hosts -b
  ```
  Expected: `/mnt/tank/media/plex` listed in the NFS exports.

---

### Task 5: Mount NFS on Proxmox host (sturm) + configure Plex LXC bind mount + install Plex

**Context:** The NFS mount **must live on the Proxmox host (sturm)**, not inside the Plex LXC. LXCs cannot mount NFS directly — NFS requires kernel-level filesystem support that runs on the host. The mount is added to sturm's fstab, then passed into the LXC as a bind mount via Terraform. The `roles/plex` Ansible role runs on the Plex LXC and only handles Plex software installation.

**Files:**
- Create: `roles/proxmox/tasks/nfs-mounts.yml` — NFS mount on Proxmox host (runs on sturm only)
- Modify: `roles/proxmox/tasks/main.yml` — include nfs-mounts.yml
- Modify: `group_vars/sturm.yml` (create) — NFS mount vars specific to sturm
- Create: `roles/plex/tasks/main.yml` — Plex software install inside LXC
- Create: `roles/plex/defaults/main.yml`
- Modify: `terraform/plex.tf` — add mount_point bind mount
- Create: `group_vars/plex.yml`
- Modify: `hosts`
- Modify: `main.yml`
- Modify: `Taskfile.yml`

- [ ] **Step 1: Add plex to hosts file**

  The `[plex]` group should already exist (IP 192.168.233.12). Verify it's present:
  ```ini
  [plex]
  plex.tlesh.xyz ansible_host=192.168.233.12
  ```

- [ ] **Step 2: Create group_vars/sturm.yml with NFS mount vars**

  ```yaml
  ---
  # NFS mounts for this Proxmox node
  proxmox_nfs_mounts:
    - src: "192.168.233.6:/mnt/tank/media/plex"
      path: "/mnt/plex-media"
      opts: "_netdev,x-systemd.automount,rw,hard,intr,rsize=131072,wsize=131072,timeo=600"
  ```

- [ ] **Step 3: Create roles/proxmox/tasks/nfs-mounts.yml**

  ```yaml
  ---
  # tasks file for proxmox — NFS mounts on Proxmox host
  # Runs on the Proxmox host, NOT inside LXCs.
  # NFS mounts here are passed into LXCs as bind mounts via Terraform mount_point blocks.

  - name: Install NFS client on Proxmox host
    ansible.builtin.apt:
      name: nfs-common
      state: present
    become: true

  - name: Create NFS mount point directories
    ansible.builtin.file:
      path: "{{ item.path }}"
      state: directory
      mode: "0755"
    loop: "{{ proxmox_nfs_mounts | default([]) }}"
    become: true

  - name: Configure NFS mounts in fstab (automount, boot-safe)
    ansible.posix.mount:
      path: "{{ item.path }}"
      src: "{{ item.src }}"
      fstype: nfs
      opts: "{{ item.opts }}"
      state: mounted
    loop: "{{ proxmox_nfs_mounts | default([]) }}"
    become: true
  ```

- [ ] **Step 4: Include nfs-mounts.yml in roles/proxmox/tasks/main.yml**

  Append:
  ```yaml
  - name: Configure NFS mounts
    ansible.builtin.include_tasks: nfs-mounts.yml
  ```

- [ ] **Step 5: Add bind mount to terraform/plex.tf**

  Add inside the `proxmox_virtual_environment_container.plex` resource block, after the `disk` block:
  ```hcl
  mount_point {
    path   = "/media/plex"
    volume = "/mnt/plex-media"
  }
  ```
  > `volume` with a host path (starting with `/`) creates a bind mount passthrough. The `bpg/proxmox` provider maps this to `mp0: /mnt/plex-media,mp=/media/plex` in the LXC config. Verify with `terraform providers schema -json | python3 -m json.tool | grep -A5 mount_point` if the syntax differs in your installed version.

- [ ] **Step 6: Create group_vars/plex.yml**

  ```yaml
  ---
  plex_render_gid: 104   # update after checking: stat -c '%g' /dev/dri/renderD128 on sturm
  ```

- [ ] **Step 7: Create roles/plex/defaults/main.yml**

  ```yaml
  ---
  plex_render_gid: 104
  ```

- [ ] **Step 8: Create roles/plex/tasks/main.yml**

  This role runs **inside the Plex LXC** (192.168.233.12). It only handles Plex software installation — the NFS mount is already available as a bind mount via the Terraform config above.

  ```yaml
  ---
  # tasks file for plex — installs Plex inside the LXC
  # The /media/plex bind mount is provided by the Proxmox host via Terraform mount_point.

  - name: Install Plex Media Server
    ansible.builtin.shell:
      cmd: |
        set -o pipefail
        curl -fsSL https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor \
          -o /etc/apt/trusted.gpg.d/plexmediaserver.gpg
        echo "deb https://downloads.plex.tv/repo/deb public main" \
          > /etc/apt/sources.list.d/plexmediaserver.list
        apt-get update -qq
        apt-get install -y plexmediaserver
      executable: /bin/bash
      creates: /usr/lib/plexmediaserver/Plex\ Media\ Server
    become: true

  - name: Ensure Plex Media Server is enabled and started
    ansible.builtin.systemd:
      name: plexmediaserver
      enabled: true
      state: started
    become: true
  ```

- [ ] **Step 6: Add plex task to Taskfile.yml**

  Copy structure from an existing task (e.g., `glance`) and add:
  ```yaml
  plex:
    desc: Deploy Plex media server
    cmds:
      - doppler run -- ansible-playbook main.yml -l plex {{ .CLI_ARGS }}
  ```

- [ ] **Step 7: Add plex role to main.yml**

  Add a plex play to `main.yml`:
  ```yaml
  - hosts: plex
    become: true
    roles:
      - role: ansible-user
      - role: plex
  ```

- [ ] **Step 8: Apply and verify**

  ```bash
  task check
  task plex
  # Verify Plex is running
  doppler run -- ansible plex -m shell \
    -a "systemctl is-active plexmediaserver && ls /media/plex/" \
    -i hosts -b
  ```
  Expected: `active` and NFS mount contents visible inside LXC.

---

### Task 6: Provision and configure Netdata

**Context:** Add a Netdata parent LXC (vm_id 105, IP .23) on sturm. Install Netdata agents on all three Proxmox nodes streaming metrics to the parent.

**Files:**
- Create: `terraform/netdata.tf`
- Create: `roles/netdata/tasks/main.yml`
- Create: `roles/netdata/defaults/main.yml`
- Create: `group_vars/netdata.yml`
- Modify: `hosts`
- Modify: `main.yml`
- Modify: `Taskfile.yml`

- [ ] **Step 1: Add netdata to hosts file**

  ```ini
  [netdata]
  netdata.tlesh.xyz ansible_host=192.168.233.23
  ```

- [ ] **Step 2: Create terraform/netdata.tf**

  ```hcl
  resource "proxmox_virtual_environment_container" "netdata" {
    node_name    = "sturm"
    vm_id        = 105
    unprivileged = true

    description = "Netdata monitoring parent"

    features {
      nesting = true
    }

    disk {
      datastore_id = "vm_data"
      size         = 8
    }

    initialization {
      hostname = "netdata"

      dns {
        domain  = "tlesh.xyz"
        servers = ["1.1.1.1"]
      }

      ip_config {
        ipv4 {
          address = "192.168.233.23/24"
          gateway = "192.168.233.1"
        }
      }

      user_account {
        keys     = [nonsensitive(data.doppler_secrets.this.map.SSH_PUBLIC_KEY)]
        password = data.doppler_secrets.this.map.PM_API_PASSWORD
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
      mac_address = "BC:24:11:A2:3C:55"
      name        = "eth0"
    }

    operating_system {
      template_file_id = proxmox_virtual_environment_download_file.ubuntu_24_04_lxc_template.id
      type             = "ubuntu"
    }

    lifecycle {
      ignore_changes = [
        node_name,
        operating_system[0].template_file_id,
        initialization[0].user_account,
      ]
    }

    tags = ["terraform"]
  }
  ```

- [ ] **Step 3: Create roles/netdata/defaults/main.yml**

  ```yaml
  ---
  netdata_role: "parent"          # parent | child
  netdata_parent_host: ""         # set on child nodes
  netdata_parent_port: 19999
  netdata_claim_token: ""         # optional Netdata Cloud claim token
  ```

- [ ] **Step 4: Create group_vars/netdata.yml**

  ```yaml
  ---
  netdata_role: "parent"
  ```

  Add to `group_vars/proxmox.yml`:
  ```yaml
  # Netdata
  netdata_role: "child"
  netdata_parent_host: "192.168.233.23"
  ```

- [ ] **Step 5: Create roles/netdata/tasks/main.yml**

  ```yaml
  ---
  # tasks file for netdata

  - name: Install Netdata via kickstart script
    ansible.builtin.shell:
      cmd: |
        set -o pipefail
        wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
        bash /tmp/netdata-kickstart.sh --non-interactive --stable-channel 2>&1
      executable: /bin/bash
      creates: /usr/sbin/netdata
    become: true

  - name: Configure Netdata streaming (child → parent)
    ansible.builtin.blockinfile:
      path: /etc/netdata/stream.conf
      create: true
      marker: "# {mark} ANSIBLE MANAGED STREAMING"
      block: |
        [stream]
        enabled = {{ 'yes' if netdata_role == 'child' else 'no' }}
        destination = {{ netdata_parent_host }}:{{ netdata_parent_port }}
    become: true
    when: netdata_role == "child"
    notify: Restart Netdata

  - name: Ensure Netdata is enabled and started
    ansible.builtin.systemd:
      name: netdata
      enabled: true
      state: started
    become: true

  handlers:
    - name: Restart Netdata
      ansible.builtin.systemd:
        name: netdata
        state: restarted
      become: true
  ```

- [ ] **Step 6: Add netdata task to Taskfile.yml**

  ```yaml
  netdata:
    desc: Deploy Netdata monitoring
    cmds:
      - doppler run -- ansible-playbook main.yml -l netdata,proxmox {{ .CLI_ARGS }}
  ```

- [ ] **Step 7: Add netdata role to main.yml**

  ```yaml
  - hosts: netdata
    become: true
    roles:
      - role: ansible-user
      - role: netdata

  - hosts: proxmox
    become: true
    roles:
      - role: netdata   # installs child agent on each Proxmox node
  ```

- [ ] **Step 8: Apply Terraform, then Ansible**

  ```bash
  cd terraform && task
  # Review plan — expect 1 new resource: proxmox_virtual_environment_container.netdata
  cd terraform && task apply
  cd ..
  task check
  task netdata
  ```

- [ ] **Step 9: Verify Netdata is receiving metrics from all nodes**

  ```bash
  # Open Netdata dashboard
  open http://192.168.233.23:19999
  # Or check via curl
  curl -s http://192.168.233.23:19999/api/v1/info | python3 -m json.tool | grep -i host
  ```
  Expected: Dashboard shows metrics from netdata LXC + all three Proxmox nodes (tika, bupu, sturm).

- [ ] **Step 10: Configure Netdata TrueNAS collector on the parent LXC**

  Netdata includes a native `truenas` go.d plugin that polls the TrueNAS REST API from the Netdata parent — no configuration is needed on TrueNAS itself.

  Add to `roles/netdata/tasks/main.yml` (inside the `when: netdata_role == 'parent'` block or unconditionally if only the parent runs this role):

  ```yaml
  - name: Configure TrueNAS go.d collector
    ansible.builtin.copy:
      dest: /etc/netdata/go.d/truenas.conf
      owner: netdata
      group: netdata
      mode: "0640"
      content: |
        jobs:
          - name: truenas
            url: https://{{ truenas_host }}
            token: {{ truenas_api_key_netdata }}
            tls_skip_verify: true
    become: true
    when: netdata_role == "parent"
    notify: Restart Netdata
  ```

  Add to `group_vars/netdata.yml`:
  ```yaml
  truenas_host: "192.168.233.6"
  truenas_api_key_netdata: "{{ lookup('env', 'TRUENAS_API_KEY') }}"
  ```

  Ensure `TRUENAS_API_KEY` is set in Doppler (same key used by the truenas Ansible role in Task 4).

  After applying (`task netdata`), verify TrueNAS metrics appear:
  ```bash
  curl -s "http://192.168.233.23:19999/api/v1/charts" | python3 -m json.tool | grep truenas | head -10
  ```
  Expected: chart entries prefixed with `truenas.` (e.g., `truenas.cpu_temp`, `truenas.memory`, `truenas.storage_pool_status`).

- [ ] **Step 11: Commit Phase 1**

  ```bash
  git add roles/netdata roles/plex roles/proxmox roles/truenas \
    terraform/netdata.tf group_vars/netdata.yml group_vars/plex.yml \
    group_vars/sturm.yml hosts main.yml Taskfile.yml
  git commit -m "feat: Phase 1 — NFS share, Netdata observability, multipath config"
  ```

---

## Phase 2: Plex + Hardware Transcoding

---

### Task 7: Configure VAAPI hardware transcoding

**Context:** The Ryzen 7 5825U in sturm has an integrated Radeon Vega GPU. The Plex LXC is already privileged (unprivileged = false). Pass `/dev/dri/renderD128` into the LXC and ensure GID alignment.

**Files:**
- Modify: `roles/plex/tasks/main.yml`
- Modify: `terraform/plex.tf`

- [ ] **Step 1: Verify VAAPI is available on sturm**

  ```bash
  doppler run -- ansible sturm -m shell \
    -a "apt-get install -y vainfo 2>/dev/null; vainfo 2>&1 | head -20" \
    -i hosts -b
  ```
  Expected: `VAProfileH264*` and/or `VAProfileHEVC*` entries. If `vainfo` fails, install `mesa-va-drivers` on the Proxmox host.

- [ ] **Step 2: Get render device GID on sturm host**

  ```bash
  doppler run -- ansible sturm -m shell \
    -a "stat -c '%G %g' /dev/dri/renderD128" \
    -i hosts -b
  ```
  Record the GID (typically `render`, GID 104 or 105 on Ubuntu/Debian).

- [ ] **Step 3: Get render GID inside Plex LXC**

  ```bash
  doppler run -- ansible plex -m shell \
    -a "getent group render 2>/dev/null || echo 'render group missing'" \
    -i hosts -b
  ```
  If missing or different from host GID, the Plex user won't have access to the device.

- [ ] **Step 4: Add VAAPI and GID tasks to roles/plex/tasks/main.yml**

  Append to `roles/plex/tasks/main.yml`:
  ```yaml
  # VAAPI hardware transcoding

  - name: Install VAAPI drivers in Plex LXC
    ansible.builtin.apt:
      name:
        - vainfo
        - mesa-va-drivers
      state: present
    become: true

  - name: Ensure render group exists with correct GID
    ansible.builtin.group:
      name: render
      gid: "{{ plex_render_gid }}"
      state: present
    become: true

  - name: Add plex user to render group
    ansible.builtin.user:
      name: plex
      groups: render
      append: true
    become: true
    notify: Restart Plex
  ```

  Add to `roles/plex/defaults/main.yml`:
  ```yaml
  # Set to match host render group GID (check: stat -c '%g' /dev/dri/renderD128 on Proxmox host)
  plex_render_gid: 104
  ```

  Add handler at end of `roles/plex/tasks/main.yml`:
  ```yaml
  handlers:
    - name: Restart Plex
      ansible.builtin.systemd:
        name: plexmediaserver
        state: restarted
      become: true
  ```

- [ ] **Step 5: Add /dev/dri device passthrough to terraform/plex.tf**

  Add inside the `proxmox_virtual_environment_container.plex` resource, after the `features` block:
  ```hcl
  device {
    host_path     = "/dev/dri/renderD128"
    mode          = "0666"
  }
  ```

- [ ] **Step 6: Apply and verify VAAPI inside Plex LXC**

  ```bash
  task check
  cd terraform && task apply
  task plex
  doppler run -- ansible plex -m shell \
    -a "LIBVA_DRIVER_NAME=radeonsi vainfo 2>&1 | head -10" \
    -i hosts -b
  ```
  Expected: VA-API info showing Radeon Vega profile entries.

- [ ] **Step 7: Enable hardware transcoding in Plex**

  In the Plex web UI (http://192.168.233.12:32400/web):
  1. Settings → Transcoder → Enable Hardware-Accelerated Video Encoding ✓
  2. Play a video that requires transcoding → confirm the Plex dashboard shows "hw" in the transcode session.

- [ ] **Step 8: Configure Plex library**

  In the Plex web UI:
  1. Add Library → Movies/TV/Music
  2. Browse to `/media/plex` (the NFS bind mount path)
  3. Allow scan to complete

- [ ] **Step 9: Commit Phase 2**

  ```bash
  git add roles/plex terraform/plex.tf group_vars/plex.yml
  git commit -m "feat: Phase 2 — Plex NFS media + VAAPI hardware transcoding"
  ```

---

## Phase 3: LXC HA for pi-hole

**Prerequisites:** Phase 1 complete, iSCSI benchmarks passed.

---

### Task 8: Configure software watchdog on all Proxmox nodes

**Context:** Proxmox HA requires fencing. Mini PCs without IPMI use the `softdog` kernel module. Load it persistently via IaC.

**Files:**
- Modify: `roles/proxmox/tasks/hardware.yml`

- [ ] **Step 1: Add softdog module config to roles/proxmox/tasks/hardware.yml**

  Append:
  ```yaml
  - name: Load softdog kernel module persistently
    ansible.builtin.copy:
      dest: /etc/modules-load.d/softdog.conf
      content: "softdog\n"
      owner: root
      group: root
      mode: "0644"
    become: true

  - name: Load softdog module immediately
    community.general.modprobe:
      name: softdog
      state: present
    become: true

  - name: Configure Proxmox HA watchdog
    ansible.builtin.lineinfile:
      path: /etc/default/pve-ha-manager
      regexp: "^WATCHDOG_MODULE="
      line: "WATCHDOG_MODULE=softdog"
      create: true
    become: true
    notify: Restart pve-ha-lrm
  ```

  Add to `roles/proxmox/handlers/main.yml`:
  ```yaml
  - name: Restart pve-ha-lrm
    ansible.builtin.systemd:
      name: pve-ha-lrm
      state: restarted
    become: true
  ```

- [ ] **Step 2: Apply and verify**

  ```bash
  task check
  task proxmox
  doppler run -- ansible proxmox -m shell \
    -a "lsmod | grep softdog && cat /etc/default/pve-ha-manager" \
    -i hosts -b
  ```
  Expected: `softdog` appears in `lsmod` output on all three nodes.

- [ ] **Step 3: Verify HA is operational in Proxmox cluster**

  ```bash
  doppler run -- ansible sturm -m shell \
    -a "pvesh get /cluster/ha/status/current --output-format json 2>&1 | head -20" \
    -i hosts -b
  ```
  Expected: Status output without errors. If HA complains about quorum or fencing, check `journalctl -u pve-ha-crm` on each node.

---

### Task 9: Migrate pi-hole disk to iSCSI + create HA resource

**Context:** Move pi-hole's root disk from `vm_data` (local) to `truenas-lvm` (shared iSCSI). Then declare an HA resource via Terraform. The disk move is a manual step — the Terraform provider does not support live disk migration.

**Files:**
- Modify: `terraform/pi-hole.tf`

- [ ] **Step 1: Stop pi-hole LXC before migration**

  In Proxmox web UI or via pvesh:
  ```bash
  doppler run -- ansible sturm -m shell \
    -a "pct stop 102" -i hosts -b
  ```

- [ ] **Step 2: Move root disk to iSCSI storage**

  ```bash
  doppler run -- ansible sturm -m shell \
    -a "pct move-volume 102 rootfs truenas-lvm --delete 1 2>&1" \
    -i hosts -b
  ```
  This migrates the rootfs volume to the shared `truenas-lvm` storage and deletes the old local disk. Wait for completion (may take 1-2 minutes for an 8GB disk).

- [ ] **Step 3: Verify disk is on new storage**

  ```bash
  doppler run -- ansible sturm -m shell \
    -a "pct config 102 | grep rootfs" -i hosts -b
  ```
  Expected: `rootfs: truenas-lvm:vm-102-disk-0,...`

- [ ] **Step 4: Start pi-hole and verify DNS is working**

  ```bash
  doppler run -- ansible sturm -m shell -a "pct start 102" -i hosts -b
  sleep 10
  doppler run -- ansible pi-hole -m shell -a "systemctl is-active pihole-FTL" -i hosts -b
  # Test DNS resolution
  dig @192.168.233.3 google.com +short
  ```
  Expected: `active` and a valid DNS response.

- [ ] **Step 5: Update terraform/pi-hole.tf to reflect new storage + add lifecycle guard**

  Change `datastore_id` and add lifecycle guard:
  ```hcl
  disk {
    datastore_id = "truenas-lvm"
    size         = 8
  }

  lifecycle {
    ignore_changes = [
      node_name,
      operating_system[0].template_file_id,
      initialization[0].user_account,
      disk,  # disk already migrated manually — prevent Terraform from recreating
    ]
  }
  ```

- [ ] **Step 6: Run terraform plan to confirm no unexpected changes**

  ```bash
  cd terraform && task
  ```
  Expected: `No changes` or only tag/metadata updates. If Terraform plans to recreate the disk, verify the `disk` entry in `ignore_changes` was added correctly.

- [ ] **Step 7: Create HA resource — add to terraform/pi-hole.tf**

  ```hcl
  resource "proxmox_virtual_environment_haresource" "pi_hole" {
    resource_id  = "ct:102"
    state        = "started"
    max_restart  = 3
    max_relocate = 3
    group        = proxmox_virtual_environment_hagroup.main.id
  }

  resource "proxmox_virtual_environment_hagroup" "main" {
    group   = "main-group"
    comment = "Primary HA group — prefer sturm, failover to bupu/tika"

    nodes = {
      sturm = 3  # highest priority
      bupu  = 2
      tika  = 1
    }
  }
  ```

- [ ] **Step 8: Apply HA resource**

  ```bash
  cd terraform && task
  # Review plan — expect 2 new resources: haresource + hagroup
  cd terraform && task apply
  ```

- [ ] **Step 9: Test HA failover**

  ```bash
  # Confirm pi-hole DNS is working before test
  dig @192.168.233.3 google.com +short

  # Stop sturm (or simulate failure)
  doppler run -- ansible sturm -m shell \
    -a "systemctl stop pve-ha-crm pve-ha-lrm 2>&1" -i hosts -b
  ```
  Wait 60–90 seconds for HA timeout. Then check:
  ```bash
  # pi-hole should have restarted on bupu or tika
  doppler run -- ansible proxmox -m shell \
    -a "pct list 2>/dev/null | grep 102" -i hosts -b
  dig @192.168.233.3 google.com +short
  ```
  Expected: pi-hole running on bupu or tika, DNS still resolving.

  Restart sturm HA services when done:
  ```bash
  doppler run -- ansible sturm -m shell \
    -a "systemctl start pve-ha-crm pve-ha-lrm" -i hosts -b
  ```

- [ ] **Step 10: Monitor Corosync latency via Netdata**

  Open http://192.168.233.23:19999 and check network latency between nodes. If Corosync latency spikes during iSCSI-heavy workloads, add QoS:
  ```bash
  # On each Proxmox node — prioritize Corosync UDP traffic
  tc qdisc add dev eth0 root handle 1: prio
  tc filter add dev eth0 parent 1: protocol ip u32 \
    match ip dport 5404 0xffff flowid 1:1
  tc filter add dev eth0 parent 1: protocol ip u32 \
    match ip dport 5405 0xffff flowid 1:1
  ```
  Automate via `roles/proxmox` if the issue is persistent.

- [ ] **Step 11: Commit Phase 3**

  ```bash
  git add roles/proxmox terraform/pi-hole.tf
  git commit -m "feat: Phase 3 — pi-hole HA on shared iSCSI storage, softdog watchdog"
  ```

---

## Final Validation Checklist

- [ ] `vm_data` confirmed on 512GB data disk on all nodes
- [ ] iSCSI visible on all three nodes (`pvesh get /storage/truenas-lvm`)
- [ ] fio benchmarks passed (sequential ≥ 100MB/s, IOPS ≥ 500, p99 < 10ms)
- [ ] Plex accessible at http://192.168.233.12:32400, media library populated
- [ ] Hardware transcoding active (verify in Plex dashboard during playback)
- [ ] Netdata dashboard at http://192.168.233.23:19999 shows all three nodes + TrueNAS
- [ ] pi-hole DNS resolving from shared iSCSI storage
- [ ] HA failover test passed (pi-hole restarted on alternate node)
- [ ] No Terraform drift (`cd terraform && task` shows no unplanned changes)
