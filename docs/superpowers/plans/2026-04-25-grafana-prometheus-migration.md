# Grafana + Prometheus Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Netdata with Prometheus + Grafana on kaz, deploy node_exporter across all hosts, and decommission the Netdata LXC on sturm.

**Architecture:** Prometheus and Grafana run as Docker containers on kaz (.10) following the existing community.docker.docker_container pattern. node_exporter runs as a systemd service (apt package) on all Proxmox nodes and LXC containers. exportarr runs as Docker containers on the arr LXC (.24) to expose Sonarr/Radarr/Lidarr metrics. Decommission is a separate Phase 2 PR after coverage is verified.

**Tech Stack:** Ansible, community.docker.docker_container, prometheus-node-exporter (apt), prom/prometheus:v3 Docker image, grafana/grafana:11 Docker image, ghcr.io/onedr0p/exportarr:v2 Docker image.

---

## Prerequisites (manual — do before starting)

Add these secrets to Doppler (main config):

- `GRAFANA_ADMIN_PASSWORD` — choose a strong password for the Grafana admin user
- `SONARR_API_KEY` — find in Sonarr UI: Settings → General → API Key
- `RADARR_API_KEY` — find in Radarr UI: Settings → General → API Key
- `LIDARR_API_KEY` — find in Lidarr UI: Settings → General → API Key

---

## File Map

**New files:**
```
inventory/hosts                              (modify — add exporters + monitoring groups)
roles/monitoring/defaults/main.yml
roles/monitoring/tasks/main.yml
roles/monitoring/templates/prometheus.yml.j2
roles/monitoring/templates/grafana-datasource.yml.j2
roles/monitoring/templates/grafana-dashboards-provider.yml.j2
roles/monitoring/files/dashboards/node-exporter-full.json
roles/monitoring/files/dashboards/exportarr-sonarr.json
roles/monitoring/files/dashboards/exportarr-radarr.json
roles/monitoring/files/dashboards/exportarr-lidarr.json
roles/node_exporter/defaults/main.yml
roles/node_exporter/tasks/main.yml
roles/exportarr/defaults/main.yml
roles/exportarr/tasks/main.yml
```

**Modified files:**
```
inventory/hosts                              (add exporters + monitoring groups)
main.yml                                     (add node_exporter, monitoring, exportarr plays)
Taskfile.yml                                 (add monitoring task)
roles/caddy/defaults/main.yml               (add grafana site)
roles/pi-hole/defaults/main.yml             (add grafana DNS entry)
```

---

## Task 1: Add inventory groups

**Files:**
- Modify: `inventory/hosts`

- [ ] **Step 1: Add exporters and monitoring groups to inventory**

Append to the bottom of `inventory/hosts`:

```ini
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

[monitoring:children]
kaz
```

- [ ] **Step 2: Verify groups resolve correctly**

```bash
doppler run -- ansible-inventory --list -i inventory/hosts | python3 -c "
import json, sys
inv = json.load(sys.stdin)
print('exporters:', sorted(inv.get('exporters', {}).get('hosts', []) + [h for g in inv.get('exporters', {}).get('children', []) for h in inv.get(g, {}).get('hosts', [])]))
print('monitoring:', inv.get('monitoring', {}).get('children', []))
"
```

Expected: exporters lists tika, bupu, sturm, tailscale, plex, pi-hole, arr, uptime-kuma, caddy, minecraft, kaz. monitoring lists kaz.

- [ ] **Step 3: Commit**

```bash
rtk git add inventory/hosts
rtk git commit -m "feat: add exporters and monitoring inventory groups"
```

---

## Task 2: Create node_exporter role

**Files:**
- Create: `roles/node_exporter/defaults/main.yml`
- Create: `roles/node_exporter/tasks/main.yml`

- [ ] **Step 1: Create defaults**

`roles/node_exporter/defaults/main.yml`:

```yaml
---
node_exporter_port: 9100
```

- [ ] **Step 2: Create tasks**

`roles/node_exporter/tasks/main.yml`:

```yaml
---
- name: Install node exporter
  ansible.builtin.package:
    name: prometheus-node-exporter
    state: present
  become: true

- name: Enable and start node exporter
  ansible.builtin.systemd:
    name: prometheus-node-exporter
    enabled: true
    state: started
  become: true
  ignore_errors: "{{ ansible_check_mode }}"
```

