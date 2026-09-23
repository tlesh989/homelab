# AutoKuma Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every web-UI Docker service in this repo gets its Uptime Kuma monitor created and removed automatically from its own docker-compose labels, instead of a manual UI step that drifts.

**Architecture:** A new `roles/autokuma` role deploys one AutoKuma container per Docker host (kaz, arr, tdarr_node, uptime-kuma), each reading its own local `docker.sock` and pushing monitor state to the central Uptime Kuma server. Every existing web-UI container across those hosts gets a `kuma.*` label block added to its existing docker-compose/`docker_container` definition.

**Tech Stack:** Ansible (community.docker collection), Docker Compose (Jinja2 templates), AutoKuma (`ghcr.io/bigboot/autokuma`), Uptime Kuma 2.x.

**Spec:** `docs/superpowers/specs/2026-09-22-autokuma-design.md`

## Global Constraints

- Pin `autokuma_version` to an exact release tag (`2.0.0` — required for Uptime Kuma v2 compatibility, this repo runs `louislam/uptime-kuma:2`, not `latest`), per `.claude/rules/docker.md`.
- Every `kuma.*` label URL is `http://{{ ansible_host }}:<port>` — each compose file is rendered on the host it describes, so the bare `ansible_host` fact (already set via the `hosts` inventory file) is correct without a `hostvars[...]` lookup. Only `roles/autokuma/defaults/main.yml` needs a cross-host `hostvars['uptime-kuma.tlesh.xyz']` lookup, since it points *at* the central Kuma server from every other host.
- Monitor `<id>` = container name (already unique per role).
- Background-only containers get **no labels at all**: `gluetun`, `watchtower` (every host), `dozzle-agent`, `beszel-agent`, `cloudflare_ddns`, `filebot`, `flaresolverr`, `bookorbit-db`, `tdarr-node` (the arr-side worker, no published UI port), `hbbs`/`hbbr` (rustdesk — no web UI), and `autokuma` itself.
- `AUTOKUMA_USERNAME`/`AUTOKUMA_PASSWORD` (your existing Kuma admin login) must be added to Doppler before first deploy — this is a manual pre-step, not part of any task below.
- Verification for every task in this plan is `task syntax && task lint` (this repo's established Definition of Done for Ansible changes — there is no unit-test framework for YAML/Jinja2 infra) plus, where noted, `task check` dry-run.

---

### Task 1: `roles/autokuma` role + wire it into all four hosts

**Files:**
- Create: `roles/autokuma/defaults/main.yml`
- Create: `roles/autokuma/tasks/main.yml`
- Modify: `main.yml:122-137` (kaz play), `main.yml:153-155` (arr play), `main.yml:159-164` (tdarr_node play), `main.yml:195-196` (uptime-kuma play)

**Interfaces:**
- Produces: an `autokuma` Docker container on each of kaz, arr, tdarr_node, uptime-kuma, watching that host's `docker.sock` and authenticated against the central Kuma server. Later tasks depend on this being live before their labels have any effect (though label tasks are safe to apply in any order — AutoKuma reconciles on Docker events whenever it's running).

- [ ] **Step 1: Create `roles/autokuma/defaults/main.yml`**

```yaml
---
# renovate: datasource=docker depName=ghcr.io/bigboot/autokuma
autokuma_version: "2.0.0"

# Routed through Caddy's HTTPS endpoint (same pattern as every other
# password-authenticated service in this repo, e.g. bookorbit_host) rather
# than a direct http://<ip>:3001 connection, since AUTOKUMA_USERNAME/
# PASSWORD would otherwise cross the LAN in cleartext.
autokuma_kuma_url: "https://uptime-kuma.tlesh.xyz"

# Persistent storage for AutoKuma's id-to-monitor mapping, required since
# v1.0.0 — without it, every container recreate (Watchtower update,
# redeploy) loses the mapping and creates duplicate monitors.
autokuma_data_dir: /opt/autokuma
```

