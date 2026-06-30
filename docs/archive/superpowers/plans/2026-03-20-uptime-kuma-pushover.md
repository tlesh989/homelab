# Uptime Kuma + Pushover Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Uptime Kuma on a dedicated LXC container to send Pushover notifications when homelab services fail and do not self-recover.

**Architecture:** New LXC `uptime-kuma` (VM 116, IP 192.168.233.16) on sturm, provisioned by Terraform and configured by a new Ansible role `uptime-kuma`. Uptime Kuma runs as a single Docker container. Pushover credentials come from Doppler (reused from Watchtower). 18 HTTP monitors are configured manually via the web UI post-deploy.

**Tech Stack:** Terraform (`bpg/proxmox` provider), Ansible (`geerlingguy.docker`, `community.docker.docker_compose_v2`), Docker, Uptime Kuma, Pushover (via existing Doppler secrets `PUSHOVER_API_TOKEN` + `PUSHOVER_USER_KEY`), Task (Taskfile.yml)

**Spec:** `docs/superpowers/specs/2026-03-20-uptime-kuma-pushover-design.md`

**Beads issues:** homelab-0ha (Terraform), homelab-65e (Ansible role), homelab-dqo (wiring), homelab-j78 (runbook), homelab-dead (manual setup)

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `terraform/uptime-kuma.tf` | Create | LXC container resource for Uptime Kuma |
| `roles/uptime-kuma/defaults/main.yml` | Create | Default vars (port, data path) |
| `roles/uptime-kuma/tasks/main.yml` | Create | Role entry point — imports sub-task files |
| `roles/uptime-kuma/tasks/directories.yml` | Create | Create `/opt/uptime-kuma/data` |
| `roles/uptime-kuma/tasks/compose.yml` | Create | Deploy Docker Compose stack |
| `roles/uptime-kuma/templates/docker-compose.yml.j2` | Create | Uptime Kuma Docker Compose template |
| `roles/uptime-kuma/handlers/main.yml` | Create | Handler to restart Uptime Kuma on change |
| `roles/arr/templates/docker-compose.yml.j2` | Modify | Expose Gluetun control port 8000 for monitoring |
| `hosts` | Modify | Add `[uptime-kuma]` group and add to `[lxc:children]` |
| `main.yml` | Modify | Add `setup uptime-kuma` play |
| `Taskfile.yml` | Modify | Add `uptime-kuma` task |
| `docs/runbooks/uptime-kuma-monitors.md` | Create | Recovery runbook listing all 18 monitors |

---

## Task 1: Terraform — Provision uptime-kuma LXC (homelab-0ha)

**Files:**
- Create: `terraform/uptime-kuma.tf`

> No unit tests for Terraform — validation is `task test` (fmt + validate) and `task plan` review.

- [ ] **Step 1: Mark issue in progress**

```bash
bd update homelab-0ha --status=in_progress
```

- [ ] **Step 2: Create feature branch**

```bash
git checkout dev
git pull
git checkout -b feature/uptime-kuma
```

- [ ] **Step 3: Choose a unique MAC address**

Look at existing containers' MAC addresses in `terraform/*.tf` to find one not in use. They follow the `BC:24:11:xx:xx:xx` convention. Pick an unused value (e.g. `BC:24:11:A2:3F:11`).

- [ ] **Step 4: Create `terraform/uptime-kuma.tf`**

```hcl
resource "proxmox_virtual_environment_container" "uptime_kuma" {
  node_name    = "sturm"
  vm_id        = 116
  unprivileged = true

  features {
    nesting = true
  }

  disk {
    datastore_id = "truenas-lvm"
    size         = 8
  }

  initialization {
    hostname = "uptime-kuma"

    dns {
      domain  = "tlesh.xyz"
      servers = ["1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.233.16/24"
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
    swap      = 256
  }

  network_interface {
    bridge      = "vmbr0"
    enabled     = true
    firewall    = true
    mac_address = "BC:24:11:A2:3F:11"
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
      disk,
    ]
  }

  tags = ["terraform"]
}
```

- [ ] **Step 5: Validate**

```bash
cd terraform && task test
```

Expected: `terraform fmt` makes no changes, `terraform validate` outputs `Success! The configuration is valid.`

- [ ] **Step 6: Review plan**