- [ ] **Step 3: Validate**

```bash
task syntax && task lint
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 4: Commit**

```bash
rtk git add roles/node_exporter/
rtk git commit -m "feat: add node_exporter role"
```

---

## Task 3: Wire node_exporter into main.yml and deploy

**Files:**
- Modify: `main.yml`
- Modify: `Taskfile.yml`

- [ ] **Step 1: Add node_exporter play to main.yml**

Add after the last play in `main.yml` (after the `configure unifi` play):

```yaml
- name: deploy node exporter to all hosts
  hosts: exporters
  gather_facts: true
  roles:
    - role: node_exporter
```

- [ ] **Step 2: Add monitoring task to Taskfile.yml**

Add under the `tasks:` section in `Taskfile.yml` alongside the other deploy tasks:

```yaml
  monitoring:
    desc: Deploy Prometheus + Grafana monitoring stack
    cmds:
      - task: ansible
        vars: { PLAYBOOK: "main.yml", LIMIT: "monitoring,exporters,arr,caddy,pi-hole", CLI_ARGS: "{{.CLI_ARGS}}" }
```

- [ ] **Step 3: Dry-run against one node first**

```bash
doppler run -- ansible-playbook main.yml --limit tika.tlesh.xyz --tags '' --check
```

Expected: "Install node exporter" shows as would change, no errors.

- [ ] **Step 4: Deploy node_exporter to all exporters**

```bash
doppler run -- ansible-playbook main.yml --limit exporters
```

Expected: all hosts show `changed` for the install + systemd tasks, then `ok` on subsequent runs (idempotent).

- [ ] **Step 5: Verify node_exporter is up on a sample host**

```bash
curl -s http://192.168.233.7:9100/metrics | head -5
```

Expected: `# HELP` lines for node metrics.

- [ ] **Step 6: Commit**

```bash
rtk git add main.yml Taskfile.yml
rtk git commit -m "feat: wire node_exporter into main playbook and Taskfile"
```

---

## Task 4: Create monitoring role — defaults and directory setup

**Files:**
- Create: `roles/monitoring/defaults/main.yml`
- Create: `roles/monitoring/tasks/main.yml` (partial — directories only)

- [ ] **Step 1: Create defaults**

`roles/monitoring/defaults/main.yml`:

```yaml
---
prometheus_version: "v3"
prometheus_port: 9090
prometheus_config_dir: /opt/prometheus/config
prometheus_data_dir: /opt/prometheus/data
prometheus_retention: 30d

grafana_version: "11"
grafana_port: 3000
grafana_data_dir: /opt/grafana/data
grafana_provisioning_dir: /opt/grafana/provisioning
grafana_dashboards_dir: /opt/grafana/provisioning/dashboards
grafana_host: "grafana.tlesh.xyz"
grafana_admin_password: "{{ lookup('env', 'GRAFANA_ADMIN_PASSWORD') }}"

monitoring_network: monitoring
```

- [ ] **Step 2: Create tasks — directories and Docker network**

`roles/monitoring/tasks/main.yml`:

```yaml
---
- name: Install Docker Python SDK
  ansible.builtin.package:
    name: python3-docker
    state: present
  become: true

- name: Create Prometheus directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "65534"
    group: "65534"
    mode: "0755"
  loop:
    - "{{ prometheus_config_dir }}"
    - "{{ prometheus_data_dir }}"
  become: true

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
  become: true

- name: Create monitoring Docker network
  community.docker.docker_network:
    name: "{{ monitoring_network }}"
    state: present
  become: true
  when: not ansible_check_mode

- name: Template Prometheus config
  ansible.builtin.template:
    src: prometheus.yml.j2
    dest: "{{ prometheus_config_dir }}/prometheus.yml"
    owner: "65534"
    group: "65534"
    mode: "0644"
  become: true
  notify: Restart Prometheus

- name: Template Grafana datasource provisioning
  ansible.builtin.template:
    src: grafana-datasource.yml.j2
    dest: "{{ grafana_provisioning_dir }}/datasources/prometheus.yml"
    owner: "472"
    group: "472"
    mode: "0644"
  become: true
  notify: Restart Grafana

- name: Template Grafana dashboard provider
  ansible.builtin.template:
    src: grafana-dashboards-provider.yml.j2
    dest: "{{ grafana_dashboards_dir }}/provider.yml"
    owner: "472"
    group: "472"
    mode: "0644"
  become: true
  notify: Restart Grafana

- name: Copy dashboard JSON files
  ansible.builtin.copy:
    src: "dashboards/{{ item }}"
    dest: "{{ grafana_dashboards_dir }}/{{ item }}"
    owner: "472"
    group: "472"
    mode: "0644"
  loop:
    - node-exporter-full.json
    - exportarr-sonarr.json
    - exportarr-radarr.json
    - exportarr-lidarr.json
  become: true
  notify: Restart Grafana

- name: Deploy Prometheus container
  community.docker.docker_container:
    name: prometheus
    image: "prom/prometheus:{{ prometheus_version }}"
    state: started
    restart_policy: always
    networks:
      - name: "{{ monitoring_network }}"
    ports:
      - "{{ prometheus_port | string }}:9090"
    volumes:
      - "{{ prometheus_config_dir }}/prometheus.yml:/etc/prometheus/prometheus.yml:ro"
      - "{{ prometheus_data_dir }}:/prometheus"
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--storage.tsdb.retention.time={{ prometheus_retention }}"
      - "--web.enable-lifecycle"
  become: true
  when: not ansible_check_mode

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
    env:
      GF_SECURITY_ADMIN_PASSWORD: "{{ grafana_admin_password }}"
      GF_USERS_ALLOW_SIGN_UP: "false"
  become: true
  when: not ansible_check_mode
  no_log: true
```

- [ ] **Step 3: Create handlers**

`roles/monitoring/handlers/main.yml`:

```yaml
---
- name: Restart Prometheus
  community.docker.docker_container:
    name: prometheus
    state: started
    restart: true
  become: true
  when: not ansible_check_mode

- name: Restart Grafana
  community.docker.docker_container:
    name: grafana
    state: started
    restart: true
  become: true
  when: not ansible_check_mode
```

- [ ] **Step 4: Validate syntax**

```bash
task syntax && task lint
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 5: Commit**

```bash
rtk git add roles/monitoring/defaults/ roles/monitoring/tasks/ roles/monitoring/handlers/
rtk git commit -m "feat: add monitoring role scaffold with Prometheus and Grafana containers"
```

---

## Task 5: Create Prometheus and Grafana provisioning templates

**Files:**
- Create: `roles/monitoring/templates/prometheus.yml.j2`
- Create: `roles/monitoring/templates/grafana-datasource.yml.j2`
- Create: `roles/monitoring/templates/grafana-dashboards-provider.yml.j2`

- [ ] **Step 1: Create Prometheus scrape config template**

`roles/monitoring/templates/prometheus.yml.j2`:

```yaml
global:
  scrape_interval: 60s
  evaluation_interval: 60s

scrape_configs:
  - job_name: node
    static_configs:
      - targets:
{% for host in groups['exporters'] %}
        - "{{ hostvars[host]['ansible_host'] }}:9100"
{% endfor %}

  - job_name: exportarr-sonarr
    static_configs:
      - targets:
        - "192.168.233.24:9707"

  - job_name: exportarr-radarr
    static_configs:
      - targets:
        - "192.168.233.24:9708"

  - job_name: exportarr-lidarr
    static_configs:
      - targets:
        - "192.168.233.24:9709"
```

- [ ] **Step 2: Create Grafana datasource provisioning**

`roles/monitoring/templates/grafana-datasource.yml.j2`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

- [ ] **Step 3: Create Grafana dashboard provider**

`roles/monitoring/templates/grafana-dashboards-provider.yml.j2`:

```yaml
apiVersion: 1

providers:
  - name: default
    type: file
    updateIntervalSeconds: 30
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: false
```

- [ ] **Step 4: Validate**

```bash
task syntax && task lint
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 5: Commit**

```bash
rtk git add roles/monitoring/templates/
rtk git commit -m "feat: add Prometheus and Grafana provisioning templates"
```

---

## Task 6: Download community dashboard JSON files

**Files:**
- Create: `roles/monitoring/files/dashboards/node-exporter-full.json`
- Create: `roles/monitoring/files/dashboards/exportarr-sonarr.json`
- Create: `roles/monitoring/files/dashboards/exportarr-radarr.json`
- Create: `roles/monitoring/files/dashboards/exportarr-lidarr.json`