- [ ] **Step 2: Create `roles/autokuma/tasks/main.yml`**

```yaml
---
- name: Install Docker Python SDK
  ansible.builtin.package:
    name: python3-docker
    state: present
  become: true

- name: Create AutoKuma data directory
  ansible.builtin.file:
    path: "{{ autokuma_data_dir }}"
    state: directory
    mode: "0755"
  become: true

- name: Assert AutoKuma credentials are set
  ansible.builtin.assert:
    that:
      - lookup('env', 'AUTOKUMA_USERNAME') | length > 0
      - lookup('env', 'AUTOKUMA_PASSWORD') | length > 0
    fail_msg: "AUTOKUMA_USERNAME and AUTOKUMA_PASSWORD must be set via Doppler."
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))

- name: Deploy AutoKuma container
  community.docker.docker_container:
    name: autokuma
    image: "ghcr.io/bigboot/autokuma:{{ autokuma_version }}"
    state: started
    restart_policy: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - "{{ autokuma_data_dir }}:/data"
    env:
      AUTOKUMA__KUMA__URL: "{{ autokuma_kuma_url }}"
      AUTOKUMA__KUMA__USERNAME: "{{ lookup('env', 'AUTOKUMA_USERNAME') }}"
      AUTOKUMA__KUMA__PASSWORD: "{{ lookup('env', 'AUTOKUMA_PASSWORD') }}"
  become: true
  no_log: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

- [ ] **Step 3: Add `autokuma` to the kaz play in `main.yml`**

Find (`main.yml:122-128`):

```yaml
  roles:
    - role: users
    - role: geerlingguy.ntp
    - role: geerlingguy.docker
    - role: artis3n.tailscale.machine
      when: not ansible_check_mode
    - role: watchtower
    - role: glance
```

Replace with:

```yaml
  roles:
    - role: users
    - role: geerlingguy.ntp
    - role: geerlingguy.docker
    - role: artis3n.tailscale.machine
      when: not ansible_check_mode
    - role: autokuma
    - role: watchtower
    - role: glance
```

- [ ] **Step 4: Add `autokuma` to the arr play in `main.yml`**

Find (`main.yml:150-155`):

```yaml
- name: setup arr stack
  hosts: arr
  become: true
  roles:
    - role: geerlingguy.docker
    - role: arr
```

Replace with:

```yaml
- name: setup arr stack
  hosts: arr
  become: true
  roles:
    - role: geerlingguy.docker
    - role: autokuma
    - role: arr
```

- [ ] **Step 5: Add `autokuma` to the tdarr_node play in `main.yml`**

Find (`main.yml:157-164`):

```yaml
- name: setup tdarr transcode node
  hosts: tdarr_node
  become: true
  roles:
    - role: users
    - role: geerlingguy.ntp
    - role: geerlingguy.docker
    - role: tdarr_node
```

Replace with:

```yaml
- name: setup tdarr transcode node
  hosts: tdarr_node
  become: true
  roles:
    - role: users
    - role: geerlingguy.ntp
    - role: geerlingguy.docker
    - role: autokuma
    - role: tdarr_node
```

- [ ] **Step 6: Add `autokuma` to the uptime-kuma play in `main.yml`**

Find (`main.yml:192-196`):

```yaml
- name: setup uptime-kuma server
  hosts: uptime-kuma
  become: true
  roles:
    - role: uptime_kuma
```

Replace with:

```yaml
- name: setup uptime-kuma server
  hosts: uptime-kuma
  become: true
  roles:
    - role: autokuma
    - role: uptime_kuma