```bash
cd terraform && task plan
```

Expected: plan shows 1 resource to add (`proxmox_virtual_environment_container.uptime_kuma`), no changes to existing resources.

- [ ] **Step 7: Commit**

```bash
git add terraform/uptime-kuma.tf
git commit -m "feat: add uptime-kuma LXC Terraform resource"
```

---

## Task 2: Ansible Role — roles/uptime-kuma (homelab-65e)

**Files:**
- Create: `roles/uptime-kuma/defaults/main.yml`
- Create: `roles/uptime-kuma/tasks/main.yml`
- Create: `roles/uptime-kuma/tasks/docker.yml`
- Create: `roles/uptime-kuma/tasks/directories.yml`
- Create: `roles/uptime-kuma/tasks/compose.yml`
- Create: `roles/uptime-kuma/templates/docker-compose.yml.j2`
- Create: `roles/uptime-kuma/handlers/main.yml`
- Modify: `roles/arr/templates/docker-compose.yml.j2`

- [ ] **Step 1: Mark issue in progress**

```bash
bd update homelab-65e --status=in_progress
```

- [ ] **Step 2: Create defaults**

Create `roles/uptime-kuma/defaults/main.yml`:

```yaml
---
uptime_kuma_data_path: /opt/uptime-kuma/data
uptime_kuma_port: 3001
```

- [ ] **Step 3: Create task entry point**

Create `roles/uptime-kuma/tasks/main.yml`:

```yaml
---
- name: Install Docker
  ansible.builtin.import_tasks: docker.yml

- name: Create directories
  ansible.builtin.import_tasks: directories.yml

- name: Deploy Docker Compose stack
  ansible.builtin.import_tasks: compose.yml
```

Create `roles/uptime-kuma/tasks/docker.yml`:

```yaml
---
- name: Install Docker
  ansible.builtin.import_role:
    name: geerlingguy.docker
```

- [ ] **Step 4: Create directories task**

Create `roles/uptime-kuma/tasks/directories.yml`:

```yaml
---
- name: Create uptime-kuma data directory
  ansible.builtin.file:
    path: "{{ uptime_kuma_data_path }}"
    state: directory
    mode: "0755"
    owner: root
    group: root
```

- [ ] **Step 5: Create compose task**

Create `roles/uptime-kuma/tasks/compose.yml`:

```yaml
---
- name: Deploy docker-compose.yml
  ansible.builtin.template:
    src: docker-compose.yml.j2
    dest: /opt/uptime-kuma/docker-compose.yml
    owner: root
    group: root
    mode: "0644"
  notify: restart uptime-kuma

- name: Start uptime-kuma Docker Compose stack
  community.docker.docker_compose_v2:
    project_src: /opt/uptime-kuma
    state: present
    pull: missing
  when: not ansible_check_mode
```

- [ ] **Step 6: Create Docker Compose template**

Create `roles/uptime-kuma/templates/docker-compose.yml.j2`:

```yaml
---
# Managed by Ansible — do not edit manually
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    security_opt:
      - apparmor=unconfined
    volumes:
      - "{{ uptime_kuma_data_path }}:/app/data"
    ports:
      - "{{ uptime_kuma_port }}:3001"
    restart: unless-stopped
```

> `security_opt: apparmor=unconfined` is required for all Docker containers in unprivileged LXC containers. Docker attempts to load the `docker-default` AppArmor profile on startup, which fails under LXC confinement (`apparmor_parser` requires policy admin privileges). This disables AppArmor for the container — a documented tradeoff. See the comment block in `roles/arr/templates/docker-compose.yml.j2` for full context.

- [ ] **Step 7: Create handler**

Create `roles/uptime-kuma/handlers/main.yml`:

```yaml
---
- name: restart uptime-kuma
  community.docker.docker_compose_v2:
    project_src: /opt/uptime-kuma
    state: restarted
  when: not ansible_check_mode
```

- [ ] **Step 8: Expose Gluetun control port in arr Docker Compose**

Edit `roles/arr/templates/docker-compose.yml.j2`. Find the `gluetun` service `ports:` block and add port 8000:

```yaml
    ports:
      - "{{ arr_qbittorrent_port }}:{{ arr_qbittorrent_port }}"
      - "8000:8000"
```

