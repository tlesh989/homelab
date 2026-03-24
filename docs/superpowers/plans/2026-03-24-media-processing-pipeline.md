# Media Processing Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Lidarr and beets to the arr stack and create the directory structure for a semi-automated TV/movie/music processing pipeline.

**Architecture:** Two new Docker containers (Lidarr, beets) are added to the existing arr Docker Compose stack on LXC 106 (bupu). New `unprocessed/` drop-zone directories are created under the shared TrueNAS NFS mount. A `beets-import` Taskfile task triggers remote tag processing. Glance is updated in this PR with the Lidarr monitor entry.

**Tech Stack:** Ansible, Jinja2 templates, Docker Compose, beets (MusicBrainz), Lidarr (linuxserver)

---

## File Map

| File                                        | Action | What changes                                                      |
| ------------------------------------------- | ------ | ----------------------------------------------------------------- |
| `roles/arr/defaults/main.yml`               | Modify | Add `arr_lidarr_port` (all ports live here, not in group_vars)    |
| `roles/arr/tasks/directories.yml`           | Modify | Add media root dirs + unprocessed tree + lidarr/beets config dirs |
| `roles/arr/templates/beets-config.yml.j2`   | Create | beets `config.yaml` template                                      |
| `roles/arr/tasks/compose.yml`               | Modify | Add beets config deploy task                                      |
| `roles/arr/templates/docker-compose.yml.j2` | Modify | Add `lidarr` and `beets` service blocks                           |
| `Taskfile.yml`                              | Modify | Add `beets-import` task                                           |

---

## Task 1: Add Lidarr Port Variable

**Files:**

- Modify: `roles/arr/defaults/main.yml`

- [ ] **Step 1: Add `arr_lidarr_port` to defaults**

  In `roles/arr/defaults/main.yml`, add after `arr_flaresolverr_port`:

  ```yaml
  arr_lidarr_port: 8686
  ```

  Final ports block should read:

  ```yaml
  # Ports
  arr_qbittorrent_port: 8080
  arr_sonarr_port: 8989
  arr_radarr_port: 7878
  arr_prowlarr_port: 9696
  arr_bazarr_port: 6767
  arr_seerr_port: 5055
  arr_flaresolverr_port: 8191
  arr_lidarr_port: 8686
  ```

- [ ] **Step 2: Validate syntax**

  ```bash
  task syntax
  ```

  Expected: `playbook: main.yml` with no errors.

- [ ] **Step 3: Commit**

  ```bash
  git add roles/arr/defaults/main.yml
  git commit -m "feat(arr): add arr_lidarr_port default variable"
  ```

---

## Task 2: Add Directory Creation

**Files:**

- Modify: `roles/arr/tasks/directories.yml`

- [ ] **Step 1: Add media root dirs, unprocessed tree, and config dirs**

  Append to the existing config directories loop in `roles/arr/tasks/directories.yml`. The file currently has two tasks: download staging dirs and arr config dirs. Add two new tasks after the existing ones.

  Ensure this task file runs after `roles/arr/tasks/nfs.yml` in `roles/arr/tasks/main.yml` so directories are created on the mounted share (not hidden under the pre-mount local path).

  Note: do **not** add `become: true` — the existing tasks in this file omit it, and the NFS mount is accessible to the Ansible service account without privilege escalation.

  > **`books/` directory**: omitted intentionally — it will be a TrueNAS child dataset created manually when Calibre is set up later.

  ```yaml
  - name: Create media library root directories
    ansible.builtin.file:
      path: "{{ item }}"
      state: directory
      mode: "0755"
      owner: "{{ arr_puid }}"
      group: "{{ arr_pgid }}"
    loop:
      - "{{ arr_media_path }}/tv"
      - "{{ arr_media_path }}/movies"
      - "{{ arr_media_path }}/music"

  - name: Create unprocessed drop-zone directories
    ansible.builtin.file:
      path: "{{ item }}"
      state: directory
      mode: "0755"
      owner: "{{ arr_puid }}"
      group: "{{ arr_pgid }}"
    loop:
      - "{{ arr_media_path }}/unprocessed/tv"
      - "{{ arr_media_path }}/unprocessed/movies"
      - "{{ arr_media_path }}/unprocessed/music"
      - "{{ arr_media_path }}/unprocessed/music-ready"
      - "{{ arr_media_path }}/unprocessed/music-review"
  ```

  Also extend the existing arr config directories loop to include lidarr and beets:

  ```yaml
  - "{{ arr_config_path }}/lidarr"
  - "{{ arr_config_path }}/beets"
  ```

  The full updated config loop should end with:

  ```yaml
  loop:
    - "{{ arr_config_path }}/compose"
    - "{{ arr_config_path }}/gluetun"
    - "{{ arr_config_path }}/qbittorrent"
    - "{{ arr_config_path }}/sonarr"
    - "{{ arr_config_path }}/radarr"
    - "{{ arr_config_path }}/prowlarr"
    - "{{ arr_config_path }}/bazarr"
    - "{{ arr_config_path }}/seerr"
    - "{{ arr_config_path }}/lidarr"
    - "{{ arr_config_path }}/beets"
  ```

