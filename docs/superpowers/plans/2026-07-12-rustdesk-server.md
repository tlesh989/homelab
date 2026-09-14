# RustDesk Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a self-hosted RustDesk server (`hbbs` + `hbbr`) to kaz via a new Ansible role, reachable only over Tailscale.

**Architecture:** New `roles/rustdesk` role deploys the official `rustdesk/rustdesk-server` image as two containers via `community.docker.docker_container`, wired into kaz's existing play in `main.yml`. All published ports are bound to kaz's Tailscale IP only.

**Tech Stack:** Ansible, `community.docker.docker_container`, Docker image `rustdesk/rustdesk-server`.

## Global Constraints

- Image tag pinned to major version only (e.g. `"1"`), never `:latest` — `.claude/rules/docker.md`
- Every task needs a descriptive `name:` — `.claude/rules/ansible.md`
- `mode:` required on every file/copy task — `feedback_ansible_mode_param`
- All published ports bound to `rustdesk_tailscale_ip` (`100.70.205.92`), never `0.0.0.0` — spec security requirement
- No secrets involved (keypair is generated in-container, never stored in Doppler or the repo)
- 2-space YAML indentation, `become: true` scoped to tasks that need it, not globally

---

### Task 1: Scaffold the `rustdesk` role with variables and data directory

**Files:**
- Create: `roles/rustdesk/defaults/main.yml`
- Create: `roles/rustdesk/tasks/main.yml`

**Interfaces:**
- Produces: role variables `rustdesk_version`, `rustdesk_tailscale_ip`, `rustdesk_data_path` — consumed by Task 2's container definitions.

- [ ] **Step 1: Create the role's defaults file**

`roles/rustdesk/defaults/main.yml`:
```yaml
---
rustdesk_version: "1"
rustdesk_tailscale_ip: "100.70.205.92"
rustdesk_data_path: /opt/rustdesk/data
```

- [ ] **Step 2: Create tasks/main.yml with the data directory task**

`roles/rustdesk/tasks/main.yml`:
```yaml
---
- name: Create RustDesk data directory
  ansible.builtin.file:
    path: "{{ rustdesk_data_path }}"
    state: directory
    owner: root
    group: root
    mode: "0700"
  become: true

- name: Install Docker Python SDK
  ansible.builtin.package:
    name: python3-docker
    state: present
  become: true
```

- [ ] **Step 3: Verify syntax**

Run: `cd /Users/tommy/repos/tlesh989/homelab && ansible-lint roles/rustdesk`
Expected: no errors (role isn't wired into a play yet, so this only lints the role's own YAML)

- [ ] **Step 4: Commit**

```bash
git add roles/rustdesk/defaults/main.yml roles/rustdesk/tasks/main.yml
git commit -m "feat(rustdesk): scaffold role with variables and data directory"
```

---

### Task 2: Add the `hbbs` and `hbbr` container tasks