- [ ] **Step 1: Create dashboards directory**

```bash
mkdir -p roles/monitoring/files/dashboards
```

- [ ] **Step 2: Download Node Exporter Full dashboard**

```bash
curl -sL "https://grafana.com/api/dashboards/1860/revisions/latest/download" \
  -o roles/monitoring/files/dashboards/node-exporter-full.json
```

Expected: file is ~150KB of JSON, starts with `{"annotations":`.

- [ ] **Step 3: Download exportarr dashboards**

```bash
curl -sL "https://raw.githubusercontent.com/onedr0p/exportarr/master/examples/grafana/dashboard2.json" \
  -o roles/monitoring/files/dashboards/exportarr-sonarr.json

curl -sL "https://raw.githubusercontent.com/onedr0p/exportarr/master/examples/grafana/dashboard2.json" \
  -o roles/monitoring/files/dashboards/exportarr-radarr.json

curl -sL "https://raw.githubusercontent.com/onedr0p/exportarr/master/examples/grafana/dashboard2.json" \
  -o roles/monitoring/files/dashboards/exportarr-lidarr.json
```

Note: exportarr uses a single shared dashboard template. After downloading, open each JSON file and change the `title` field to match the service: `"Sonarr"`, `"Radarr"`, `"Lidarr"` respectively, and update the `job` label filter variable default value to `exportarr-sonarr`, `exportarr-radarr`, `exportarr-lidarr`.

- [ ] **Step 4: Verify all files downloaded**

```bash
ls -lh roles/monitoring/files/dashboards/
```

Expected: 4 JSON files, all non-empty.

- [ ] **Step 5: Commit**

```bash
rtk git add roles/monitoring/files/
rtk git commit -m "feat: add community dashboard JSON files for Prometheus and Grafana"
```

---

## Task 7: Create exportarr role

**Files:**
- Create: `roles/exportarr/defaults/main.yml`
- Create: `roles/exportarr/tasks/main.yml`
- Create: `group_vars/exportarr.yml`

- [ ] **Step 1: Create defaults**

`roles/exportarr/defaults/main.yml`:

```yaml
---
exportarr_version: "v2"
exportarr_sonarr_port: 9707
exportarr_radarr_port: 9708
exportarr_lidarr_port: 9709
exportarr_sonarr_url: "http://localhost:8989"
exportarr_radarr_url: "http://localhost:7878"
exportarr_lidarr_url: "http://localhost:8686"
exportarr_sonarr_api_key: "{{ lookup('env', 'SONARR_API_KEY') }}"
exportarr_radarr_api_key: "{{ lookup('env', 'RADARR_API_KEY') }}"
exportarr_lidarr_api_key: "{{ lookup('env', 'LIDARR_API_KEY') }}"
```

- [ ] **Step 2: Create tasks**

`roles/exportarr/tasks/main.yml`:

```yaml
---
- name: Install Docker Python SDK
  ansible.builtin.package:
    name: python3-docker
    state: present
  become: true

- name: Deploy exportarr for Sonarr
  community.docker.docker_container:
    name: exportarr-sonarr
    image: "ghcr.io/onedr0p/exportarr:{{ exportarr_version }}"
    state: started
    restart_policy: always
    ports:
      - "{{ exportarr_sonarr_port | string }}:{{ exportarr_sonarr_port | string }}"
    command: sonarr
    env:
      PORT: "{{ exportarr_sonarr_port | string }}"
      URL: "{{ exportarr_sonarr_url }}"
      APIKEY: "{{ exportarr_sonarr_api_key }}"
  become: true
  when: not ansible_check_mode
  no_log: true

- name: Deploy exportarr for Radarr
  community.docker.docker_container:
    name: exportarr-radarr
    image: "ghcr.io/onedr0p/exportarr:{{ exportarr_version }}"
    state: started
    restart_policy: always
    ports:
      - "{{ exportarr_radarr_port | string }}:{{ exportarr_radarr_port | string }}"
    command: radarr
    env:
      PORT: "{{ exportarr_radarr_port | string }}"
      URL: "{{ exportarr_radarr_url }}"
      APIKEY: "{{ exportarr_radarr_api_key }}"
  become: true
  when: not ansible_check_mode
  no_log: true

- name: Deploy exportarr for Lidarr
  community.docker.docker_container:
    name: exportarr-lidarr
    image: "ghcr.io/onedr0p/exportarr:{{ exportarr_version }}"
    state: started
    restart_policy: always
    ports:
      - "{{ exportarr_lidarr_port | string }}:{{ exportarr_lidarr_port | string }}"
    command: lidarr
    env:
      PORT: "{{ exportarr_lidarr_port | string }}"
      URL: "{{ exportarr_lidarr_url }}"
      APIKEY: "{{ exportarr_lidarr_api_key }}"
  become: true
  when: not ansible_check_mode
  no_log: true
```

