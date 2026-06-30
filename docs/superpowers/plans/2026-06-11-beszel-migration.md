# Beszel Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken Grafana + Prometheus + 7-exporter stack and leftover Netdata artifacts with Beszel — a lightweight, self-contained monitoring platform providing host/Docker metrics, alerts, and S.M.A.R.T. health across all homelab nodes.

**Architecture:** Beszel hub runs as a Docker container on kaz (port 8090); agents run as systemd-managed binaries on all other hosts (Proxmox bare-metal + LXCs) and as a Docker container co-located with the hub on kaz (for Docker stat collection). Agents connect outbound to the hub via WebSocket — no inbound ports required on agents. Hub credentials (public KEY + API TOKEN) are stored in Doppler and injected at deploy time.

**Tech Stack:** Ansible, Docker (kaz hub + agent), systemd binary (all other agents), Doppler secrets, Beszel `henrygd/beszel` + `henrygd/beszel-agent` images.

---

## Beads Issues

Create these before starting:

```bash
bd create --title="Replace Grafana/Prometheus/Netdata with Beszel" \
  --description="Tear down the broken monitoring stack (Grafana, Prometheus, 7 exporters, node_exporter, Netdata) and replace with Beszel. See docs/superpowers/plans/2026-06-11-beszel-migration.md." \
  --type=feature --priority=2
```

Close `homelab-a8i` (Add Prometheus alert rules — superseded by Beszel alerting):

```bash
bd close homelab-a8i --reason="Prometheus removed; Beszel has built-in alerting"
```

---

## File Map

| Action | Path |
|--------|------|
| DELETE | `roles/monitoring/` (entire directory) |
| DELETE | `roles/node_exporter/` (entire directory) |
| DELETE | `roles/netdata/` (after running removal) |
| CREATE | `roles/beszel/defaults/main.yml` |
| CREATE | `roles/beszel/handlers/main.yml` |
| CREATE | `roles/beszel/tasks/main.yml` |
| CREATE | `roles/beszel/tasks/hub.yml` |
| CREATE | `roles/beszel/tasks/agent.yml` |
| MODIFY | `main.yml` — remove 2 plays, add 1 beszel play |
| MODIFY | `hosts` — remove `[exporters:children]` + `[monitoring:children]`, add `[beszel_hub]` + `[beszel_agents:children]` |
| MODIFY | `Taskfile.yml` — remove `monitoring:` task, add `beszel:` task |

---

## Task 1: Stop and remove running monitoring containers on kaz

**Files:**
- Create: `teardown-monitoring.yml` (temporary, deleted after running)

- [ ] **Step 1: Write teardown playbook**

```yaml
# teardown-monitoring.yml
---
- name: Tear down Grafana/Prometheus monitoring stack
  hosts: kaz
  gather_facts: false
  become: true
  tasks:
    - name: Stop and remove monitoring containers
      community.docker.docker_container:
        name: "{{ item }}"
        state: absent
      loop:
        - prometheus
        - grafana
        - cadvisor
        - pve-exporter
        - dozzle
        - truenas-exporter
        - unpoller
        - pihole-exporter
        - plex-exporter
      failed_when: false

    - name: Remove monitoring Docker network
      community.docker.docker_network:
        name: monitoring
        state: absent
      failed_when: false

    - name: Remove monitoring data directories
      ansible.builtin.file:
        path: "{{ item }}"
        state: absent
      loop:
        - /opt/prometheus
        - /opt/grafana
        - /opt/pve-exporter
```

- [ ] **Step 2: Dry-run teardown**

```bash
doppler run -- ansible-playbook teardown-monitoring.yml --check --diff
```

Expected: Shows containers/dirs to be removed. No errors.

- [ ] **Step 3: Apply teardown**

```bash
doppler run -- ansible-playbook teardown-monitoring.yml
```

- [ ] **Step 4: Verify containers gone**

```bash
ssh ansible@kaz.tlesh.xyz "docker ps -a --format '{{.Names}}' | grep -E 'prometheus|grafana|cadvisor|pve-exporter|dozzle|truenas|unpoller|pihole|plex-exporter'"
```