This exposes Gluetun's HTTP control API so Uptime Kuma can check `/v1/publicip/ip` to verify the VPN tunnel is live.

> **Note:** This change will trigger a restart of the entire arr stack (gluetun + all `network_mode: service:gluetun` containers) on the next `task arr` run. Plan for ~1 minute of arr downtime when deploying.

- [ ] **Step 9: Syntax check**

```bash
task syntax
```

Expected: no errors.

- [ ] **Step 10: Lint**

```bash
task lint
```

Expected: no errors or warnings on the new role files.

- [ ] **Step 11: Commit**

```bash
git add roles/uptime-kuma/ roles/arr/templates/docker-compose.yml.j2
git commit -m "feat: add uptime-kuma Ansible role with Docker Compose deploy"
```

---

## Task 3: Wiring — Inventory, main.yml, Taskfile (homelab-dqo)

**Files:**
- Modify: `hosts`
- Modify: `main.yml`
- Modify: `Taskfile.yml`

- [ ] **Step 1: Mark issue in progress**

```bash
bd update homelab-dqo --status=in_progress
```

- [ ] **Step 2: Add host to inventory**

Edit `hosts`. Add the new group after the `[arr]` block:

```ini
[uptime-kuma]
uptime-kuma.tlesh.xyz ansible_host=192.168.233.16
```

Also add `uptime-kuma` under `[lxc:children]`:

```ini
[lxc:children]
tailscale
plex
glance
pi-hole
netdata
arr
uptime-kuma
```

- [ ] **Step 3: Add play to main.yml**

Edit `main.yml`. Add this play at the end, following the existing pattern:

```yaml
- name: setup uptime-kuma server
  hosts: uptime-kuma
  become: true
  roles:
    - role: ansible-user
    - role: GROG.package
    - role: uptime-kuma
```

- [ ] **Step 4: Add Taskfile task**

Edit `Taskfile.yml`. Add an `uptime-kuma` task following the `arr:` pattern:

```yaml
  uptime-kuma:
    desc: Deploy Uptime Kuma monitoring server
    cmds:
      - task: ansible
        vars: { PLAYBOOK: "main.yml", LIMIT: "uptime-kuma", CLI_ARGS: "{{.CLI_ARGS}}" }
```

- [ ] **Step 5: Syntax and lint check**

```bash
task syntax && task lint
```

Expected: both pass with no errors.

- [ ] **Step 6: Dry-run check**

```bash
task check
```

Expected: shows expected changes for `uptime-kuma` host only. No unexpected changes to other hosts.

- [ ] **Step 7: Commit**

```bash
git add hosts main.yml Taskfile.yml
git commit -m "feat: wire up uptime-kuma host group, inventory, and Taskfile task"
```

---

## Task 4: Runbook (homelab-j78)

**Files:**
- Create: `docs/runbooks/uptime-kuma-monitors.md`

- [ ] **Step 1: Mark issue in progress**

```bash
bd update homelab-j78 --status=in_progress
```

- [ ] **Step 2: Create runbook**

Create `docs/runbooks/uptime-kuma-monitors.md`:

```markdown
# Uptime Kuma Monitor Recovery Runbook

Use this document to recreate all monitors if the Uptime Kuma data volume is lost.

**URL:** http://192.168.233.16:3001
**Notification:** Configure one Pushover notification channel first.
  - Pushover API Token: `PUSHOVER_API_TOKEN` from Doppler
  - Pushover User Key: `PUSHOVER_USER_KEY` from Doppler

**Global settings for all monitors:**
- Type: HTTP(s)
- Heartbeat interval: 60 seconds
- Retries before alert: 3
- Accepted status codes: 200-299

---

## ARR Stack

| Name | URL | Notes |
|---|---|---|
| Sonarr | http://arr.tlesh.xyz:8989/api/v3/health | |
| Radarr | http://arr.tlesh.xyz:7878/api/v3/health | |
| Prowlarr | http://arr.tlesh.xyz:9696/api/v1/health | |
| Bazarr | http://arr.tlesh.xyz:6767/api/v1/system/health | |
| Seerr | http://arr.tlesh.xyz:5055/api/v1/status | |
| qBittorrent | http://arr.tlesh.xyz:8080 | |
| FlareSolverr | http://arr.tlesh.xyz:8191 | |
| Gluetun VPN | http://arr.tlesh.xyz:8000/v1/publicip/ip | Response body should contain a ProtonVPN IP |

## Core Services

| Name | URL | Notes |
|---|---|---|
| Plex | http://plex.tlesh.xyz:32400/identity | |
| Pi-hole | http://pi-hole.tlesh.xyz/admin | |
| Glance | http://glance.tlesh.xyz:8080 | |
| Netdata | http://netdata.tlesh.xyz:19999 | |

## Infrastructure

| Name | URL | Notes |
|---|---|---|
| Proxmox tika | https://tika.tlesh.xyz:8006 | Enable "Ignore TLS/SSL error" |
| Proxmox bupu | https://bupu.tlesh.xyz:8006 | Enable "Ignore TLS/SSL error" |
| Proxmox sturm | https://sturm.tlesh.xyz:8006 | Enable "Ignore TLS/SSL error" |
| TrueNAS | http://ansalon.tlesh.xyz | |
```