**Files:**
- Modify: `roles/rustdesk/tasks/main.yml` (append after Task 1's tasks)

**Interfaces:**
- Consumes: `rustdesk_version`, `rustdesk_tailscale_ip`, `rustdesk_data_path` from Task 1's defaults.
- Produces: running containers named `hbbs` and `hbbr` — consumed by Task 4's deploy verification.

- [ ] **Step 1: Append the `hbbs` container task**

Append to `roles/rustdesk/tasks/main.yml`:
```yaml
- name: Deploy hbbs container (RustDesk rendezvous/ID server)
  community.docker.docker_container:
    name: hbbs
    image: "rustdesk/rustdesk-server:{{ rustdesk_version }}"
    command: ["hbbs", "-r", "{{ rustdesk_tailscale_ip }}:21117"]
    state: started
    restart_policy: always
    ports:
      - "{{ rustdesk_tailscale_ip }}:21115:21115/tcp"
      - "{{ rustdesk_tailscale_ip }}:21116:21116/tcp"
      - "{{ rustdesk_tailscale_ip }}:21116:21116/udp"
      - "{{ rustdesk_tailscale_ip }}:21118:21118/tcp"
    volumes:
      - "{{ rustdesk_data_path }}:/root"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

- [ ] **Step 2: Append the `hbbr` container task**

Append to `roles/rustdesk/tasks/main.yml`:
```yaml
- name: Deploy hbbr container (RustDesk relay)
  community.docker.docker_container:
    name: hbbr
    image: "rustdesk/rustdesk-server:{{ rustdesk_version }}"
    command: ["hbbr"]
    state: started
    restart_policy: always
    ports:
      - "{{ rustdesk_tailscale_ip }}:21117:21117/tcp"
      - "{{ rustdesk_tailscale_ip }}:21119:21119/tcp"
    volumes:
      - "{{ rustdesk_data_path }}:/root"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

- [ ] **Step 3: Verify syntax and lint**

Run: `cd /Users/tommy/repos/tlesh989/homelab && ansible-lint roles/rustdesk`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add roles/rustdesk/tasks/main.yml
git commit -m "feat(rustdesk): deploy hbbs and hbbr containers"
```

---

### Task 3: Wire the role into kaz's play

**Files:**
- Modify: `main.yml:132` (insert after the existing `n8n` role entry, inside the `setup docker server` play's `roles:` list)

**Interfaces:**
- Consumes: `roles/rustdesk` role produced by Tasks 1-2.

- [ ] **Step 1: Add the role to the kaz play**

In `main.yml`, the `setup docker server` play's `roles:` list currently reads (around line 124-134):
```yaml
  roles:
    - role: users
    - role: geerlingguy.ntp
    - role: geerlingguy.docker
    - role: artis3n.tailscale.machine
      when: not ansible_check_mode
    - role: watchtower
    - role: glance
    - role: n8n
    - role: freshrss
    - role: cloudflare_ddns
```

Change the `- role: n8n` line to add `rustdesk` immediately after it:
```yaml
    - role: n8n
    - role: rustdesk
    - role: freshrss
    - role: cloudflare_ddns
```

- [ ] **Step 2: Run syntax check**

Run: `cd /Users/tommy/repos/tlesh989/homelab && task syntax`
Expected: `playbook: main.yml` with no errors

- [ ] **Step 3: Run lint**

Run: `cd /Users/tommy/repos/tlesh989/homelab && task lint`
Expected: no errors reported for `roles/rustdesk` or `main.yml`

- [ ] **Step 4: Run a dry-run against kaz**

Run: `cd /Users/tommy/repos/tlesh989/homelab && task kaz -- --check`
Expected: dry-run completes with no errors; `hbbs`/`hbbr` container tasks show as `skipped` (guarded by `not ansible_check_mode`)

- [ ] **Step 5: Commit**

```bash
git add main.yml
git commit -m "feat(rustdesk): wire role into kaz play"
```

---

### Task 4: Deploy and verify

**Files:** none (deployment + manual verification only)

**Interfaces:** none — this task exercises Tasks 1-3's output.

- [ ] **Step 1: Apply the playbook to kaz**

Run: `cd /Users/tommy/repos/tlesh989/homelab && task kaz`
Expected: `hbbs` and `hbbr` containers report `changed`, play recap shows `failed=0`

- [ ] **Step 2: Confirm both containers are running on kaz**

Run: `doppler run -- ansible kaz -m shell -a "docker ps --filter name=hbb --format '{{'{{'}}.Names{{'}}'}}: {{'{{'}}.Status{{'}}'}}'"`
Expected: two lines, `hbbs: Up ...` and `hbbr: Up ...`

- [ ] **Step 3: Confirm hbbs generated its keypair with no bind errors**

Run: `doppler run -- ansible kaz -m shell -a "docker logs hbbs 2>&1 | tail -20"`
Expected: log output shows the key files were generated (or already present) and no `address already in use` / bind-failure errors

- [ ] **Step 4: Confirm ports are Tailscale-only, not LAN-reachable**

From your Mac (on the home LAN, Tailscale temporarily disconnected or from a separate LAN-only device), attempt: `nc -zv 192.168.233.10 21116`
Expected: connection refused/times out (port is bound to the Tailscale IP, not the LAN IP)

Then with Tailscale connected: `nc -zv 100.70.205.92 21116`
Expected: connection succeeds

- [ ] **Step 5: Configure the RustDesk clients**

On the Windows 11 PC and your Mac's RustDesk client: Settings → Network → ID/Relay Server, set to `100.70.205.92`, leaving Key blank initially so the client fetches it, or paste the public key from:

Run: `doppler run -- ansible kaz -m shell -a "cat /opt/rustdesk/data/id_ed25519.pub"` (`docker logs hbbs` also prints the key on first startup — either source works)

Expected: both clients show the server as connected (green) in their Network settings

- [ ] **Step 6: Live connection test**

From the Mac's RustDesk client, connect to the Windows PC's ID.
Expected: session connects successfully with no "for testing purposes only" warning

- [ ] **Step 7: Add Uptime Kuma monitor (manual, no Ansible automation exists for Uptime Kuma monitors)**

In the Uptime Kuma web UI, add a new **TCP Port** monitor:
- Friendly name: `RustDesk hbbs`
- Hostname: `100.70.205.92`
- Port: `21116`

Expected: monitor shows "Up" after its first check

---

## Self-Review Notes

- Spec coverage: architecture (Tasks 1-2), Tailscale-only binding (Task 2 ports, verified Task 4 Step 4), key persistence via volume (Task 2 `volumes:`), main.yml wiring (Task 3), verification steps from spec (Task 4), Uptime Kuma checklist item (Task 4 Step 7). Glance/Watchtower explicitly out of scope per spec (no web UI; Watchtower already covers kaz).
- No placeholders — all steps contain literal file contents, exact commands, and expected output.
- Type/name consistency checked: `rustdesk_tailscale_ip`, `rustdesk_data_path`, `rustdesk_version` used identically across Tasks 1-2; container names `hbbs`/`hbbr` consistent across Tasks 2 and 4.
