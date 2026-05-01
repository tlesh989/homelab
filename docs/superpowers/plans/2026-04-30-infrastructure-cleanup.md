# Infrastructure Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Seerr to Caddy reverse proxy, remove stale Grafana dashboard, add cAdvisor and Proxmox PVE exporter dashboards, and configure Grafana alerting with Pushover notifications.

**Architecture:** All changes are Ansible role modifications on existing infrastructure. No new hosts or containers beyond cAdvisor and pve-exporter (both on kaz). Grafana alerting uses native Grafana Alerting (not Alertmanager) provisioned as files via Ansible.

**Tech Stack:** Ansible, Docker (community.docker), Prometheus v3, Grafana 13, Caddy, Pi-hole

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `roles/caddy/defaults/main.yml` | Modify | Add seerr to caddy_services |
| `roles/pi-hole/defaults/main.yml` | Modify | Add seerr.tlesh.xyz DNS record |
| `roles/glance/templates/glance.yml.j2` | Modify | Update Seerr URL to HTTPS subdomain |
| `roles/monitoring/defaults/main.yml` | Modify | Add cadvisor/pve-exporter/alerting defaults |
| `roles/monitoring/tasks/main.yml` | Modify | Add container tasks, cleanup, alerting provisioning |
| `roles/monitoring/templates/prometheus.yml.j2` | Modify | Add cadvisor + pve scrape jobs |
| `roles/monitoring/templates/pve-exporter.yml.j2` | Create | pve-exporter credentials config |
| `roles/monitoring/files/dashboards/scraparr-dashboard.json` | Delete | Stale exporter removed |
| `roles/monitoring/files/dashboards/cadvisor-dashboard.json` | Create | cAdvisor community dashboard |
| `roles/monitoring/files/dashboards/proxmox-dashboard.json` | Create | Proxmox PVE community dashboard |
| `roles/monitoring/files/alerting/contact-points.yaml` | Create | Pushover contact point |
| `roles/monitoring/files/alerting/rules.yaml` | Create | Alert rules (disk, host-down, memory) |

---

## Task 1: Add Seerr to Caddy + Pi-hole + Glance

**Files:**
- Modify: `roles/caddy/defaults/main.yml`
- Modify: `roles/pi-hole/defaults/main.yml`
- Modify: `roles/glance/templates/glance.yml.j2` (line ~240)

- [ ] **Step 1: Add seerr to caddy_services**

In `roles/caddy/defaults/main.yml`, append to the `caddy_services` list (after the `freshrss` entry):

```yaml
  - name: seerr
    upstream: "192.168.233.24:5055"
```

- [ ] **Step 2: Add seerr DNS record to Pi-hole**

In `roles/pi-hole/defaults/main.yml`, append to `pihole_local_hosts` (after `freshrss.tlesh.xyz`):

```yaml
  - "192.168.233.17 seerr.tlesh.xyz"
```

- [ ] **Step 3: Update Glance Seerr URL to HTTPS subdomain**

In `roles/glance/templates/glance.yml.j2`, find the Seerr entry (currently uses direct HTTP to arr IP):

```yaml
              - title: Seerr
                url: http://{{ hostvars['arr.tlesh.xyz'].ansible_host }}:5055
                icon: si:seerr
```

Replace with:

```yaml
              - title: Seerr
                url: https://seerr.tlesh.xyz
                icon: si:seerr
```

- [ ] **Step 4: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add roles/caddy/defaults/main.yml roles/pi-hole/defaults/main.yml roles/glance/templates/glance.yml.j2
git commit -m "feat: add Seerr to Caddy reverse proxy and Pi-hole DNS"
```

---

## Task 2: Remove Stale Scraparr Dashboard

**Files:**
- Modify: `roles/monitoring/tasks/main.yml`
- Delete: `roles/monitoring/files/dashboards/scraparr-dashboard.json`

- [ ] **Step 1: Remove scraparr-dashboard.json from the dashboard copy loop**

In `roles/monitoring/tasks/main.yml`, find the "Copy dashboard JSON files" task:

```yaml
- name: Copy dashboard JSON files
  ansible.builtin.copy:
    src: "dashboards/{{ item }}"
    dest: "{{ grafana_dashboards_dir }}/{{ item }}"
    owner: "472"
    group: "472"
    mode: "0644"
  loop:
    - node-exporter-full.json
    - scraparr-dashboard.json
  become: true
  notify: Restart Grafana