- [ ] **Step 3: Validate**

```bash
task syntax && task lint
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 4: Commit**

```bash
rtk git add roles/exportarr/
rtk git commit -m "feat: add exportarr role for arr metrics"
```

---

## Task 8: Wire monitoring and exportarr into main.yml

**Files:**
- Modify: `main.yml`

- [ ] **Step 1: Add monitoring play to main.yml**

Add after the `setup docker server` play (hosts: kaz) in `main.yml`:

```yaml
- name: deploy monitoring stack
  hosts: monitoring
  gather_facts: true
  roles:
    - role: monitoring
```

- [ ] **Step 2: Add exportarr play to main.yml**

Add after the `setup arr stack` play (hosts: arr) in `main.yml`:

```yaml
- name: deploy exportarr metrics exporters
  hosts: arr
  gather_facts: true
  roles:
    - role: exportarr
```

- [ ] **Step 3: Validate**

```bash
task syntax && task lint
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 4: Commit**

```bash
rtk git add main.yml
rtk git commit -m "feat: wire monitoring and exportarr plays into main playbook"
```

---

## Task 9: Add grafana.tlesh.xyz to Caddy and pi-hole

**Files:**
- Modify: `roles/caddy/defaults/main.yml`
- Modify: `roles/pi-hole/defaults/main.yml`

- [ ] **Step 1: Add Grafana to Caddy services list**

In `roles/caddy/defaults/main.yml`, add to the `caddy_services` list:

```yaml
  - name: grafana
    upstream: "192.168.233.10:3000"
```

- [ ] **Step 2: Add Grafana DNS entry to pi-hole**

In `roles/pi-hole/defaults/main.yml`, add to the `pihole_local_hosts` list:

```yaml
  - "192.168.233.17 grafana.tlesh.xyz"
```

(Note: .17 is caddy — Caddy terminates TLS and proxies to kaz:3000.)

- [ ] **Step 3: Validate**

```bash
task syntax && task lint
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 4: Commit**

```bash
rtk git add roles/caddy/defaults/main.yml roles/pi-hole/defaults/main.yml
rtk git commit -m "feat: add grafana.tlesh.xyz to Caddy and pi-hole DNS"
```

---

## Task 10: Deploy the full monitoring stack

- [ ] **Step 1: Dry-run monitoring role on kaz**

```bash
doppler run -- ansible-playbook main.yml --limit kaz.tlesh.xyz --check
```

Expected: directory creation, template, container tasks shown as would-change. No failures.

- [ ] **Step 2: Deploy monitoring stack**

```bash
task monitoring
```

Expected: all tasks complete without errors.

- [ ] **Step 3: Verify Prometheus targets**

Open `http://192.168.233.10:9090/targets` in browser.

Expected: all node_exporter targets and exportarr targets listed. Confirm they show State=UP after ~60 seconds.

- [ ] **Step 4: Verify Grafana is accessible**

Open `https://grafana.tlesh.xyz` in browser (requires Caddy + pi-hole deploy first if not done).

Login with username `admin` and the `GRAFANA_ADMIN_PASSWORD` from Doppler.

Expected: Node Exporter Full and exportarr dashboards visible under Dashboards.

- [ ] **Step 5: Deploy Caddy and pi-hole updates**

```bash
doppler run -- ansible-playbook main.yml --limit caddy.tlesh.xyz,pi-hole.tlesh.xyz
```

---

## Task 11: Add Grafana to Uptime Kuma and Glance

Per the new service checklist, every service with a web UI needs Uptime Kuma + Glance entries.

- [ ] **Step 1: Add Uptime Kuma monitor for Grafana**