Expected: No output (all containers removed).

---

## Task 2: Purge Netdata from all servers

The Netdata role was installed via kickstart script on hosts. Netdata cron updater at `/etc/cron.daily/netdata-updater` is generating Pushover noise from bare-metal Proxmox hosts and possibly LXCs.

**Files:**
- Modify: `roles/netdata/tasks/main.yml` (overwrite with removal tasks)

- [ ] **Step 1: Overwrite roles/netdata/tasks/main.yml with removal tasks**

```yaml
---
- name: Stop Netdata service
  ansible.builtin.systemd:
    name: netdata
    state: stopped
    enabled: false
  failed_when: false
  become: true

- name: Run Netdata kickstart uninstaller if present
  ansible.builtin.shell:
    cmd: /usr/libexec/netdata/netdata-uninstaller.sh --yes --force 2>/dev/null || true
    executable: /bin/bash
  become: true
  changed_when: false

- name: Remove Netdata apt package if present
  ansible.builtin.apt:
    name:
      - netdata
      - netdata-core
      - netdata-plugins-bash
      - netdata-plugins-python
    state: absent
    purge: true
  failed_when: false
  become: true

- name: Remove Netdata cron updater
  ansible.builtin.file:
    path: /etc/cron.daily/netdata-updater
    state: absent
  become: true

- name: Remove Netdata config directory
  ansible.builtin.file:
    path: /etc/netdata
    state: absent
  become: true

- name: Remove Netdata data and lib directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: absent
  loop:
    - /var/lib/netdata
    - /var/cache/netdata
    - /var/log/netdata
    - /usr/libexec/netdata
    - /usr/share/netdata
  become: true

- name: Remove Netdata sudoers file
  ansible.builtin.file:
    path: /etc/sudoers.d/92-netdata-cert-refresh
    state: absent
  become: true

- name: Remove netdata system user
  ansible.builtin.user:
    name: netdata
    state: absent
    remove: true
  failed_when: false
  become: true
```

- [ ] **Step 2: Add temporary netdata removal play to main.yml**

Add this block just before the `EOF` / end of `main.yml`:

```yaml
- name: remove netdata from all hosts
  hosts: all:!truenas:!unifi
  gather_facts: true
  become: true
  roles:
    - role: netdata
```

- [ ] **Step 3: Dry-run Netdata removal against all hosts**

```bash
doppler run -- ansible-playbook main.yml --tags "" --limit "proxmox,lxc,kaz,barlo" -C
```

Expected: Shows removal tasks. `failed_when: false` means check mode won't error on missing services.

- [ ] **Step 4: Apply Netdata removal**

```bash
doppler run -- ansible-playbook main.yml --limit "proxmox,lxc,kaz,barlo" -e "ansible_play_hosts_all=proxmox,lxc,kaz,barlo"
```

Actually, since the play targets `all:!truenas:!unifi`, run it directly:

```bash
doppler run -- ansible-playbook main.yml --start-at-task "remove netdata from all hosts"
```

Or more cleanly, run the role standalone:

```bash
doppler run -- ansible-playbook -b main.yml --limit "tika.tlesh.xyz,bupu.tlesh.xyz,sturm.tlesh.xyz,tailscale.tlesh.xyz,plex.tlesh.xyz,pi-hole.tlesh.xyz,arr.tlesh.xyz,uptime-kuma.tlesh.xyz,caddy.tlesh.xyz,minecraft.tlesh.xyz,kaz.tlesh.xyz,barlo.tlesh.xyz"
```

- [ ] **Step 5: Verify Netdata gone from Proxmox hosts**

```bash
ssh ansible@tika.tlesh.xyz "systemctl status netdata 2>&1; ls /etc/cron.daily/netdata-updater 2>&1"
ssh ansible@bupu.tlesh.xyz "systemctl status netdata 2>&1; ls /etc/cron.daily/netdata-updater 2>&1"
ssh ansible@sturm.tlesh.xyz "systemctl status netdata 2>&1; ls /etc/cron.daily/netdata-updater 2>&1"
```