```

Update the loop to remove `scraparr-dashboard.json`:

```yaml
- name: Copy dashboard JSON files
  ansible.builtin.copy:
    src: "dashboards/{{ item }}"
    dest: "{{ grafana_dashboards_dir }}/{{ item }}"
    owner: "472"
    group: "472"
    mode: "0644"
  loop:
    - node-exporter-full.json
  become: true
  notify: Restart Grafana
```

- [ ] **Step 2: Add task to remove stale scraparr dashboard from host**

Directly after the dashboard copy task, add:

```yaml
- name: Remove stale scraparr dashboard
  ansible.builtin.file:
    path: "{{ grafana_dashboards_dir }}/scraparr-dashboard.json"
    state: absent
  become: true
  notify: Restart Grafana
```

- [ ] **Step 3: Delete the source file from the role**

```bash
rm roles/monitoring/files/dashboards/scraparr-dashboard.json
```

- [ ] **Step 4: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add roles/monitoring/tasks/main.yml
git rm roles/monitoring/files/dashboards/scraparr-dashboard.json
git commit -m "chore: remove stale scraparr Grafana dashboard"
```

---

## Task 3: Add cAdvisor Container + Dashboard

**Files:**
- Modify: `roles/monitoring/defaults/main.yml`
- Modify: `roles/monitoring/tasks/main.yml`
- Modify: `roles/monitoring/templates/prometheus.yml.j2`
- Create: `roles/monitoring/files/dashboards/cadvisor-dashboard.json`

- [ ] **Step 1: Add cAdvisor defaults**

In `roles/monitoring/defaults/main.yml`, append:

```yaml
cadvisor_version: "v0.51"
cadvisor_port: 8083
```

- [ ] **Step 2: Add cAdvisor container task**

In `roles/monitoring/tasks/main.yml`, after the Grafana container task, add:

```yaml
- name: Deploy cAdvisor container
  community.docker.docker_container:
    name: cadvisor
    image: "gcr.io/cadvisor/cadvisor:{{ cadvisor_version }}"
    state: started
    restart_policy: always
    ports:
      - "{{ cadvisor_port | string }}:8080"
    volumes:
      - "/:/rootfs:ro"
      - "/var/run:/var/run:ro"
      - "/sys:/sys:ro"
      - "/var/lib/docker:/var/lib/docker:ro"
      - "/dev/disk:/dev/disk:ro"
    devices:
      - "/dev/kmsg"
    privileged: true
  become: true
  when: not ansible_check_mode
```

- [ ] **Step 3: Add cAdvisor scrape job to Prometheus**

In `roles/monitoring/templates/prometheus.yml.j2`, append after the scraparr job block:

```yaml
  - job_name: cadvisor
    static_configs:
      - targets:
          - "{{ hostvars['kaz.tlesh.xyz']['ansible_host'] }}:{{ cadvisor_port }}"
```

- [ ] **Step 4: Download cAdvisor community dashboard**

```bash
curl -sL "https://grafana.com/api/dashboards/14282/revisions/latest/download" \
  -o roles/monitoring/files/dashboards/cadvisor-dashboard.json
```

Expected: JSON file created (~50KB). Verify it starts with `{`.

- [ ] **Step 5: Add cadvisor-dashboard.json to the copy loop**

In `roles/monitoring/tasks/main.yml`, update the dashboard copy loop:

```yaml
  loop:
    - node-exporter-full.json
    - cadvisor-dashboard.json
```

- [ ] **Step 6: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add roles/monitoring/defaults/main.yml \
        roles/monitoring/tasks/main.yml \
        roles/monitoring/templates/prometheus.yml.j2 \
        roles/monitoring/files/dashboards/cadvisor-dashboard.json
