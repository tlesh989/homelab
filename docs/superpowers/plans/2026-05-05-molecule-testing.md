# Molecule Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Molecule test coverage (default structural + integration stub scenarios) to the four homelab-owned Ansible roles: `cloudflare_ddns`, `minecraft`, `n8n`, `monitoring`.

**Architecture:** Per-role two-scenario layout mirroring vendored Galaxy roles. Default scenarios run in lightweight Docker containers testing file/package operations; integration scenarios stub DinD-based full-stack testing. Docker-only tasks in roles are guarded by a `molecule_testing` var set in scenario group_vars to prevent failures in the structural default scenario.

**Tech Stack:** molecule, molecule-plugins[docker], pytest-testinfra (for CLI assertions), geerlingguy/docker-ubuntu2604-ansible image, Ansible ansible verifier for most assertions, Task runner.

---

## File Map

**New files:**
- `requirements-dev.txt`
- `roles/cloudflare_ddns/molecule/default/{molecule.yml,converge.yml,prepare.yml,verify.yml,cleanup.yml}`
- `roles/cloudflare_ddns/molecule/integration/{molecule.yml,converge.yml,verify.yml}`
- `roles/minecraft/molecule/default/{molecule.yml,converge.yml,prepare.yml,verify.yml,cleanup.yml}`
- `roles/minecraft/molecule/integration/{molecule.yml,converge.yml,verify.yml}`
- `roles/n8n/molecule/default/{molecule.yml,converge.yml,prepare.yml,verify.yml,cleanup.yml}`
- `roles/n8n/molecule/integration/{molecule.yml,converge.yml,verify.yml}`
- `roles/monitoring/molecule/default/{molecule.yml,converge.yml,prepare.yml,verify.yml,cleanup.yml}`
- `roles/monitoring/molecule/integration/{molecule.yml,converge.yml,verify.yml}`
- `docs/molecule-hardening-report.md` (produced by iteration loop)

**Modified files:**
- `Taskfile.yml` — add three molecule targets
- `roles/cloudflare_ddns/tasks/main.yml` — add `molecule_testing` guard to container deploy
- `roles/n8n/tasks/main.yml` — add `molecule_testing` guard to container deploy
- `roles/monitoring/tasks/main.yml` — add `molecule_testing` guard to Docker network + container deploys

---

## Task 1: Install Molecule

**Files:**
- Create: `requirements-dev.txt`

- [ ] **Step 1: Create requirements-dev.txt**

```
# requirements-dev.txt
molecule
molecule-plugins[docker]
pytest-testinfra
ansible-core
```

- [ ] **Step 2: Create and activate a virtualenv, install dependencies**

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
```

Expected: pip installs without errors.

- [ ] **Step 3: Verify molecule is available**

```bash
molecule --version
```

Expected output contains: `molecule 6.x.x` (or higher).

- [ ] **Step 4: Commit**

```bash
git add requirements-dev.txt
git commit -m "chore: add molecule dev dependencies"
```

---

## Task 2: Add Taskfile Molecule Targets

**Files:**
- Modify: `Taskfile.yml`

- [ ] **Step 1: Add three molecule tasks to Taskfile.yml**

Find the `tasks:` section in `Taskfile.yml` and add after the existing tasks (before the `ansible:` internal task if present):

```yaml
  molecule-test:
    desc: "Run Molecule default scenario for a role. Usage: task molecule-test -- ROLE=<role>"
    cmds:
      - cd roles/{{.ROLE}} && molecule test -s default

  molecule-integration:
    desc: "Run Molecule integration scenario for a role (requires Docker-in-Docker). Usage: task molecule-integration -- ROLE=<role>"
    cmds:
      - cd roles/{{.ROLE}} && molecule test -s integration

  molecule-test-all:
    desc: "Run Molecule default scenario for all four roles"
    cmds:
      - task: molecule-test
        vars: { ROLE: cloudflare_ddns }
      - task: molecule-test
        vars: { ROLE: minecraft }
      - task: molecule-test
        vars: { ROLE: n8n }
      - task: molecule-test
        vars: { ROLE: monitoring }
```

- [ ] **Step 2: Verify task list shows new targets**

```bash
task --list | grep molecule
```

Expected: three entries (`molecule-test`, `molecule-integration`, `molecule-test-all`).

- [ ] **Step 3: Commit**

```bash
git add Taskfile.yml
git commit -m "chore: add molecule task targets"
```

---

## Task 3: Add molecule_testing Guard to Docker Tasks in Roles

Without this guard, `community.docker.*` tasks fail in the default scenario because the lightweight test container has no Docker daemon. The `when: not ansible_check_mode` gate already on these tasks is preserved alongside the new guard.

**Files:**
- Modify: `roles/cloudflare_ddns/tasks/main.yml`
- Modify: `roles/n8n/tasks/main.yml`
- Modify: `roles/monitoring/tasks/main.yml`

- [ ] **Step 1: Guard the container deploy task in cloudflare_ddns**

In `roles/cloudflare_ddns/tasks/main.yml`, find the `Deploy Cloudflare DDNS container` task and replace its `when:` line:

```yaml
# Before:
  when: not ansible_check_mode

# After:
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

- [ ] **Step 2: Guard the container deploy task in n8n**

In `roles/n8n/tasks/main.yml`, find the `Deploy n8n container` task and replace its `when:` line:

```yaml
# Before:
  when: not ansible_check_mode

# After:
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

- [ ] **Step 3: Guard Docker tasks in monitoring**

In `roles/monitoring/tasks/main.yml`, find every `community.docker.*` task (`Create monitoring Docker network`, `Deploy Prometheus container`, `Deploy Grafana container`, `Deploy cAdvisor container`, `Deploy pve-exporter container`) and update each `when:` line from:

```yaml
  when: not ansible_check_mode
```

to:

```yaml
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

- [ ] **Step 4: Verify lint still passes**

```bash
task lint
```

Expected: zero failures.

- [ ] **Step 5: Commit**

```bash
git add roles/cloudflare_ddns/tasks/main.yml roles/n8n/tasks/main.yml roles/monitoring/tasks/main.yml
git commit -m "chore: add molecule_testing guard to Docker tasks for test isolation"
```

---

## Task 4: cloudflare_ddns Default Scenario

The cloudflare_ddns role is entirely Docker-based (4 assert tasks + python3-docker package + container deploy). The default scenario verifies: assert tasks pass with fake env vars, python3-docker is installed.

**Files:**
- Create: `roles/cloudflare_ddns/molecule/default/molecule.yml`
- Create: `roles/cloudflare_ddns/molecule/default/converge.yml`
- Create: `roles/cloudflare_ddns/molecule/default/prepare.yml`
- Create: `roles/cloudflare_ddns/molecule/default/verify.yml`
- Create: `roles/cloudflare_ddns/molecule/default/cleanup.yml`

- [ ] **Step 1: Create molecule.yml**

```yaml
# roles/cloudflare_ddns/molecule/default/molecule.yml
---
role_name_check: 1
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2604-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        molecule_testing: true
        ddns_image_version: "1"
        ddns_domains: fake.example.com
        ddns_proxied: "false"
  env:
    CF_DNS_API_TOKEN: fake-cf-token
    DDNS_DOMAINS: fake.example.com
    PUSHOVER_API_TOKEN: fake-pushover-token
    PUSHOVER_USER_KEY: fake-pushover-key
verifier:
  name: ansible
```

- [ ] **Step 2: Create converge.yml**

```yaml
# roles/cloudflare_ddns/molecule/default/converge.yml
---
- name: Converge
  hosts: all
  gather_facts: true
  roles:
    - role: cloudflare_ddns
```

- [ ] **Step 3: Create prepare.yml (no prior state needed)**

```yaml
# roles/cloudflare_ddns/molecule/default/prepare.yml
---
- name: Prepare
  hosts: all
  gather_facts: false
  tasks:
    - name: No preparation required for cloudflare_ddns default scenario
      ansible.builtin.debug:
        msg: "cloudflare_ddns has no filesystem state to pre-seed"
```

- [ ] **Step 4: Create verify.yml**

```yaml
# roles/cloudflare_ddns/molecule/default/verify.yml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Verify python3-docker is installed
      ansible.builtin.package_facts:
        manager: apt

    - name: Assert python3-docker package is present
      ansible.builtin.assert:
        that:
          - "'python3-docker' in ansible_facts.packages"
        fail_msg: "python3-docker was not installed by the cloudflare_ddns role"
        success_msg: "python3-docker is installed"
```

- [ ] **Step 5: Create cleanup.yml**

```yaml
# roles/cloudflare_ddns/molecule/default/cleanup.yml
---
- name: Cleanup
  hosts: all
  gather_facts: false
  tasks:
    - name: No cleanup required for cloudflare_ddns default scenario
      ansible.builtin.debug:
        msg: "Nothing to clean up"
```

- [ ] **Step 6: Commit**

```bash
git add roles/cloudflare_ddns/molecule/
git commit -m "test(cloudflare_ddns): add molecule default scenario"
```

---

## Task 5: minecraft Default Scenario

The minecraft role has rich file system operations with no Docker tasks — the best candidate for structural testing. Tests: directory layout, system user, config templates, systemd service, cron job, update script existence + silent-exit behavior.

The upgrade-path test uses `prepare.yml` to write an older version file, then `converge.yml` runs with the same version (no network download needed in the structural scenario — we just verify the version-check logic skips the download when versions match and triggers it when older).

**Files:**
- Create: `roles/minecraft/molecule/default/molecule.yml`
- Create: `roles/minecraft/molecule/default/converge.yml`
- Create: `roles/minecraft/molecule/default/prepare.yml`
- Create: `roles/minecraft/molecule/default/verify.yml`
- Create: `roles/minecraft/molecule/default/cleanup.yml`

- [ ] **Step 1: Create molecule.yml**

```yaml
# roles/minecraft/molecule/default/molecule.yml
---
role_name_check: 1
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2604-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        molecule_testing: true
        # Pin version to match what prepare.yml writes so download is skipped
        minecraft_bds_version: "1.21.2.1"
        minecraft_bds_download_url: "https://example.com/fake-bedrock.zip"
        minecraft_install_dir: /opt/minecraft
        minecraft_operator_xuid: "1234567890123456"
        minecraft_update_weekday: "0"
        minecraft_update_hour: "3"
        minecraft_update_minute: "0"
        minecraft_server_name: "Molecule Test Server"
        minecraft_gamemode: survival
        minecraft_difficulty: normal
        minecraft_max_players: 10
        minecraft_level_seed: ""
        minecraft_allow_cheats: "false"
        minecraft_online_mode: "true"
  env:
    MINECRAFT_OPERATOR_XUID: "1234567890123456"
verifier:
  name: ansible
```

- [ ] **Step 2: Create prepare.yml (write older version to trigger upgrade-path logic)**