Expected: `Unit netdata.service could not be found`, `No such file or directory`.

---

## Task 3: Remove old roles and clean up inventory/playbook/Taskfile

**Files:**
- Delete: `roles/monitoring/`, `roles/node_exporter/`, `roles/netdata/`
- Modify: `main.yml`
- Modify: `hosts`
- Modify: `Taskfile.yml`

- [ ] **Step 1: Delete old roles**

```bash
rm -rf roles/monitoring roles/node_exporter roles/netdata
```

- [ ] **Step 2: Remove the three plays from main.yml**

Remove these three plays entirely:

```yaml
# Remove this play:
- name: deploy monitoring stack
  hosts: monitoring
  gather_facts: true
  become: true
  roles:
    - role: monitoring

# Remove this play:
- name: deploy node exporter to all hosts
  hosts: exporters
  gather_facts: true
  become: true
  roles:
    - role: node_exporter

# Remove the temporary netdata removal play added in Task 2
- name: remove netdata from all hosts
  hosts: all:!truenas:!unifi
  ...
```

- [ ] **Step 3: Remove old host groups from hosts inventory**

Remove these two group definitions from `hosts`:

```ini
# Remove:
[exporters:children]
proxmox
tailscale
plex
pi-hole
arr
uptime-kuma
caddy
minecraft
kaz
barlo

# Remove:
[monitoring:children]
kaz
```

- [ ] **Step 4: Remove monitoring task from Taskfile.yml**

Find and remove the `monitoring:` task block (lines ~185-215) from `Taskfile.yml`. It looks like:

```yaml
  monitoring:
    desc: Deploy Prometheus + Grafana monitoring stack
    ...
    vars: { ROLE: monitoring }
```

- [ ] **Step 5: Verify syntax still passes**

```bash
task syntax && task lint
```

Expected: Both pass with no references to removed roles/groups.

- [ ] **Step 6: Commit teardown**

```bash
rtk git add -A && rtk git commit -m "chore(monitoring): tear down Grafana/Prometheus/Netdata stack"
```

---

## Task 4: Create roles/beszel — defaults and structure

**Files:**
- Create: `roles/beszel/defaults/main.yml`
- Create: `roles/beszel/handlers/main.yml`
- Create: `roles/beszel/tasks/main.yml` (dispatcher)

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p roles/beszel/{defaults,handlers,tasks}
```

- [ ] **Step 2: Write roles/beszel/defaults/main.yml**

```yaml
---
beszel_version: "latest"
beszel_agent_version: "latest"
beszel_data_dir: /opt/beszel
beszel_hub_port: 8090
beszel_agent_port: 45876
```

- [ ] **Step 3: Write roles/beszel/handlers/main.yml**

```yaml
---
- name: Restart beszel-agent
  ansible.builtin.systemd:
    name: beszel-agent
    state: restarted
    daemon_reload: true
  become: true
```

- [ ] **Step 4: Write roles/beszel/tasks/main.yml (dispatcher)**

```yaml
---
- name: Install Docker Python SDK
  ansible.builtin.package:
    name: python3-docker
    state: present
  become: true
  when: inventory_hostname in groups['beszel_hub']

- name: Deploy Beszel hub
  ansible.builtin.include_tasks: hub.yml
  when: inventory_hostname in groups['beszel_hub']

- name: Deploy Beszel agent
  ansible.builtin.include_tasks: agent.yml
  when: inventory_hostname in groups['beszel_agents']
```

---

## Task 5: Create roles/beszel/tasks/hub.yml

**Files:**
- Create: `roles/beszel/tasks/hub.yml`

- [ ] **Step 1: Write hub.yml**

```yaml
---
- name: Create Beszel data directory
  ansible.builtin.file:
    path: "{{ beszel_data_dir }}"
    state: directory
    mode: "0755"
    owner: root
    group: root
  become: true