```

- [ ] **Step 7: Validate**

Run: `task syntax && task lint`
Expected: both pass with no errors. (`task check` requires live hosts/Doppler and is exercised at actual deploy time, not in this plan.)

- [ ] **Step 8: Commit**

```bash
git add roles/autokuma main.yml
git commit -m "feat: add AutoKuma role for automated Uptime Kuma monitor management"
```

---

### Task 2: Label the arr stack

**Files:**
- Modify: `roles/arr/templates/docker-compose.yml.j2`

**Interfaces:**
- Consumes: nothing from Task 1 (labels are inert without AutoKuma running, but syntactically independent).
- Produces: nothing consumed by later tasks — this is the last task that touches `roles/arr`.

Add a `labels:` block to each of qbittorrent, sonarr, radarr, prowlarr, bazarr, lidarr, beets, tdarr-server, and seerr. Skip gluetun, filebot, flaresolverr, watchtower (no web UI / background-only).

- [ ] **Step 1: Label qbittorrent**

Find:

```yaml
    volumes:
      - "{{ arr_config_path }}/qbittorrent:/config"
      - "{{ arr_downloads_path }}:{{ arr_downloads_path }}"
      - "{{ arr_media_path }}/books:{{ arr_media_path }}/books"
    depends_on:
      - gluetun
    restart: unless-stopped
```

Replace with:

```yaml
    volumes:
      - "{{ arr_config_path }}/qbittorrent:/config"
      - "{{ arr_downloads_path }}:{{ arr_downloads_path }}"
      - "{{ arr_media_path }}/books:{{ arr_media_path }}/books"
    labels:
      kuma.qbittorrent.http.name: "qBittorrent"
      kuma.qbittorrent.http.url: "http://{{ ansible_host }}:{{ arr_qbittorrent_port }}"
    depends_on:
      - gluetun
    restart: unless-stopped
```

- [ ] **Step 2: Label sonarr**

Find:

```yaml
    volumes:
      - "{{ arr_config_path }}/sonarr:/config"
      - "{{ arr_downloads_path }}:{{ arr_downloads_path }}"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_sonarr_port }}:8989"
    restart: unless-stopped
```

Replace with:

```yaml
    volumes:
      - "{{ arr_config_path }}/sonarr:/config"
      - "{{ arr_downloads_path }}:{{ arr_downloads_path }}"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_sonarr_port }}:8989"
    labels:
      kuma.sonarr.http.name: "Sonarr"
      kuma.sonarr.http.url: "http://{{ ansible_host }}:{{ arr_sonarr_port }}"
    restart: unless-stopped
```

- [ ] **Step 3: Label radarr**

Find:

```yaml
    volumes:
      - "{{ arr_config_path }}/radarr:/config"
      - "{{ arr_downloads_path }}:{{ arr_downloads_path }}"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_radarr_port }}:7878"
    restart: unless-stopped
```

Replace with:

```yaml
    volumes:
      - "{{ arr_config_path }}/radarr:/config"
      - "{{ arr_downloads_path }}:{{ arr_downloads_path }}"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_radarr_port }}:7878"
    labels:
      kuma.radarr.http.name: "Radarr"
      kuma.radarr.http.url: "http://{{ ansible_host }}:{{ arr_radarr_port }}"
    restart: unless-stopped
```

- [ ] **Step 4: Label prowlarr**

Find:

```yaml
    volumes:
      - "{{ arr_config_path }}/prowlarr:/config"
    ports:
      - "{{ arr_prowlarr_port }}:9696"
    restart: unless-stopped
```

Replace with:

```yaml
    volumes:
      - "{{ arr_config_path }}/prowlarr:/config"
    ports:
      - "{{ arr_prowlarr_port }}:9696"
    labels:
      kuma.prowlarr.http.name: "Prowlarr"
      kuma.prowlarr.http.url: "http://{{ ansible_host }}:{{ arr_prowlarr_port }}"
    restart: unless-stopped
```

- [ ] **Step 5: Label bazarr**

Find:

```yaml
    volumes:
      - "{{ arr_config_path }}/bazarr:/config"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_bazarr_port }}:6767"
    restart: unless-stopped