- [ ] **Step 3: Commit**

```bash
git add docs/runbooks/uptime-kuma-monitors.md
git commit -m "docs: add uptime-kuma monitors recovery runbook"
```

- [ ] **Step 4: Close issue**

```bash
bd close homelab-j78
```

---

## Task 5: Deploy and First-Time Setup (homelab-dead)

> **Prerequisite:** Tasks 1–4 must be complete. The LXC must be provisioned via `terraform apply` before running Ansible.

- [ ] **Step 1: Mark issue in progress**

```bash
bd update homelab-dead --status=in_progress
```

- [ ] **Step 2: Apply Terraform**

```bash
cd terraform && task apply
```

Expected: 1 resource created (`proxmox_virtual_environment_container.uptime_kuma`). Verify the container appears in the Proxmox UI on sturm.

- [ ] **Step 3: Bootstrap the new LXC**

```bash
doppler run -- ansible-playbook -b bootstrap.yml --limit uptime-kuma.tlesh.xyz --tags bootstrap -e "ansible_user=root"
```

> Must use `-e "ansible_user=root"` — Doppler sets `SSH_USER=tommy` locally but the container only has root at first boot.

- [ ] **Step 4: Deploy Ansible role**

```bash
task uptime-kuma
```

Expected: all tasks complete without errors. Check mode skips `docker_compose_v2` steps — that's expected.

- [ ] **Step 5: Verify Uptime Kuma is reachable**

Open `http://192.168.233.16:3001` in a browser. You should see the Uptime Kuma setup/login screen.

- [ ] **Step 6: Configure Pushover notification channel**

In the Uptime Kuma UI:
1. Go to **Settings → Notifications → Add Notification**
2. Type: **Pushover**
3. API Token: value of `PUSHOVER_API_TOKEN` from Doppler
4. User Key: value of `PUSHOVER_USER_KEY` from Doppler
5. Name it "Pushover"
6. Click **Test** — verify you receive a test notification on your phone
7. Save

- [ ] **Step 7: Add all 18 monitors**

Follow `docs/runbooks/uptime-kuma-monitors.md`. For each monitor:
1. Click **Add New Monitor**
2. Type: HTTP(s)
3. Set name, URL, interval (60s), retries (3)
4. Assign "Pushover" notification
5. Save

For the 3 Proxmox monitors: enable **"Ignore TLS/SSL error"** (self-signed certs).

- [ ] **Step 8: Verify all monitors go green**

Wait ~2 minutes. All 18 monitors should show green/up. Investigate any that stay red.

- [ ] **Step 9: Close all issues**

```bash
bd close homelab-0ha homelab-65e homelab-dqo homelab-dead
```

---

## Final Validation (Definition of Done)

- [ ] `task syntax` passes
- [ ] `task lint` passes
- [ ] `task check` dry-run shows changes only for `uptime-kuma` host group
- [ ] `cd terraform && task test` passes
- [ ] Uptime Kuma accessible at `http://192.168.233.16:3001`
- [ ] All 18 monitors green
- [ ] Test Pushover notification received on phone

---

## Open a PR

```bash
# Run coderabbit review first (required before PR per project conventions)
coderabbit review --plain --base dev

# Then ship
/ship
```