Log into Uptime Kuma at `https://uptime-kuma.tlesh.xyz` and add:
- Type: HTTP(s)
- Friendly Name: Grafana
- URL: `https://grafana.tlesh.xyz`
- Heartbeat interval: 60s

- [ ] **Step 2: Add Grafana to Glance dashboard**

Find the Glance config in `roles/glance/templates/` or `roles/glance/files/` and add a Grafana monitor widget/link to the dashboard. Follow the pattern used for other services already listed.

Deploy: `doppler run -- ansible-playbook main.yml --limit kaz.tlesh.xyz`

---

## Task 12: Verify all targets and commit final state

- [ ] **Step 1: Confirm all Prometheus targets are UP**

```bash
curl -s http://192.168.233.10:9090/api/v1/targets | python3 -c "
import json, sys
data = json.load(sys.stdin)
targets = data['data']['activeTargets']
down = [t for t in targets if t['health'] != 'up']
print(f'Total: {len(targets)}, Down: {len(down)}')
for t in down:
    print(f'  DOWN: {t[\"labels\"][\"job\"]} {t[\"scrapeUrl\"]}')
"
```

Expected: `Down: 0`.

- [ ] **Step 2: Run full syntax and lint check**

```bash
task syntax && task lint
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 3: Push branch**

```bash
rtk git push -u origin feature/grafana-prometheus-migration
```

- [ ] **Step 4: Run CodeRabbit review**

```bash
coderabbit review --plain --base main
```

Address any issues found before creating the PR.

- [ ] **Step 5: Open PR via /ship**

Use `/ship` to create the PR.

---

## Phase 2: Decommission Netdata (separate PR — after verification period)

> Run this only after Grafana has been running cleanly for ~1 day with all targets UP.

- [ ] **Step 1: Create decommission branch**

```bash
git checkout main && git pull
git checkout -b chore/decommission-netdata
```

- [ ] **Step 2: Delete netdata Terraform file**

```bash
rm terraform/netdata.tf
```

Run `task plan` in `terraform/` to confirm it will destroy `proxmox_virtual_environment_container.netdata`. Then run `task apply`.

- [ ] **Step 3: Remove netdata plays from main.yml**

Remove both plays:
- `setup netdata parent` (hosts: netdata)
- `setup netdata agents on proxmox nodes` (hosts: proxmox, roles: netdata)

- [ ] **Step 4: Remove netdata from Taskfile**

Remove the `netdata:` task block from `Taskfile.yml`.

- [ ] **Step 5: Remove netdata group_vars**

```bash
rm group_vars/netdata.yml
```

In `group_vars/proxmox.yml`, remove:
```yaml
netdata_role: "child"
netdata_parent_host: "192.168.233.23"
netdata_parent_port: 19999
```

- [ ] **Step 6: Remove netdata from inventory**

In `inventory/hosts`, remove the `[netdata]` group block:
```ini
[netdata]
netdata.tlesh.xyz ansible_host=192.168.233.23
```

- [ ] **Step 7: Remove netdata Caddy site**

In `roles/caddy/defaults/main.yml`, remove from `caddy_services`:
```yaml
  - name: netdata
    upstream: "192.168.233.23:19999"
```

Deploy Caddy: `doppler run -- ansible-playbook main.yml --limit caddy.tlesh.xyz`

- [ ] **Step 8: Remove netdata pi-hole DNS entry**

In `roles/pi-hole/defaults/main.yml`, remove:
```yaml
  - "192.168.233.17 netdata.tlesh.xyz"
```

Deploy pi-hole: `doppler run -- ansible-playbook main.yml --limit pi-hole.tlesh.xyz`

- [ ] **Step 9: Delete netdata role**

```bash
rm -rf roles/netdata/
```

- [ ] **Step 10: Validate**

```bash
task syntax && task lint
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 11: Remove NETDATA_STREAM_API_KEY from Doppler**

In Doppler dashboard, delete `NETDATA_STREAM_API_KEY` from the main config.

- [ ] **Step 12: Commit and open PR**

```bash
rtk git add -A
rtk git commit -m "chore: decommission Netdata monitoring stack"
rtk git push -u origin chore/decommission-netdata
```

Run `coderabbit review --plain --base main` then use `/ship` to open the PR.