```

Replace with:

```yaml
    volumes:
      - "{{ arr_config_path }}/bazarr:/config"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_bazarr_port }}:6767"
    labels:
      kuma.bazarr.http.name: "Bazarr"
      kuma.bazarr.http.url: "http://{{ ansible_host }}:{{ arr_bazarr_port }}"
    restart: unless-stopped
```

- [ ] **Step 6: Label lidarr**

Find:

```yaml
    volumes:
      - "{{ arr_config_path }}/lidarr:/config"
      - "{{ arr_downloads_path }}:{{ arr_downloads_path }}"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_lidarr_port }}:8686"
    restart: unless-stopped
```

Replace with:

```yaml
    volumes:
      - "{{ arr_config_path }}/lidarr:/config"
      - "{{ arr_downloads_path }}:{{ arr_downloads_path }}"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_lidarr_port }}:8686"
    labels:
      kuma.lidarr.http.name: "Lidarr"
      kuma.lidarr.http.url: "http://{{ ansible_host }}:{{ arr_lidarr_port }}"
    restart: unless-stopped
```

- [ ] **Step 7: Label beets**

Find:

```yaml
    volumes:
      - "{{ arr_config_path }}/beets:/config"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_beets_port }}:{{ arr_beets_port }}"
    restart: unless-stopped
```

Replace with:

```yaml
    volumes:
      - "{{ arr_config_path }}/beets:/config"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_beets_port }}:{{ arr_beets_port }}"
    labels:
      kuma.beets.http.name: "Beets"
      kuma.beets.http.url: "http://{{ ansible_host }}:{{ arr_beets_port }}"
    restart: unless-stopped
```

- [ ] **Step 8: Label tdarr-server**

Find:

```yaml
    ports:
      - "{{ arr_tdarr_webui_port }}:{{ arr_tdarr_webui_port }}"
      - "{{ arr_tdarr_server_port }}:{{ arr_tdarr_server_port }}"
    restart: unless-stopped

  seerr:
```

Replace with:

```yaml
    ports:
      - "{{ arr_tdarr_webui_port }}:{{ arr_tdarr_webui_port }}"
      - "{{ arr_tdarr_server_port }}:{{ arr_tdarr_server_port }}"
    labels:
      kuma.tdarr-server.http.name: "Tdarr"
      kuma.tdarr-server.http.url: "http://{{ ansible_host }}:{{ arr_tdarr_webui_port }}"
    restart: unless-stopped

  seerr:
```

- [ ] **Step 9: Label seerr**

Find:

```yaml
    volumes:
      - "{{ arr_config_path }}/seerr:/app/config"
    ports:
      - "{{ arr_seerr_port }}:5055"
    restart: unless-stopped
```

Replace with:

```yaml
    volumes:
      - "{{ arr_config_path }}/seerr:/app/config"
    ports:
      - "{{ arr_seerr_port }}:5055"
    labels:
      kuma.seerr.http.name: "Seerr"
      kuma.seerr.http.url: "http://{{ ansible_host }}:{{ arr_seerr_port }}"
    restart: unless-stopped