- name: Deploy Beszel hub container
  community.docker.docker_container:
    name: beszel
    image: "henrygd/beszel:{{ beszel_version }}"
    state: started
    restart_policy: unless-stopped
    pull: true
    ports:
      - "{{ beszel_hub_port }}:8090"
    volumes:
      - "{{ beszel_data_dir }}:/beszel_data"
    env:
      APP_URL: "http://kaz.tlesh.xyz:{{ beszel_hub_port | string }}"
  become: true

- name: Deploy Beszel agent container on hub host (for Docker stats)
  community.docker.docker_container:
    name: beszel-agent
    image: "henrygd/beszel-agent:{{ beszel_agent_version }}"
    state: started
    restart_policy: unless-stopped
    pull: true
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    env:
      KEY: "{{ lookup('env', 'BESZEL_KEY') }}"
      TOKEN: "{{ lookup('env', 'BESZEL_TOKEN') }}"
      HUB_URL: "http://127.0.0.1:{{ beszel_hub_port | string }}"
      PORT: "{{ beszel_agent_port | string }}"
  become: true
  when:
    - lookup('env', 'BESZEL_KEY') | length > 0
    - lookup('env', 'BESZEL_TOKEN') | length > 0
  no_log: true
```

> **Note:** The `beszel-agent` container on kaz is gated on credentials being present. On first deploy (Task 6), skip agents — run hub only. After the manual bootstrap step (Task 8) sets BESZEL_KEY and BESZEL_TOKEN in Doppler, re-run to deploy the agents.

---

## Task 6: Create roles/beszel/tasks/agent.yml

The binary agent works on all Debian/Ubuntu LXCs and Proxmox bare-metal hosts (no Docker required).

**Files:**
- Create: `roles/beszel/tasks/agent.yml`

- [ ] **Step 1: Write agent.yml**

```yaml
---
- name: Get system architecture for beszel-agent
  ansible.builtin.set_fact:
    _beszel_arch: >-
      {{ 'arm64' if ansible_architecture == 'aarch64' else 'amd64' }}

- name: Download beszel-agent binary
  ansible.builtin.get_url:
    url: "https://github.com/henrygd/beszel/releases/latest/download/beszel-agent_linux_{{ _beszel_arch }}.tar.gz"
    dest: /tmp/beszel-agent.tar.gz
    mode: "0644"
  become: true

- name: Extract beszel-agent binary
  ansible.builtin.unarchive:
    src: /tmp/beszel-agent.tar.gz
    dest: /usr/local/bin/
    remote_src: true
    include:
      - beszel-agent
    mode: "0755"
  become: true
  notify: Restart beszel-agent

- name: Create beszel-agent systemd unit
  ansible.builtin.copy:
    dest: /etc/systemd/system/beszel-agent.service
    mode: "0644"
    content: |
      [Unit]
      Description=Beszel Agent
      After=network.target

      [Service]
      Type=simple
      Restart=always
      RestartSec=5
      Environment=KEY={{ lookup('env', 'BESZEL_KEY') }}
      Environment=TOKEN={{ lookup('env', 'BESZEL_TOKEN') }}
      Environment=HUB_URL=http://kaz.tlesh.xyz:8090
      Environment=PORT={{ beszel_agent_port }}
      ExecStart=/usr/local/bin/beszel-agent

      [Install]
      WantedBy=multi-user.target
  become: true
  no_log: true
  notify: Restart beszel-agent
  when:
    - lookup('env', 'BESZEL_KEY') | length > 0
    - lookup('env', 'BESZEL_TOKEN') | length > 0

- name: Enable and start beszel-agent
  ansible.builtin.systemd:
    name: beszel-agent
    state: started
    enabled: true
    daemon_reload: true
  become: true
  when:
    - lookup('env', 'BESZEL_KEY') | length > 0
    - lookup('env', 'BESZEL_TOKEN') | length > 0
```

---

## Task 7: Wire Beszel into main.yml, hosts, and Taskfile

**Files:**
- Modify: `hosts`
- Modify: `main.yml`
- Modify: `Taskfile.yml`

- [ ] **Step 1: Add Beszel groups to hosts inventory**

Add at the end of `hosts`:

```ini
[beszel_hub:children]
kaz