- [ ] **Step 2: Validate syntax**

  ```bash
  task syntax
  ```

  Expected: no errors.

- [ ] **Step 3: Dry-run check**

  ```bash
  task arr -- --check
  ```

  Expected: directories task shows `changed` for new paths, all others `ok`.

- [ ] **Step 4: Commit**

  ```bash
  git add roles/arr/tasks/directories.yml
  git commit -m "feat(arr): add media root, unprocessed, and lidarr/beets config dirs"
  ```

---

## Task 3: Create Beets Config Template and Deploy Task

**Files:**

- Create: `roles/arr/templates/beets-config.yml.j2`
- Modify: `roles/arr/tasks/compose.yml`

- [ ] **Step 1: Create the beets config template**

  Create `roles/arr/templates/beets-config.yml.j2`:

  ```yaml
  # Managed by Ansible — do not edit manually
  directory: /data/media/unprocessed/music-ready
  library: /config/musiclibrary.db

  import:
    move: yes
    quiet: yes
    log: /config/import.log

  plugins: fetchart embedart
  ```

- [ ] **Step 2: Add beets config deploy task to compose.yml**

  In `roles/arr/tasks/compose.yml`, add a new task **before** the `Deploy docker-compose.yml` task:

  ```yaml
  - name: Deploy beets config
    ansible.builtin.template:
      src: beets-config.yml.j2
      dest: "{{ arr_config_path }}/beets/config.yaml"
      mode: "0644"
      owner: "{{ arr_puid }}"
      group: "{{ arr_pgid }}"
    notify: restart arr stack
  ```

- [ ] **Step 3: Validate syntax**

  ```bash
  task syntax
  ```

  Expected: no errors.