```

- [ ] **Step 10: Validate**

Run: `task syntax && task lint`
Expected: both pass.

- [ ] **Step 11: Commit**

```bash
git add roles/arr/templates/docker-compose.yml.j2
git commit -m "feat(arr): add AutoKuma labels to web-UI containers"
```

---

### Task 3: Label bookorbit, uptime-kuma, and the standalone kaz services

**Files:**
- Modify: `roles/bookorbit/tasks/main.yml`
- Modify: `roles/uptime_kuma/templates/docker-compose.yml.j2`
- Modify: `roles/n8n/tasks/main.yml`
- Modify: `roles/freshrss/tasks/main.yml`
- Modify: `roles/wallos/tasks/main.yml`
- Modify: `roles/syncthing/tasks/main.yml`
- Modify: `roles/dozzle_hub/tasks/main.yml`
- Modify: `roles/beszel/tasks/hub.yml`

**Interfaces:**
- Consumes: nothing from Task 1/2.
- Produces: nothing consumed by later tasks.

Every remaining in-scope web-UI service, in one task since each edit is the same mechanical shape (add a `labels:` dict to an existing `docker_container`/compose service block).

- [ ] **Step 1: Label bookorbit-app**

In `roles/bookorbit/tasks/main.yml`, find:

```yaml
      JWT_SECRET: "{{ lookup('env', 'BOOKORBIT_JWT_SECRET') }}"
      SETUP_BOOTSTRAP_TOKEN: "{{ lookup('env', 'BOOKORBIT_SETUP_BOOTSTRAP_TOKEN') }}"
      APP_URL: "https://{{ bookorbit_host }}"
      TZ: "{{ bookorbit_timezone }}"
      PUID: "{{ bookorbit_puid }}"
      PGID: "{{ bookorbit_pgid }}"
  become: true
  no_log: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

Replace with:

```yaml
      JWT_SECRET: "{{ lookup('env', 'BOOKORBIT_JWT_SECRET') }}"
      SETUP_BOOTSTRAP_TOKEN: "{{ lookup('env', 'BOOKORBIT_SETUP_BOOTSTRAP_TOKEN') }}"
      APP_URL: "https://{{ bookorbit_host }}"
      TZ: "{{ bookorbit_timezone }}"
      PUID: "{{ bookorbit_puid }}"
      PGID: "{{ bookorbit_pgid }}"
    labels:
      kuma.bookorbit-app.http.name: "BookOrbit"
      kuma.bookorbit-app.http.url: "http://{{ ansible_host }}:{{ bookorbit_port }}"
  become: true
  no_log: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

(This is the *last* `env:` block in the file — `bookorbit-db`'s task above it is unrelated and stays untouched; it has no web UI.)

- [ ] **Step 2: Label uptime-kuma itself**

In `roles/uptime_kuma/templates/docker-compose.yml.j2`, find:

```yaml
    volumes:
      - "{{ uptime_kuma_data_path }}:/app/data"
    ports:
      - "{{ uptime_kuma_port }}:3001"
    restart: unless-stopped
```

Replace with:

```yaml
    volumes:
      - "{{ uptime_kuma_data_path }}:/app/data"
    ports:
      - "{{ uptime_kuma_port }}:3001"
    labels:
      kuma.uptime-kuma.http.name: "Uptime Kuma"
      kuma.uptime-kuma.http.url: "http://{{ ansible_host }}:{{ uptime_kuma_port }}"
    restart: unless-stopped
```

(This role also runs on `barlo`, which has no AutoKuma instance and is currently offline/excluded from inventory — the label is inert there with no monitor created, and self-corrects via `ansible_host` if barlo returns and gets AutoKuma later.)

- [ ] **Step 3: Label n8n**

In `roles/n8n/tasks/main.yml`, find:

```yaml
      N8N_BLOCK_ENV_ACCESS_IN_NODE: "false"
      N8N_GIT_NODE_DISABLE_BARE_REPOS: "true"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

Replace with:

```yaml
      N8N_BLOCK_ENV_ACCESS_IN_NODE: "false"
      N8N_GIT_NODE_DISABLE_BARE_REPOS: "true"
    labels:
      kuma.n8n.http.name: "n8n"
      kuma.n8n.http.url: "http://{{ ansible_host }}:{{ n8n_port }}"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

- [ ] **Step 4: Label freshrss**

In `roles/freshrss/tasks/main.yml`, find:

```yaml
    env:
      TZ: "America/New_York"
      CRON_MIN: "*/15"
      FRESHRSS_ENV: "production"
  become: true
  when: not ansible_check_mode