[beszel_agents:children]
proxmox
lxc
kaz
barlo
```

- [ ] **Step 2: Add Beszel play to main.yml**

Add after the kaz/glance/n8n plays (before truenas play):

```yaml
- name: deploy beszel monitoring
  hosts: beszel_hub:beszel_agents
  gather_facts: true
  become: true
  roles:
    - role: beszel
```

- [ ] **Step 3: Add beszel task to Taskfile.yml**

Add alongside other deploy tasks:

```yaml
  beszel:
    desc: Deploy Beszel monitoring hub and agents
    cmds:
      - task: deploy
        vars: { ROLE: beszel, LIMIT: "beszel_hub,beszel_agents" }
```

- [ ] **Step 4: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: Both pass cleanly.

- [ ] **Step 5: Add Uptime Kuma monitor entry to docs**

Add to `docs/runbooks/` or a comment in defaults — Beszel hub at `http://kaz.tlesh.xyz:8090` should be monitored via Uptime Kuma (add manually in UI per the new service checklist).

- [ ] **Step 6: Commit role and wiring**

```bash
rtk git add roles/beszel main.yml hosts Taskfile.yml
rtk git commit -m "feat(beszel): add Beszel monitoring role and wiring"
```

---

## Task 8: First deploy — hub only (no credentials yet)

- [ ] **Step 1: Deploy hub only (agents gated on missing credentials)**

```bash
doppler run -- ansible-playbook main.yml --limit kaz --tags ""
```

Or via task:

```bash
task beszel -- --limit kaz
```

The agent tasks will be skipped because `BESZEL_KEY` and `BESZEL_TOKEN` are not yet in Doppler.

- [ ] **Step 2: Verify hub container running**

```bash
ssh ansible@kaz.tlesh.xyz "docker ps --filter name=beszel --format '{{.Names}}\t{{.Status}}'"
```

Expected: `beszel    Up X seconds`

---

## Task 9: Manual bootstrap — get credentials from Beszel UI

> This task is **manual** and cannot be automated. Complete it before deploying agents.

- [ ] **Step 1: Open Beszel UI**

Navigate to `http://kaz.tlesh.xyz:8090` (or via Tailscale if not on LAN).

- [ ] **Step 2: Create admin account**

On first visit, Beszel prompts for an admin email + password. Set these up.

- [ ] **Step 3: Get the hub public KEY**

Click **"Add System"** → The dialog shows a public key labeled "Key". Copy it — this is the same `BESZEL_KEY` used by all agents.

- [ ] **Step 4: Create an API token**

Go to **Settings → API Tokens** → Create a new token. Copy the value — this is `BESZEL_TOKEN`.

- [ ] **Step 5: Store in Doppler**

```bash
doppler secrets set BESZEL_KEY="<paste key here>"
doppler secrets set BESZEL_TOKEN="<paste token here>"
```

---

## Task 10: Deploy agents to all hosts

- [ ] **Step 1: Deploy full beszel role (hub + agents)**

```bash
task beszel
```

This runs against `beszel_hub,beszel_agents`. Now that `BESZEL_KEY` and `BESZEL_TOKEN` are in Doppler, all agent tasks will execute.

- [ ] **Step 2: Verify agents appear in Beszel UI**

Open `http://kaz.tlesh.xyz:8090`. Verify these systems appear and show metrics:
- kaz
- tika, bupu, sturm (Proxmox bare-metal)
- tailscale, plex, pi-hole, arr, uptime-kuma, caddy, minecraft (LXCs)
- barlo

- [ ] **Step 3: Verify each host's agent status via SSH**

```bash
for h in tika.tlesh.xyz bupu.tlesh.xyz sturm.tlesh.xyz plex.tlesh.xyz pi-hole.tlesh.xyz; do
  echo "=== $h ==="; ssh ansible@$h "systemctl is-active beszel-agent"
done
```

Expected: `active` for each host.

---

## Task 11: Clean up Doppler secrets

Remove secrets that were exclusively used by the old monitoring stack. **Verify each before deleting** — some may be shared.