git commit -m "feat: add cAdvisor container metrics and Grafana dashboard"
```

---

## Task 4: Add Proxmox PVE Exporter + Dashboard

**Files:**
- Modify: `roles/monitoring/defaults/main.yml`
- Create: `roles/monitoring/templates/pve-exporter.yml.j2`
- Modify: `roles/monitoring/tasks/main.yml`
- Modify: `roles/monitoring/templates/prometheus.yml.j2`
- Create: `roles/monitoring/files/dashboards/proxmox-dashboard.json`

- [ ] **Step 1: Add pve-exporter defaults**

In `roles/monitoring/defaults/main.yml`, append:

```yaml
pve_exporter_version: "3"
pve_exporter_port: 9221
pve_exporter_config_dir: /opt/pve-exporter
pve_exporter_host: "192.168.233.7"  # tika — primary Proxmox node
```

- [ ] **Step 2: Create pve-exporter credentials template**

Create `roles/monitoring/templates/pve-exporter.yml.j2`:

```yaml
default:
  user: "{{ lookup('env', 'PVE_TOKEN_ID') }}"
  token_name: "pve-exporter"
  token_value: "{{ lookup('env', 'PVE_TOKEN_SECRET') }}"
  verify_ssl: false
```

Note: Before running the playbook, create a Proxmox API token:
1. In Proxmox UI → Datacenter → Permissions → API Tokens → Add
2. User: `root@pam`, Token ID: `pve-exporter`, uncheck "Privilege Separation"
3. Store token ID as `PVE_TOKEN_ID` and secret as `PVE_TOKEN_SECRET` in Doppler

- [ ] **Step 3: Add pve-exporter tasks**

In `roles/monitoring/tasks/main.yml`, after the cAdvisor task, add:

```yaml
- name: Create pve-exporter config directory
  ansible.builtin.file:
    path: "{{ pve_exporter_config_dir }}"
    state: directory
    owner: "1000"
    group: "1000"
    mode: "0755"
  become: true

- name: Template pve-exporter credentials config
  ansible.builtin.template:
    src: pve-exporter.yml.j2
    dest: "{{ pve_exporter_config_dir }}/pve.yml"
    owner: "1000"
    group: "1000"
    mode: "0600"
  become: true

- name: Deploy pve-exporter container
  community.docker.docker_container:
    name: pve-exporter
    image: "prompve/prometheus-pve-exporter:{{ pve_exporter_version }}"
    state: started
    restart_policy: always
    ports:
      - "{{ pve_exporter_port | string }}:9221"
    volumes:
      - "{{ pve_exporter_config_dir }}/pve.yml:/etc/pve.yml:ro"
  become: true
  when: not ansible_check_mode
```

- [ ] **Step 4: Add pve scrape job to Prometheus**

In `roles/monitoring/templates/prometheus.yml.j2`, append after the cAdvisor job:

```yaml
  - job_name: pve
    static_configs:
      - targets:
          - "{{ hostvars['kaz.tlesh.xyz']['ansible_host'] }}:{{ pve_exporter_port }}"
    metrics_path: /pve
    params:
      module: [default]
      cluster: ['1']
      node: ['1']
```

- [ ] **Step 5: Download Proxmox PVE community dashboard**

```bash
curl -sL "https://grafana.com/api/dashboards/10347/revisions/latest/download" \
  -o roles/monitoring/files/dashboards/proxmox-dashboard.json