```

Replace with:

```yaml
    env:
      TZ: "America/New_York"
      CRON_MIN: "*/15"
      FRESHRSS_ENV: "production"
    labels:
      kuma.freshrss.http.name: "FreshRSS"
      kuma.freshrss.http.url: "http://{{ ansible_host }}:{{ freshrss_port }}"
  become: true
  when: not ansible_check_mode
```

- [ ] **Step 5: Label wallos**

In `roles/wallos/tasks/main.yml`, find:

```yaml
    env:
      TZ: "{{ wallos_timezone }}"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

Replace with:

```yaml
    env:
      TZ: "{{ wallos_timezone }}"
    labels:
      kuma.wallos.http.name: "Wallos"
      kuma.wallos.http.url: "http://{{ ansible_host }}:{{ wallos_port }}"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

- [ ] **Step 6: Label syncthing**

In `roles/syncthing/tasks/main.yml`, find:

```yaml
    command:
      - "--gui-address=0.0.0.0:{{ syncthing_gui_port }}"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

Replace with:

```yaml
    command:
      - "--gui-address=0.0.0.0:{{ syncthing_gui_port }}"
    labels:
      kuma.syncthing.http.name: "Syncthing"
      kuma.syncthing.http.url: "http://{{ ansible_host }}:{{ syncthing_gui_port }}"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

(This is the last `docker_container` task in the file — the earlier `docker run` config-generation step above it stays untouched.)

- [ ] **Step 7: Label dozzle_hub**

In `roles/dozzle_hub/tasks/main.yml`, find:

```yaml
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "{{ dozzle_hub_data_dir }}:/data"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

Replace with:

```yaml
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "{{ dozzle_hub_data_dir }}:/data"
    labels:
      kuma.dozzle.http.name: "Dozzle"
      kuma.dozzle.http.url: "http://{{ ansible_host }}:{{ dozzle_hub_port }}"
  become: true
  when:
    - not ansible_check_mode
    - not (molecule_testing | default(false))
```

- [ ] **Step 8: Label the Beszel hub**

In `roles/beszel/tasks/hub.yml`, find:

```yaml
    volumes:
      - "{{ beszel_data_dir }}:/beszel_data"
    env:
      APP_URL: "http://{{ beszel_hub_hostname }}:{{ beszel_hub_port | string }}"
  become: true

- name: Deploy Beszel agent container on hub host
```

Replace with:

```yaml
    volumes:
      - "{{ beszel_data_dir }}:/beszel_data"
    env:
      APP_URL: "http://{{ beszel_hub_hostname }}:{{ beszel_hub_port | string }}"
    labels:
      kuma.beszel.http.name: "Beszel"
      kuma.beszel.http.url: "http://{{ ansible_host }}:{{ beszel_hub_port }}"
  become: true

- name: Deploy Beszel agent container on hub host
```

(`beszel-agent`, the second task in this file, stays untouched — background-only, no web UI.)

- [ ] **Step 9: Validate**

Run: `task syntax && task lint`
Expected: both pass.

- [ ] **Step 10: Commit**

```bash
git add roles/bookorbit/tasks/main.yml roles/uptime_kuma/templates/docker-compose.yml.j2 roles/n8n/tasks/main.yml roles/freshrss/tasks/main.yml roles/wallos/tasks/main.yml roles/syncthing/tasks/main.yml roles/dozzle_hub/tasks/main.yml roles/beszel/tasks/hub.yml
git commit -m "feat: add AutoKuma labels to remaining web-UI services"
```

---

## After implementation

- `task check` dry-run across all four hosts before merging (needs Doppler + live hosts, not exercised in this plan).
- Manual pre-deploy step (you): add `AUTOKUMA_USERNAME`/`AUTOKUMA_PASSWORD` to Doppler with your existing Kuma admin credentials.
- After deploy: verify each `autokuma` container logs a successful Kuma login, confirm monitors appear in the Kuma UI for one service per host, then remove one label from a test service and confirm AutoKuma deletes its monitor (per the spec's Testing section).