- [ ] **Step 1: Verify PVE credentials are only used by pve-exporter**

```bash
grep -rn "PVE_USER\|PVE_PASS\|PVE_PASSWORD" roles/ group_vars/ host_vars/ Taskfile.yml
```

If no results → safe to delete from Doppler. If results → keep.

- [ ] **Step 2: Verify PIHOLE_PASSWORD is only used by pihole-exporter**

```bash
grep -rn "PIHOLE_PASSWORD" roles/ group_vars/ host_vars/
```

If only in the now-deleted monitoring role → delete from Doppler.

- [ ] **Step 3: Delete confirmed monitoring-only secrets from Doppler**

Secrets confirmed safe to remove (verified monitoring-only):

```bash
doppler secrets delete GRAFANA_ADMIN_PASSWORD
doppler secrets delete NETDATA_STREAM_API_KEY
doppler secrets delete TRUENAS_PROM_KEY
doppler secrets delete UP_PROMETHEUS_HTTP_LISTEN
doppler secrets delete UP_UNIFI_DEFAULT_PASS
doppler secrets delete UP_UNIFI_DEFAULT_SAVE_ALARMS
doppler secrets delete UP_UNIFI_DEFAULT_SAVE_EVENTS
doppler secrets delete UP_UNIFI_DEFAULT_SAVE_IDS
doppler secrets delete UP_UNIFI_DEFAULT_SAVE_SITES
doppler secrets delete UP_UNIFI_DEFAULT_URL
doppler secrets delete UP_UNIFI_DEFAULT_USER
```

Secrets to verify before deleting:
- `PIHOLE_PASSWORD` — check if pi-hole role uses it for anything other than exporter
- `TRUENAS_API_KEY` — **keep**: used by TrueNAS role for management tasks
- `UNIFI_CONTROLLER_URL`, `UNIFI_RO_USERNAME`, `UNIFI_RO_PASSWORD` — check if unifly CLI uses them
- `PLEX_TOKEN` — **keep**: used by plex server role

- [ ] **Step 4: Delete teardown-monitoring.yml**

```bash
rm teardown-monitoring.yml
rtk git add -A && rtk git commit -m "chore(monitoring): clean up Doppler secrets and teardown playbook"
```

---

## Task 12: Post-deploy checklist and PR

- [ ] **Step 1: Add Beszel to Glance dashboard**

In the Glance role/config, add a widget pointing to `http://kaz.tlesh.xyz:8090` (or use Tailscale hostname). This is the "New Service Checklist" requirement from CLAUDE.md.

- [ ] **Step 2: Add Beszel to Uptime Kuma**

In Uptime Kuma UI, add an HTTP monitor for `http://kaz.tlesh.xyz:8090`. Alert on down.

- [ ] **Step 3: Close the beads tracking issue**

```bash
bd close <issue-id-from-step-0>
```

- [ ] **Step 4: Run preflight checks**

```bash
task syntax && task lint
```

- [ ] **Step 5: Ship PR**

```bash
# Use /ship skill to create the PR
```

---

## Self-Review

**Spec coverage:**
- ✓ Remove Grafana + Prometheus + exporters (Tasks 1, 3)
- ✓ Remove Netdata artifacts (Task 2)
- ✓ Remove no-longer-needed Doppler secrets (Task 11)
- ✓ Deploy Beszel hub on kaz (Tasks 4-5, 8)
- ✓ Deploy Beszel agents on all hosts (Tasks 6, 10)
- ✓ Uptime Kuma + Glance for new service (Task 12)
- ✓ Beads tracking throughout

**Key dependency:** Tasks 9 and 10 require the hub to be running first. Tasks 5-7 (credential-gated tasks) will silently skip until Task 9 completes — this is intentional and safe.

**UNIFI vars note:** `UNIFI_CONTROLLER_URL`, `UNIFI_RO_USERNAME`, `UNIFI_RO_PASSWORD` were added for UnPoller. The `unifly` CLI uses its own auth (2FA-based, stored differently). These three are likely safe to delete but verify via `grep -rn UNIFI roles/` after the monitoring role is gone.