```yaml
# roles/minecraft/molecule/default/prepare.yml
---
- name: Prepare
  hosts: all
  gather_facts: false
  tasks:
    - name: Create minecraft install directory
      ansible.builtin.file:
        path: /opt/minecraft
        state: directory
        owner: root
        group: root
        mode: "0755"
      become: true

    - name: Write older .version file to simulate upgrade scenario
      ansible.builtin.copy:
        content: "1.20.0.0"
        dest: /opt/minecraft/.version
        mode: "0644"
      become: true
```

Note: `converge.yml` runs with `minecraft_bds_version: 1.21.2.1` which is newer than `1.20.0.0` so the download task triggers — but because this is a structural scenario the download will fail on a nonexistent URL. The molecule idempotency test catches if the download task incorrectly fires a second time.

**To prevent download failure in the default scenario**, add a second converge pass that sets the version to match installed. Alternatively, accept that the download step will fail and check only idempotency from a matching version. The simplest approach: set `minecraft_bds_version` to `1.20.0.0` in the scenario so it matches prepare.yml's written version — download is skipped entirely, and we test the no-change idempotency path.

Update `molecule.yml`'s group_vars to set `minecraft_bds_version: "1.20.0.0"` (matching prepare.yml's written version) so the download condition `when: minecraft_bds_version is version(minecraft_installed_version, '>')` is false and the role converges cleanly.

- [ ] **Step 3: Update molecule.yml version to match prepare.yml (no download)**

Edit `roles/minecraft/molecule/default/molecule.yml` and change:

```yaml
        minecraft_bds_version: "1.20.0.0"
```