```

Expected: JSON file created. Verify it starts with `{`.

- [ ] **Step 6: Add proxmox-dashboard.json to the copy loop**

In `roles/monitoring/tasks/main.yml`, update the dashboard copy loop:

```yaml
  loop:
    - node-exporter-full.json
    - cadvisor-dashboard.json
    - proxmox-dashboard.json
```

- [ ] **Step 7: Add PVE Doppler secrets note**

Ensure Doppler project has these secrets set before running the playbook:
- `PVE_TOKEN_ID` — format: `root@pam!pve-exporter`
- `PVE_TOKEN_SECRET` — the UUID shown once when creating the token

- [ ] **Step 8: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add roles/monitoring/defaults/main.yml \
        roles/monitoring/tasks/main.yml \
        roles/monitoring/templates/prometheus.yml.j2 \
        roles/monitoring/templates/pve-exporter.yml.j2 \
        roles/monitoring/files/dashboards/proxmox-dashboard.json
git commit -m "feat: add Proxmox PVE exporter and Grafana dashboard"
```

---

## Task 5: Grafana Alerting with Pushover

**Files:**
- Modify: `roles/monitoring/defaults/main.yml`
- Modify: `roles/monitoring/tasks/main.yml`
- Create: `roles/monitoring/files/alerting/contact-points.yaml`
- Create: `roles/monitoring/files/alerting/rules.yaml`

- [ ] **Step 1: Add alerting defaults**

In `roles/monitoring/defaults/main.yml`, append:

```yaml
grafana_alerting_dir: /opt/grafana/provisioning/alerting
```

- [ ] **Step 2: Create alerting provisioning directory task**

In `roles/monitoring/tasks/main.yml`, find the "Create Grafana directories" task and add `"{{ grafana_alerting_dir }}"` to its loop:

```yaml
- name: Create Grafana directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "472"
    group: "472"
    mode: "0755"
  loop:
    - "{{ grafana_data_dir }}"
    - "{{ grafana_provisioning_dir }}/datasources"
    - "{{ grafana_dashboards_dir }}"
    - "{{ grafana_alerting_dir }}"
  become: true
```

- [ ] **Step 3: Add alerting volume mount to Grafana container**

In `roles/monitoring/tasks/main.yml`, find the Grafana container task volumes section and add the alerting mount:

```yaml
    volumes:
      - "{{ grafana_data_dir }}:/var/lib/grafana"
      - "{{ grafana_provisioning_dir }}/datasources:/etc/grafana/provisioning/datasources:ro"
      - "{{ grafana_dashboards_dir }}:/etc/grafana/provisioning/dashboards:ro"
      - "{{ grafana_alerting_dir }}:/etc/grafana/provisioning/alerting:ro"
```

- [ ] **Step 4: Add alerting file copy tasks**

In `roles/monitoring/tasks/main.yml`, after the "Remove stale scraparr dashboard" task, add:

```yaml
- name: Copy Grafana alerting provisioning files
  ansible.builtin.copy:
    src: "alerting/{{ item }}"
    dest: "{{ grafana_alerting_dir }}/{{ item }}"
    owner: "472"
    group: "472"
    mode: "0644"
  loop:
    - contact-points.yaml
    - rules.yaml
  become: true
  notify: Restart Grafana
```

- [ ] **Step 5: Create Pushover contact point**

Create `roles/monitoring/files/alerting/contact-points.yaml`:

```yaml
apiVersion: 1

contactPoints:
  - orgId: 1
    name: Pushover
    receivers:
      - uid: pushover-main
        type: pushover
        settings:
          apiToken: $PUSHOVER_APP_TOKEN
          userKey: $PUSHOVER_USER_KEY
          priority: 0
          okPriority: -2
        disableResolveMessage: false
```

Note: Grafana reads `$PUSHOVER_APP_TOKEN` and `$PUSHOVER_USER_KEY` from the container environment. Add these as env vars in the Grafana container task (see Step 6).

- [ ] **Step 6: Add Pushover env vars to Grafana container**

In `roles/monitoring/tasks/main.yml`, in the Grafana container task, add an `env:` section:

```yaml
- name: Deploy Grafana container
  community.docker.docker_container:
    name: grafana
    image: "grafana/grafana:{{ grafana_version }}"
    state: started
    restart_policy: always
    networks:
      - name: "{{ monitoring_network }}"
    ports:
      - "{{ grafana_port | string }}:3000"
    volumes:
      - "{{ grafana_data_dir }}:/var/lib/grafana"
      - "{{ grafana_provisioning_dir }}/datasources:/etc/grafana/provisioning/datasources:ro"
      - "{{ grafana_dashboards_dir }}:/etc/grafana/provisioning/dashboards:ro"
      - "{{ grafana_alerting_dir }}:/etc/grafana/provisioning/alerting:ro"
    env:
      PUSHOVER_APP_TOKEN: "{{ lookup('env', 'PUSHOVER_APP_TOKEN') }}"
      PUSHOVER_USER_KEY: "{{ lookup('env', 'PUSHOVER_USER_KEY') }}"
  become: true
  when: not ansible_check_mode
```

- [ ] **Step 7: Create alert rules**

Create `roles/monitoring/files/alerting/rules.yaml`:

```yaml
apiVersion: 1

groups:
  - orgId: 1
    name: infrastructure
    folder: Infrastructure
    interval: 1m
    rules:
      - uid: host-disk-full
        title: Host Disk Full
        condition: C
        data:
          - refId: A
            datasourceUid: prometheus
            model:
              expr: '(node_filesystem_avail_bytes{fstype!="tmpfs",mountpoint="/"} / node_filesystem_size_bytes{fstype!="tmpfs",mountpoint="/"}) * 100'
              intervalMs: 1000
              maxDataPoints: 43200
              refId: A
          - refId: C
            datasourceUid: __expr__
            model:
              conditions:
                - evaluator:
                    params:
                      - 15
                    type: lt
                  operator:
                    type: and
                  query:
                    params:
                      - A
                  reducer:
                    type: last
              refId: C
              type: classic_conditions
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk below 15% on {{ $labels.instance }}"
        noDataState: NoData
        execErrState: Error
        isPaused: false
        notification_settings:
          receiver: Pushover

      - uid: host-down
        title: Host Down
        condition: C
        data:
          - refId: A
            datasourceUid: prometheus
            model:
              expr: 'up{job="node"}'
              intervalMs: 1000
              maxDataPoints: 43200
              refId: A
          - refId: C
            datasourceUid: __expr__
            model:
              conditions:
                - evaluator:
                    params:
                      - 1
                    type: lt
                  operator:
                    type: and
                  query:
                    params:
                      - A
                  reducer:
                    type: last
              refId: C
              type: classic_conditions
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Host {{ $labels.instance }} is unreachable"
        noDataState: Alerting
        execErrState: Error
        isPaused: false
        notification_settings:
          receiver: Pushover

      - uid: high-memory-pressure
        title: High Memory Pressure
        condition: C
        data:
          - refId: A
            datasourceUid: prometheus
            model:
              expr: '(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100'
              intervalMs: 1000
              maxDataPoints: 43200
              refId: A
          - refId: C
            datasourceUid: __expr__
            model:
              conditions:
                - evaluator:
                    params:
                      - 10
                    type: lt
                  operator:
                    type: and
                  query:
                    params:
                      - A
                  reducer:
                    type: last
              refId: C
              type: classic_conditions
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Memory below 10% available on {{ $labels.instance }}"
        noDataState: NoData
        execErrState: Error
        isPaused: false
        notification_settings:
          receiver: Pushover
```

Note: `datasourceUid: prometheus` assumes the Prometheus datasource UID is `prometheus`. Verify after first deploy: Grafana UI → Connections → Data Sources → Prometheus → copy the UID. If different, update this file and re-run the playbook.

- [ ] **Step 8: Ensure Doppler has Pushover secrets**

Verify these exist in Doppler before running:
- `PUSHOVER_APP_TOKEN` — from pushover.net app settings
- `PUSHOVER_USER_KEY` — from pushover.net user settings (already used by cloudflare_ddns role)

- [ ] **Step 9: Verify syntax and lint**

```bash
task syntax && task lint
```

Expected: no errors.

- [ ] **Step 10: Commit**

```bash
mkdir -p roles/monitoring/files/alerting
git add roles/monitoring/defaults/main.yml \
        roles/monitoring/tasks/main.yml \
        roles/monitoring/files/alerting/contact-points.yaml \
        roles/monitoring/files/alerting/rules.yaml
git commit -m "feat: add Grafana alerting with Pushover for disk, host-down, and memory"
```

---

## Final Steps

- [ ] **Run CodeRabbit review**

```bash
coderabbit review --plain --base main
```

Fix any issues found before opening the PR.

- [ ] **Open PR**

```bash
git push -u origin HEAD
gh pr create --title "feat: infrastructure cleanup — Seerr, Grafana dashboards, alerting" \
  --body "Adds Seerr to Caddy/DNS, removes stale scraparr dashboard, adds cAdvisor and Proxmox PVE dashboards, configures Grafana alerting with Pushover notifications."
```

- [ ] **Deploy and verify**

```bash
doppler run -- ansible-playbook main.yml --limit caddy,pi-hole,kaz --tags caddy,pi-hole,monitoring
```

Verify:
- `https://seerr.tlesh.xyz` loads Seerr UI
- Grafana → Dashboards shows "cAdvisor" and "Proxmox" dashboards with data
- Grafana → Alerting → Contact Points shows "Pushover" entry
- Grafana → Alerting → Alert Rules shows 3 rules in "Infrastructure" folder
- Trigger test: Grafana → Alerting → Contact Points → Pushover → Test (Pushover notification received)