- [ ] **Step 4: Dry-run check**

  ```bash
  task arr -- --check
  ```

  Expected: `Deploy beets config` shows `changed` (file doesn't exist yet).

- [ ] **Step 5: Commit**

  ```bash
  git add roles/arr/templates/beets-config.yml.j2 roles/arr/tasks/compose.yml
  git commit -m "feat(arr): add beets config template and deploy task"
  ```

---

## Task 4: Add Lidarr and Beets to Docker Compose

**Files:**

- Modify: `roles/arr/templates/docker-compose.yml.j2`

- [ ] **Step 1: Add lidarr service**

  In `roles/arr/templates/docker-compose.yml.j2`, add after the `bazarr` service block and before `seerr`:

  ```yaml
  lidarr:
    image: lscr.io/linuxserver/lidarr:3.1.0
    container_name: lidarr
    security_opt:
      - apparmor=unconfined
    environment:
      PUID: "{{ arr_puid }}"
      PGID: "{{ arr_pgid }}"
      TZ: "{{ arr_timezone }}"
    volumes:
      - "{{ arr_config_path }}/lidarr:/config"
      - "{{ arr_downloads_path }}:{{ arr_downloads_path }}"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    ports:
      - "{{ arr_lidarr_port }}:8686"
    restart: unless-stopped
  ```

- [ ] **Step 2: Add beets service**

  Add after the `lidarr` service block and before `seerr`:

  ```yaml
  beets:
    image: lscr.io/linuxserver/beets:2.7.1
    container_name: beets
    security_opt:
      - apparmor=unconfined
    environment:
      PUID: "{{ arr_puid }}"
      PGID: "{{ arr_pgid }}"
      TZ: "{{ arr_timezone }}"
    volumes:
      - "{{ arr_config_path }}/beets:/config"
      - "{{ arr_media_path }}:{{ arr_media_path }}"
    restart: unless-stopped
  ```

  Note: beets has no exposed ports — it is invoked via `docker exec` only.

- [ ] **Step 3: Validate syntax**

  ```bash
  task syntax
  ```

  Expected: no errors.

- [ ] **Step 4: Lint**

  ```bash
  task lint
  ```

  Expected: no errors or warnings.

- [ ] **Step 5: Dry-run check**

  ```bash
  task arr -- --check
  ```

  Expected: `Deploy docker-compose.yml` shows `changed`.

- [ ] **Step 6: Commit**

  ```bash
  git add roles/arr/templates/docker-compose.yml.j2
  git commit -m "feat(arr): add lidarr and beets containers to docker-compose"
  ```

---

## Task 5: Add beets-import to Taskfile

**Files:**

- Modify: `Taskfile.yml`

- [ ] **Step 1: Add beets-import task**

  In `Taskfile.yml`, add after the `arr` task.

  Note: this task calls `doppler run -- ansible` (the ad-hoc binary), **not** `ansible-playbook`. This is intentional — it runs a single shell command on the remote host rather than a playbook. All other tasks in this file use `ansible-playbook`; this one is the exception.

  ```yaml
  beets-import:
    desc: Run beets music import on the arr host (tags high-confidence, sweeps rest to music-review)
    cmds:
      - >-
        doppler run -- ansible arr -b -m shell -a
        "docker exec beets beet import -q /data/media/unprocessed/music && (find /data/media/unprocessed/music -mindepth 1 -maxdepth 1 -exec mv {} /data/media/unprocessed/music-review/ \; 2>/dev/null || true)"
  ```

- [ ] **Step 2: Verify task appears in task list**

  ```bash
  task --list-all
  ```

  Expected: `beets-import` appears with its description.

- [ ] **Step 3: Commit**

  ```bash
  git add Taskfile.yml
  git commit -m "feat: add beets-import task for remote music tagging"
  ```

---

## Task 6: Deploy and Verify

- [ ] **Step 1: Final lint pass**

  ```bash
  task lint
  ```

  Expected: clean.

- [ ] **Step 2: Final dry-run**

  ```bash
  task arr -- --check
  ```

  Review all `changed` items — should only be the new directories, beets config, and docker-compose. No unexpected changes.

- [ ] **Step 3: Deploy arr stack**

  ```bash
  task arr
  ```

  Expected: all tasks complete, stack restarts with lidarr and beets added.

- [ ] **Step 4: Verify containers are running on arr host**

  ```bash
  doppler run -- ansible arr -b -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}'"
  ```

  Expected: `lidarr` and `beets` appear with `Up` status alongside existing containers.

- [ ] **Step 5: Verify beets config was deployed**

  ```bash
  doppler run -- ansible arr -b -m shell -a "docker exec beets cat /config/config.yaml"
  ```

  Expected: config matches the template (directory, library, import settings, plugins).

- [ ] **Step 6: Verify new directories exist on NFS mount**

  ```bash
  doppler run -- ansible arr -b -m shell -a "ls /data/media/ && ls /data/media/unprocessed/"
  ```

  Expected: `tv movies music unprocessed` under `/data/media/`, `tv movies music music-ready music-review` under `unprocessed/`.

- [ ] **Step 7: Verify Lidarr is reachable**

  Open `http://arr.tlesh.xyz:8686` in a browser.
  Expected: Lidarr UI loads.

- [ ] **Step 8: Deploy Glance update**

  ```bash
  task glance
  ```

  Expected: Lidarr tile appears on the Infrastructure page.

- [ ] **Step 9: Open PR**

  ```bash
  /ship "feat: add Lidarr and beets to arr stack with media processing pipeline"
  ```

---

## Post-Deploy: Manual Configuration

After the deploy is confirmed working, follow the manual setup steps in the spec doc:
`docs/superpowers/specs/2026-03-24-media-processing-pipeline-design.md`

Order:

1. Prowlarr — add indexers, connect Sonarr/Radarr/Lidarr as apps
2. qBittorrent — change default credentials, set download paths
3. Sonarr — add download client (`gluetun:8080`), root folder, naming format
4. Radarr — same as Sonarr
5. Lidarr — add download client, root folder, naming format, **add artists before importing**
6. Beets — verify config, run `--pretend` dry-run, then `task beets-import`
7. Plex — add TV, Movies, Music libraries
8. Seerr — connect Sonarr and Radarr (no Lidarr integration exists)
9. Uptime Kuma — manually add Lidarr HTTP monitor on port 8686