(Was `1.21.2.1` — set to match prepare.yml's `1.20.0.0` so download is skipped in default scenario.)

- [ ] **Step 4: Create converge.yml**

```yaml
# roles/minecraft/molecule/default/converge.yml
---
- name: Converge
  hosts: all
  gather_facts: true
  roles:
    - role: minecraft
```

- [ ] **Step 5: Create verify.yml**

```yaml
# roles/minecraft/molecule/default/verify.yml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Verify minecraft system user exists
      ansible.builtin.getent:
        database: passwd
        key: minecraft
      register: minecraft_user

    - name: Assert minecraft user has nologin shell
      ansible.builtin.assert:
        that:
          - minecraft_user.ansible_facts.getent_passwd['minecraft'][4] == '/usr/sbin/nologin'
        fail_msg: "minecraft user does not exist or has wrong shell"

    - name: Verify install directory exists with correct ownership
      ansible.builtin.stat:
        path: /opt/minecraft
      register: install_dir

    - name: Assert install directory is owned by minecraft
      ansible.builtin.assert:
        that:
          - install_dir.stat.exists
          - install_dir.stat.isdir
          - install_dir.stat.pw_name == 'minecraft'
          - install_dir.stat.gr_name == 'minecraft'
          - install_dir.stat.mode == '0755'
        fail_msg: "Install directory missing or wrong ownership"

    - name: Verify server.properties exists
      ansible.builtin.stat:
        path: /opt/minecraft/server.properties
      register: server_props

    - name: Assert server.properties is owned by minecraft
      ansible.builtin.assert:
        that:
          - server_props.stat.exists
          - server_props.stat.pw_name == 'minecraft'
          - server_props.stat.mode == '0644'
        fail_msg: "server.properties missing or wrong ownership"

    - name: Verify permissions.json exists
      ansible.builtin.stat:
        path: /opt/minecraft/permissions.json
      register: perms_json

    - name: Assert permissions.json is owned by minecraft
      ansible.builtin.assert:
        that:
          - perms_json.stat.exists
          - perms_json.stat.pw_name == 'minecraft'
        fail_msg: "permissions.json missing or wrong ownership"

    - name: Verify systemd service file exists
      ansible.builtin.stat:
        path: /etc/systemd/system/minecraft.service
      register: service_file

    - name: Assert service file exists
      ansible.builtin.assert:
        that:
          - service_file.stat.exists
        fail_msg: "minecraft.service file not found"

    - name: Read service file content
      ansible.builtin.slurp:
        src: /etc/systemd/system/minecraft.service
      register: service_content

    - name: Assert service has Restart=on-failure (failure recovery)
      ansible.builtin.assert:
        that:
          - "'Restart=on-failure' in (service_content.content | b64decode)"
        fail_msg: "minecraft.service missing Restart=on-failure — service won't recover from crashes"

    - name: Verify update script exists and is executable
      ansible.builtin.stat:
        path: /usr/local/bin/minecraft-update
      register: update_script

    - name: Assert update script is executable
      ansible.builtin.assert:
        that:
          - update_script.stat.exists
          - update_script.stat.executable
        fail_msg: "minecraft-update script missing or not executable"

    - name: Read update script content
      ansible.builtin.slurp:
        src: /usr/local/bin/minecraft-update
      register: script_content

    - name: Assert update script has set -euo pipefail (silent-exit protection)
      ansible.builtin.assert:
        that:
          - "'set -euo pipefail' in (script_content.content | b64decode)"
        fail_msg: "minecraft-update missing set -euo pipefail — errors may silently swallow"

    # Silent-exit bug class: script must emit output on bad input, not exit silently
    - name: Run update script with unsafe INSTALL_DIR to trigger early-exit guard
      ansible.builtin.command:
        cmd: bash -c "INSTALL_DIR=/ /usr/local/bin/minecraft-update 2>&1 || true"
      register: script_bad_input
      changed_when: false

    - name: Assert script produces output on bad input (no silent exit)
      ansible.builtin.assert:
        that:
          - script_bad_input.stdout | length > 0
        fail_msg: >
          minecraft-update exited silently with INSTALL_DIR=/ —
          the early-exit guard should print an error message before exiting.
          Output was empty, which is the silent-exit bug pattern.

    - name: Verify cron job is registered for auto-update
      ansible.builtin.command:
        cmd: crontab -l -u root
      register: root_crontab
      failed_when: false
      changed_when: false

    - name: Assert minecraft-update cron job is present
      ansible.builtin.assert:
        that:
          - "'minecraft-update' in root_crontab.stdout"
        fail_msg: "minecraft-update cron job not found in root crontab"
```

- [ ] **Step 6: Create cleanup.yml**

```yaml
# roles/minecraft/molecule/default/cleanup.yml
---
- name: Cleanup
  hosts: all
  gather_facts: false
  tasks:
    - name: No extra cleanup required (container is destroyed by molecule)
      ansible.builtin.debug:
        msg: "Cleanup handled by molecule destroy"
```

- [ ] **Step 7: Commit**

```bash
git add roles/minecraft/molecule/
git commit -m "test(minecraft): add molecule default scenario"
```

---

## Task 6: n8n Default Scenario

The n8n role creates one data directory then deploys a Docker container (skipped via `molecule_testing`). The default scenario verifies: data directory exists with correct UID ownership (1000:1000) and mode 0700, python3-docker is installed.

**Files:**
- Create: `roles/n8n/molecule/default/molecule.yml`
- Create: `roles/n8n/molecule/default/converge.yml`
- Create: `roles/n8n/molecule/default/prepare.yml`
- Create: `roles/n8n/molecule/default/verify.yml`
- Create: `roles/n8n/molecule/default/cleanup.yml`

- [ ] **Step 1: Create molecule.yml**

```yaml
# roles/n8n/molecule/default/molecule.yml
---
role_name_check: 1
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2604-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        molecule_testing: true
        n8n_data_path: /opt/n8n
        n8n_port: 5678
        n8n_host: n8n.example.com
        n8n_version: "1"
verifier:
  name: ansible
```

- [ ] **Step 2: Create converge.yml**

```yaml
# roles/n8n/molecule/default/converge.yml
---
- name: Converge
  hosts: all
  gather_facts: true
  roles:
    - role: n8n
```

- [ ] **Step 3: Create prepare.yml**

```yaml
# roles/n8n/molecule/default/prepare.yml
---
- name: Prepare
  hosts: all
  gather_facts: false
  tasks:
    - name: No prior state needed for n8n default scenario
      ansible.builtin.debug:
        msg: "n8n default scenario has no prior state to seed"
```

- [ ] **Step 4: Create verify.yml**

```yaml
# roles/n8n/molecule/default/verify.yml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Verify n8n data directory exists
      ansible.builtin.stat:
        path: /opt/n8n
      register: n8n_dir

    - name: Assert n8n data directory has correct mode and UID
      ansible.builtin.assert:
        that:
          - n8n_dir.stat.exists
          - n8n_dir.stat.isdir
          - n8n_dir.stat.uid == 1000
          - n8n_dir.stat.gid == 1000
          - n8n_dir.stat.mode == '0700'
        fail_msg: >
          n8n data directory missing or wrong permissions.
          Expected uid=1000 gid=1000 mode=0700,
          got uid={{ n8n_dir.stat.uid }} gid={{ n8n_dir.stat.gid }} mode={{ n8n_dir.stat.mode }}

    - name: Verify python3-docker is installed
      ansible.builtin.package_facts:
        manager: apt

    - name: Assert python3-docker is present
      ansible.builtin.assert:
        that:
          - "'python3-docker' in ansible_facts.packages"
        fail_msg: "python3-docker was not installed by the n8n role"
```

- [ ] **Step 5: Create cleanup.yml**

```yaml
# roles/n8n/molecule/default/cleanup.yml
---
- name: Cleanup
  hosts: all
  gather_facts: false
  tasks:
    - name: No cleanup required
      ansible.builtin.debug:
        msg: "Cleanup handled by molecule destroy"
```

- [ ] **Step 6: Commit**

```bash
git add roles/n8n/molecule/
git commit -m "test(n8n): add molecule default scenario"
```

---

## Task 7: monitoring Default Scenario

The monitoring role creates many directories with specific container UIDs (65534 for Prometheus/nobody, 472 for Grafana), templates Prometheus config and Grafana alerting files, and asserts env vars. Docker tasks are guarded by `molecule_testing`. This is the richest structural scenario.

**Files:**
- Create: `roles/monitoring/molecule/default/molecule.yml`
- Create: `roles/monitoring/molecule/default/converge.yml`
- Create: `roles/monitoring/molecule/default/prepare.yml`
- Create: `roles/monitoring/molecule/default/verify.yml`
- Create: `roles/monitoring/molecule/default/cleanup.yml`

- [ ] **Step 1: Create molecule.yml**

```yaml
# roles/monitoring/molecule/default/molecule.yml
---
role_name_check: 1
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2604-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        molecule_testing: true
        prometheus_version: "v3"
        prometheus_port: 9090
        prometheus_config_dir: /opt/prometheus/config
        prometheus_data_dir: /opt/prometheus/data
        prometheus_retention: 30d
        grafana_version: "13.0"
        grafana_port: 3000
        grafana_data_dir: /opt/grafana/data
        grafana_provisioning_dir: /opt/grafana/provisioning
        grafana_dashboards_dir: /opt/grafana/provisioning/dashboards
        grafana_alerting_dir: /opt/grafana/provisioning/alerting
        grafana_admin_password: fake-grafana-password
        monitoring_network: monitoring
        cadvisor_version: "0.56"
        cadvisor_port: 8083
        pve_exporter_version: "3"
        pve_exporter_port: 9221
        pve_exporter_config_dir: /opt/pve-exporter
        # Minimal inventory group for Prometheus scrape target templating
        groups:
          monitoring:
            hosts:
              molecule-instance:
                ansible_host: 127.0.0.1
  env:
    PUSHOVER_API_TOKEN: fake-pushover-token
    PUSHOVER_USER_KEY: fake-pushover-key
    PVE_TOKEN_ID: fake@pve!token
    PVE_TOKEN_SECRET: fakesecret
    GRAFANA_ADMIN_PASSWORD: fake-grafana-password
verifier:
  name: ansible
```

- [ ] **Step 2: Create converge.yml**

```yaml
# roles/monitoring/molecule/default/converge.yml
---
- name: Converge
  hosts: all
  gather_facts: true
  roles:
    - role: monitoring
```

- [ ] **Step 3: Create prepare.yml**

```yaml
# roles/monitoring/molecule/default/prepare.yml
---
- name: Prepare
  hosts: all
  gather_facts: false
  tasks:
    - name: No prior state needed for monitoring default scenario
      ansible.builtin.debug:
        msg: "monitoring default scenario has no prior state to seed"
```

- [ ] **Step 4: Create verify.yml**

```yaml
# roles/monitoring/molecule/default/verify.yml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    # --- Prometheus directories ---
    - name: Stat Prometheus config directory
      ansible.builtin.stat:
        path: /opt/prometheus/config
      register: prom_config_dir

    - name: Assert Prometheus config dir has correct UID (65534 = nobody)
      ansible.builtin.assert:
        that:
          - prom_config_dir.stat.exists
          - prom_config_dir.stat.isdir
          - prom_config_dir.stat.uid == 65534
          - prom_config_dir.stat.gid == 65534
          - prom_config_dir.stat.mode == '0755'
        fail_msg: >
          Prometheus config dir wrong. Expected uid=65534 gid=65534 mode=0755,
          got uid={{ prom_config_dir.stat.uid }} gid={{ prom_config_dir.stat.gid }} mode={{ prom_config_dir.stat.mode }}

    - name: Stat Prometheus data directory
      ansible.builtin.stat:
        path: /opt/prometheus/data
      register: prom_data_dir

    - name: Assert Prometheus data dir exists with correct UID
      ansible.builtin.assert:
        that:
          - prom_data_dir.stat.exists
          - prom_data_dir.stat.uid == 65534
        fail_msg: "Prometheus data dir missing or wrong UID"

    - name: Verify prometheus.yml config is templated
      ansible.builtin.stat:
        path: /opt/prometheus/config/prometheus.yml
      register: prom_config_file

    - name: Assert prometheus.yml exists and is readable by nobody (65534)
      ansible.builtin.assert:
        that:
          - prom_config_file.stat.exists
          - prom_config_file.stat.uid == 65534
          - prom_config_file.stat.mode == '0644'
        fail_msg: "prometheus.yml missing or wrong ownership"

    # --- Grafana directories ---
    - name: Stat Grafana data directory
      ansible.builtin.stat:
        path: /opt/grafana/data
      register: grafana_data_dir

    - name: Assert Grafana data dir has correct UID (472 = grafana container user)
      ansible.builtin.assert:
        that:
          - grafana_data_dir.stat.exists
          - grafana_data_dir.stat.uid == 472
          - grafana_data_dir.stat.gid == 472
        fail_msg: >
          Grafana data dir wrong UID. Expected 472:472,
          got {{ grafana_data_dir.stat.uid }}:{{ grafana_data_dir.stat.gid }}

    - name: Stat Grafana provisioning datasources directory
      ansible.builtin.stat:
        path: /opt/grafana/provisioning/datasources
      register: grafana_ds_dir

    - name: Assert Grafana datasources dir exists with UID 472
      ansible.builtin.assert:
        that:
          - grafana_ds_dir.stat.exists
          - grafana_ds_dir.stat.uid == 472
        fail_msg: "Grafana datasources dir missing or wrong UID"

    - name: Stat Grafana alerting directory
      ansible.builtin.stat:
        path: /opt/grafana/provisioning/alerting
      register: grafana_alert_dir

    - name: Assert Grafana alerting dir exists with UID 472
      ansible.builtin.assert:
        that:
          - grafana_alert_dir.stat.exists
          - grafana_alert_dir.stat.uid == 472
        fail_msg: "Grafana alerting dir missing or wrong UID"

    # --- Grafana alerting provisioning files ---
    - name: Stat Grafana contact-points.yaml
      ansible.builtin.stat:
        path: /opt/grafana/provisioning/alerting/contact-points.yaml
      register: contact_points

    - name: Assert contact-points.yaml is deployed
      ansible.builtin.assert:
        that:
          - contact_points.stat.exists
          - contact_points.stat.uid == 472
          - contact_points.stat.mode == '0644'
        fail_msg: "contact-points.yaml missing or wrong ownership"

    - name: Stat Grafana rules.yaml
      ansible.builtin.stat:
        path: /opt/grafana/provisioning/alerting/rules.yaml
      register: rules_yaml

    - name: Assert rules.yaml is deployed
      ansible.builtin.assert:
        that:
          - rules_yaml.stat.exists
          - rules_yaml.stat.uid == 472
          - rules_yaml.stat.mode == '0644'
        fail_msg: "rules.yaml missing or wrong ownership"

    # --- pve-exporter ---
    - name: Stat pve-exporter config directory
      ansible.builtin.stat:
        path: /opt/pve-exporter
      register: pve_dir

    - name: Assert pve-exporter config dir exists with correct UID
      ansible.builtin.assert:
        that:
          - pve_dir.stat.exists
          - pve_dir.stat.uid == 65534
          - pve_dir.stat.mode == '0755'
        fail_msg: "pve-exporter config dir missing or wrong UID"

    - name: Stat pve.yml credentials file
      ansible.builtin.stat:
        path: /opt/pve-exporter/pve.yml
      register: pve_credentials

    - name: Assert pve.yml is mode 0600 (credentials file)
      ansible.builtin.assert:
        that:
          - pve_credentials.stat.exists
          - pve_credentials.stat.mode == '0600'
        fail_msg: "pve.yml missing or has wrong mode (expected 0600 for credentials)"

    # --- python3-docker ---
    - name: Gather package facts
      ansible.builtin.package_facts:
        manager: apt

    - name: Assert python3-docker is installed
      ansible.builtin.assert:
        that:
          - "'python3-docker' in ansible_facts.packages"
        fail_msg: "python3-docker not installed by monitoring role"
```

- [ ] **Step 5: Create cleanup.yml**

```yaml
# roles/monitoring/molecule/default/cleanup.yml
---
- name: Cleanup
  hosts: all
  gather_facts: false
  tasks:
    - name: No cleanup required
      ansible.builtin.debug:
        msg: "Cleanup handled by molecule destroy"
```

- [ ] **Step 6: Commit**

```bash
git add roles/monitoring/molecule/
git commit -m "test(monitoring): add molecule default scenario"
```

---

## Task 8: Integration Scenario Stubs (All Four Roles)

Integration scenarios require Docker-in-Docker and are run manually. This task scaffolds the minimal files so `molecule test -s integration` has a valid entry point. Full assertions are left as TODO comments for future implementation.

**Files:**
- Create: `roles/cloudflare_ddns/molecule/integration/{molecule.yml,converge.yml,verify.yml}`
- Create: `roles/minecraft/molecule/integration/{molecule.yml,converge.yml,verify.yml}`
- Create: `roles/n8n/molecule/integration/{molecule.yml,converge.yml,verify.yml}`
- Create: `roles/monitoring/molecule/integration/{molecule.yml,converge.yml,verify.yml}`

- [ ] **Step 1: Create cloudflare_ddns integration scenario**

`roles/cloudflare_ddns/molecule/integration/molecule.yml`:
```yaml
---
# Integration scenario: requires Docker-in-Docker. Run manually with:
#   task molecule-integration -- ROLE=cloudflare_ddns
# Requires real or valid Doppler secrets.
role_name_check: 1
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2604-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /var/run/docker.sock:/var/run/docker.sock
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        ddns_image_version: "1"
        ddns_domains: "{{ lookup('env', 'DDNS_DOMAINS') }}"
        ddns_proxied: "false"
verifier:
  name: ansible
```

`roles/cloudflare_ddns/molecule/integration/converge.yml`:
```yaml
---
- name: Converge
  hosts: all
  gather_facts: true
  roles:
    - role: cloudflare_ddns
```

`roles/cloudflare_ddns/molecule/integration/verify.yml`:
```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Verify cloudflare-ddns container is running
      ansible.builtin.command:
        cmd: docker ps --filter name=cloudflare-ddns --format "{{ '{{' }}.Names{{ '}}' }}"
      register: container_status
      changed_when: false

    - name: Assert container is present
      ansible.builtin.assert:
        that:
          - "'cloudflare-ddns' in container_status.stdout"
        fail_msg: "cloudflare-ddns container is not running"
```

- [ ] **Step 2: Create minecraft integration scenario**

`roles/minecraft/molecule/integration/molecule.yml`:
```yaml
---
# Integration scenario: downloads real BDS binary. Requires internet access.
# Run manually: task molecule-integration -- ROLE=minecraft
role_name_check: 1
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2604-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        minecraft_install_dir: /opt/minecraft
        minecraft_bds_version: "1.21.2.1"
        minecraft_bds_download_url: "https://www.minecraft.net/en-us/download/server/bedrock"
        minecraft_operator_xuid: "1234567890123456"
        minecraft_update_weekday: "0"
        minecraft_update_hour: "3"
        minecraft_update_minute: "0"
        minecraft_server_name: "Integration Test Server"
        minecraft_gamemode: survival
        minecraft_difficulty: normal
        minecraft_max_players: 10
        minecraft_level_seed: ""
        minecraft_allow_cheats: "false"
        minecraft_online_mode: "false"
  env:
    MINECRAFT_OPERATOR_XUID: "1234567890123456"
verifier:
  name: ansible
```

`roles/minecraft/molecule/integration/converge.yml`:
```yaml
---
- name: Converge
  hosts: all
  gather_facts: true
  roles:
    - role: minecraft
```

`roles/minecraft/molecule/integration/verify.yml`:
```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Verify BDS binary is present
      ansible.builtin.stat:
        path: /opt/minecraft/bedrock_server
      register: bds_binary

    - name: Assert BDS binary exists and is executable
      ansible.builtin.assert:
        that:
          - bds_binary.stat.exists
          - bds_binary.stat.executable
        fail_msg: "BDS binary not found after install"

    - name: Verify version file matches requested version
      ansible.builtin.slurp:
        src: /opt/minecraft/.version
      register: installed_version

    - name: Assert installed version matches requested
      ansible.builtin.assert:
        that:
          - (installed_version.content | b64decode | trim) == "1.21.2.1"
        fail_msg: >
          Version file mismatch. Expected 1.21.2.1,
          got {{ installed_version.content | b64decode | trim }}
```

- [ ] **Step 3: Create n8n integration scenario**

`roles/n8n/molecule/integration/molecule.yml`:
```yaml
---
# Integration scenario: deploys real n8n container. Requires Docker socket.
# Run manually: task molecule-integration -- ROLE=n8n
role_name_check: 1
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2604-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /var/run/docker.sock:/var/run/docker.sock
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        n8n_data_path: /opt/n8n
        n8n_port: 5678
        n8n_host: localhost
        n8n_version: "1"
verifier:
  name: ansible
```

`roles/n8n/molecule/integration/converge.yml`:
```yaml
---
- name: Converge
  hosts: all
  gather_facts: true
  roles:
    - role: n8n
```

`roles/n8n/molecule/integration/verify.yml`:
```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Verify n8n container is running
      ansible.builtin.command:
        cmd: docker ps --filter name=n8n --format "{{ '{{' }}.Names{{ '}}' }}"
      register: container_status
      changed_when: false

    - name: Assert n8n container is present
      ansible.builtin.assert:
        that:
          - "'n8n' in container_status.stdout"
        fail_msg: "n8n container is not running"
```

- [ ] **Step 4: Create monitoring integration scenario**

`roles/monitoring/molecule/integration/molecule.yml`:
```yaml
---
# Integration scenario: deploys full monitoring stack. Requires Docker socket + real secrets.
# Run manually: task molecule-integration -- ROLE=monitoring
role_name_check: 1
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2604-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /var/run/docker.sock:/var/run/docker.sock
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        prometheus_version: "v3"
        prometheus_port: 9090
        prometheus_config_dir: /opt/prometheus/config
        prometheus_data_dir: /opt/prometheus/data
        prometheus_retention: 30d
        grafana_version: "13.0"
        grafana_port: 3000
        grafana_data_dir: /opt/grafana/data
        grafana_provisioning_dir: /opt/grafana/provisioning
        grafana_dashboards_dir: /opt/grafana/provisioning/dashboards
        grafana_alerting_dir: /opt/grafana/provisioning/alerting
        grafana_admin_password: "{{ lookup('env', 'GRAFANA_ADMIN_PASSWORD') }}"
        monitoring_network: monitoring
        cadvisor_version: "0.56"
        cadvisor_port: 8083
        pve_exporter_version: "3"
        pve_exporter_port: 9221
        pve_exporter_config_dir: /opt/pve-exporter
verifier:
  name: ansible
```

`roles/monitoring/molecule/integration/converge.yml`:
```yaml
---
- name: Converge
  hosts: all
  gather_facts: true
  roles:
    - role: monitoring
```

`roles/monitoring/molecule/integration/verify.yml`:
```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Verify Prometheus container is running
      ansible.builtin.command:
        cmd: docker ps --filter name=prometheus --format "{{ '{{' }}.Names{{ '}}' }}"
      register: prometheus_status
      changed_when: false

    - name: Assert Prometheus is running
      ansible.builtin.assert:
        that:
          - "'prometheus' in prometheus_status.stdout"
        fail_msg: "Prometheus container is not running"

    - name: Verify Grafana container is running
      ansible.builtin.command:
        cmd: docker ps --filter name=grafana --format "{{ '{{' }}.Names{{ '}}' }}"
      register: grafana_status
      changed_when: false

    - name: Assert Grafana is running
      ansible.builtin.assert:
        that:
          - "'grafana' in grafana_status.stdout"
        fail_msg: "Grafana container is not running"
```

- [ ] **Step 5: Commit all integration stubs**

```bash
git add roles/cloudflare_ddns/molecule/integration/ \
        roles/minecraft/molecule/integration/ \
        roles/n8n/molecule/integration/ \
        roles/monitoring/molecule/integration/
git commit -m "test: add molecule integration scenario stubs for all four roles"
```

---

## Task 9: Iteration Loop — cloudflare_ddns

Run `molecule test -s default` for cloudflare_ddns, parse failures, fix, re-run. Up to 10 iterations.

**Failure classification:**
- `TASK [name] ... FAILED` → identify whether it's a role task, a verify assertion, or a scenario config issue
- `changed` on second idempotency run → find the task that reported changed, make it idempotent
- `NEEDS_HUMAN` → flag if Docker daemon issues leak through or external API is called

- [ ] **Step 1: Run molecule test**

```bash
cd roles/cloudflare_ddns && molecule test -s default 2>&1 | tee /tmp/molecule-cloudflare-run1.txt
```

- [ ] **Step 2: Parse and classify failures**

Read `/tmp/molecule-cloudflare-run1.txt`. Look for:
- Lines matching `TASK \[.*\] \*+` followed by `fatal:` or `FAILED`
- Lines matching `PLAY RECAP` — check for `failed=` count
- Idempotency section: lines matching `The following tasks were not idempotent`

Classify each failure as `ROLE_BUG`, `TEST_BUG`, `CONFIG_BUG`, or `NEEDS_HUMAN`.

- [ ] **Step 3: Apply fixes based on classification, re-run**

Fix the identified issues in scenario files or role tasks. Re-run:

```bash
molecule test -s default 2>&1 | tee /tmp/molecule-cloudflare-run2.txt
```

Repeat up to 10 total iterations until `PLAY RECAP` shows `failed=0` and idempotency check passes.

- [ ] **Step 4: Record result**

Note the final iteration count and any fixes applied. These go in the hardening report (Task 12).

---

## Task 10: Iteration Loop — minecraft

- [ ] **Step 1: Run molecule test**

```bash
cd roles/minecraft && molecule test -s default 2>&1 | tee /tmp/molecule-minecraft-run1.txt
```

- [ ] **Step 2: Parse and classify failures**

Pay particular attention to:
- The silent-exit assertion: `Assert script produces output on bad input`
- The cron job assertion: `Assert minecraft-update cron job is present` (crontab location may differ — ansible cron module writes to `/var/spool/cron/crontabs/root` on Debian)
- Service file assertions: verify `Restart=on-failure` is in the actual template

If the cron check fails because `crontab -l -u root` returns non-zero (no crontab), adjust the assertion to check `/etc/cron.d/` as a fallback:

```yaml
- name: Check cron.d fallback
  ansible.builtin.find:
    paths: /etc/cron.d
    patterns: "minecraft*"
  register: cron_d_files
  when: root_crontab.rc != 0

- name: Assert cron job present (crontab or cron.d)
  ansible.builtin.assert:
    that:
      - "'minecraft-update' in root_crontab.stdout or cron_d_files.matched > 0"
    fail_msg: "minecraft-update cron job not found in crontab or /etc/cron.d"
```

- [ ] **Step 3: Apply fixes, re-run up to 10 iterations**

```bash
molecule test -s default 2>&1 | tee /tmp/molecule-minecraft-runN.txt
```

- [ ] **Step 4: Record result**

---

## Task 11: Iteration Loop — n8n

- [ ] **Step 1: Run molecule test**

```bash
cd roles/n8n && molecule test -s default 2>&1 | tee /tmp/molecule-n8n-run1.txt
```

- [ ] **Step 2: Parse and classify failures**

Primary watch: uid/gid assertions on `/opt/n8n`. The role creates the dir with `owner: "1000" group: "1000"` (string, not int). `stat` returns numeric uid. If molecule container doesn't have a user with uid 1000, the `stat` result will show uid=1000 but `pw_name` will be empty — adjust assertions to check uid directly rather than by username.

- [ ] **Step 3: Apply fixes, re-run up to 10 iterations**

- [ ] **Step 4: Record result**

---

## Task 12: Iteration Loop — monitoring

- [ ] **Step 1: Run molecule test**

```bash
cd roles/monitoring && molecule test -s default 2>&1 | tee /tmp/molecule-monitoring-run1.txt
```

- [ ] **Step 2: Parse and classify failures**

Watch for:
- `Verify pve-exporter credentials are set` assert — this uses `lookup('env', ...)` which reads the provisioner `env:` block. Verify the env var names match exactly: `PVE_TOKEN_ID`, `PVE_TOKEN_SECRET`.
- `Verify Grafana alerting secrets are set` — same pattern for `PUSHOVER_API_TOKEN`, `PUSHOVER_USER_KEY`.
- Prometheus config templating may fail if Jinja2 group loop references `groups['monitoring']` — the molecule inventory may not define this group. If so, add the group to molecule.yml's inventory.
- Dashboard copy tasks — ensure the dashboard JSON files exist in `roles/monitoring/files/` or `roles/monitoring/templates/`.

- [ ] **Step 3: Apply fixes, re-run up to 10 iterations**

- [ ] **Step 4: Record result**

---

## Task 13: Write Hardening Report

After all four iteration loops complete, write the final report.

**Files:**
- Create: `docs/molecule-hardening-report.md`

- [ ] **Step 1: Write report with actual results from the iteration loops**

Use this template, filling in actual values from the loop results:

```markdown
# Molecule Hardening Report — 2026-05-05

## Summary

| Role            | Scenario | Iterations | Result |
|-----------------|----------|------------|--------|
| cloudflare_ddns | default  | N          | ✅/❌  |
| minecraft       | default  | N          | ✅/❌  |
| n8n             | default  | N          | ✅/❌  |
| monitoring      | default  | N          | ✅/❌  |

## What Was Hardened

### cloudflare_ddns
[List specific fixes applied]

### minecraft
[List specific fixes applied, especially silent-exit findings]

### n8n
[List specific fixes applied]

### monitoring
[List specific fixes applied]

## Silent-Exit Findings

[Detail any unguarded grep calls found or confirmed safe]

## Scenarios Requiring Human Review

[List NEEDS_HUMAN entries with: failure message, why it can't be auto-fixed, recommended action]

## Integration Scenarios

All four roles have integration scenario stubs at `roles/<role>/molecule/integration/`.
These require Docker-in-Docker and (for cloudflare_ddns, monitoring) real Doppler secrets.
Run with: `doppler run -- task molecule-integration -- ROLE=<role>`
```

- [ ] **Step 2: Commit report and all remaining changes**

```bash
git add docs/molecule-hardening-report.md
git add roles/
git commit -m "test: molecule hardening complete — add scenarios and hardening report"
git push
```

---

## Self-Review Notes

- **Spec coverage check:** Infrastructure ✓, per-role two scenarios ✓, four coverage areas ✓, silent-exit bug testing ✓, iteration loop ✓, hardening report ✓
- **Known gap:** minecraft `minecraft_bds_version` and related vars may have different names in actual group_vars — iteration loop will surface this
- **Known gap:** monitoring Prometheus scrape config templates against `groups['monitoring']` — may need inventory adjustment in molecule.yml
- **Type consistency:** all file path vars (`n8n_data_path`, `prometheus_config_dir`, etc.) are set explicitly in each scenario's group_vars so no cross-task type drift
