# Media Processing Pipeline Design

**Date:** 2026-03-24
**Status:** Approved

## Overview

Add Lidarr and beets to the existing arr stack to create a semi-automated media processing pipeline for TV, movies, and music. Files dropped into per-category `unprocessed/` directories are renamed, tagged (music), and moved to organized library directories that Plex monitors.

---

## Directory Structure

All directories live under the TrueNAS NFS export `wayreth/data/media`, mounted at `/data/media` on the arr LXC. No new NFS shares are required.

```
/data/media/
  tv/                        ← Sonarr root folder — organized, Plex reads here
  movies/                    ← Radarr root folder — organized, Plex reads here
  music/                     ← Lidarr root folder — organized, Plex reads here
  books/                     ← Future Calibre (child dataset on TrueNAS)
  unprocessed/
    tv/                      ← Drop zone → Sonarr manual import UI
    movies/                  ← Drop zone → Radarr manual import UI
    music/                   ← Drop zone → beets processes here
    music-ready/             ← beets high-confidence output → Lidarr manual import UI
    music-review/            ← beets low-confidence leftovers → manual attention

/data/downloads/             ← Pre-existing; created by Ansible (arr role)
  incomplete/                ← qBittorrent active downloads
  complete/                  ← qBittorrent finished downloads (Sonarr/Radarr/Lidarr import from here)
```

---

## Components

### Existing (no changes to behavior)

| Service      | Port | Role                              |
| ------------ | ---- | --------------------------------- |
| Sonarr       | 8989 | TV library management             |
| Radarr       | 7878 | Movie library management          |
| Prowlarr     | 9696 | Indexer management                |
| qBittorrent  | 8080 | Download client (via Gluetun VPN) |
| Bazarr       | 6767 | Subtitle management               |
| Seerr        | 5055 | Request interface                 |
| Flaresolverr | 8191 | Cloudflare bypass                 |
| Watchtower   | —    | Container auto-updates            |
| Gluetun      | —    | ProtonVPN WireGuard gateway       |

### New

| Service | Image                                   | Port | Role                             |
| ------- | --------------------------------------- | ---- | -------------------------------- |
| Lidarr  | `lscr.io/linuxserver/lidarr:3.1.0`      | 8686 | Music library management         |
| Beets   | `lscr.io/linuxserver/beets:2.7.1-ls319` | —    | Music tag repair via MusicBrainz |

---

## Data Flow

### Music Pipeline

```
You drop files into unprocessed/music/
         ↓
  task beets-import (runs remotely on arr LXC)
         ↓
  beet import --quiet
  ┌──────────────────────────┬─────────────────────────┐
  │ High-confidence match    │ Low-confidence / no match│
  │ Tagged + moved to        │ Left in unprocessed/music│
  │ unprocessed/music-ready/ │ → swept to music-review/ │
  └──────────────────────────┴─────────────────────────┘
         ↓
  Lidarr manual import UI (http://arr.tlesh.xyz:8686)
  You review matches, correct any errors, confirm
         ↓
  music/  ←  Plex picks up here
```

### TV & Movies Pipeline

```
You drop files into unprocessed/tv/ or unprocessed/movies/
         ↓
  Sonarr or Radarr → Manual Import → point at unprocessed dir
  You review matches, correct any errors, confirm
         ↓
  tv/ or movies/  ←  Plex picks up here
```

---

## Ansible Changes

### `group_vars/arr.yml` (optional override)

`arr_lidarr_port` is defined in `roles/arr/defaults/main.yml` with default `8686`.
Only add an override in `group_vars/arr.yml` if you want Lidarr to listen on a non-default port, for example:

```yaml
arr_lidarr_port: 8868
```

### `roles/arr/defaults/main.yml`

Add config path entries for lidarr and beets.

### `roles/arr/tasks/directories.yml`

Add creation of:

- `/data/media/tv`, `/data/media/movies`, `/data/media/music`
- `/data/media/unprocessed/tv`, `movies`, `music`, `music-ready`, `music-review`
- `/opt/arr/config/lidarr`, `/opt/arr/config/beets`

### `roles/arr/templates/docker-compose.yml.j2`

Add `lidarr` and `beets` service blocks.

### `roles/arr/templates/beets-config.yml.j2`

New template deployed to `/opt/arr/config/beets/config.yaml`.

### `Taskfile.yml`

Add `beets-import` task (runs remotely via Ansible ad-hoc shell command).

---

## Beets Configuration

Deployed to `/opt/arr/config/beets/config.yaml`:

```yaml
directory: /data/media/unprocessed/music-ready
library: /config/musiclibrary.db

import:
  move: yes # move files (not copy) after tagging
  quiet: yes # auto-tag high-confidence, skip low-confidence silently
  log: /config/import.log

plugins: fetchart embedart
```

- `move: yes` — files are moved out of `unprocessed/music/` after successful tagging
- `quiet: yes` — unattended mode; low-confidence files are skipped (not moved), then swept to `music-review/` by the task
- `fetchart` / `embedart` — downloads and embeds album art

---

## Taskfile Addition

```yaml
beets-import:
  desc: Run beets music import on the arr host (tags high-confidence, sweeps rest to music-review)
  cmds:
    - >-
      doppler run -- ansible arr -b -m shell -a
      "docker exec beets beet import -q /data/media/unprocessed/music && find /data/media/unprocessed/music -mindepth 1 -maxdepth 1 -exec mv {} /data/media/unprocessed/music-review/ \; 2>/dev/null || true"
```

---

## Manual Setup Steps

Everything below is one-time configuration done through web UIs after `task arr` deploys the updated stack. All services are accessible at `arr.tlesh.xyz:<port>` (or via Tailscale).

---

### Step 1 — Prowlarr: Add Indexers

Prowlarr manages indexer configuration for Sonarr, Radarr, and Lidarr centrally.

1. Open Prowlarr at `http://arr.tlesh.xyz:9696`
2. **Indexers → Add Indexer** — add your preferred indexers (e.g. public trackers or private ones you use)
3. **Settings → Apps → Add Application**:
   - Add **Sonarr**: URL `http://sonarr:8989`, API key from Sonarr → Settings → General
   - Add **Radarr**: URL `http://radarr:7878`, API key from Radarr → Settings → General
   - Add **Lidarr**: URL `http://lidarr:8686`, API key from Lidarr → Settings → General
4. Click **Sync App Indexers** — Prowlarr pushes indexers to all three apps

---

### Step 2 — qBittorrent: Note the Credentials

1. Open qBittorrent at `http://arr.tlesh.xyz:8080`
2. Default credentials: `admin` / `adminadmin` — change these immediately
   - Tools → Options → Web UI → change username and password
3. **Tools → Options → Downloads**:
   - Default save path: `/data/downloads/incomplete`
   - Keep completed torrents in: `/data/downloads/complete`

---

### Step 3 — Sonarr: Initial Configuration

1. Open Sonarr at `http://arr.tlesh.xyz:8989`

**Download Client:**

- Settings → Download Clients → Add → qBittorrent
  - Host: `gluetun` (qBittorrent runs inside the gluetun network namespace — use the `gluetun` Docker service name, not `localhost` or `qbittorrent`)
  - Port: `8080`
  - Username/password from Step 2
  - Category: `sonarr`

**Root Folder:**

- Settings → Media Management → Root Folders → Add
  - Path: `/data/media/tv`

**Naming Convention** (Settings → Media Management → Episode Naming):

- Enable: "Rename Episodes"
- Recommended standard format: `{Series Title} - S{season:00}E{episode:00} - {Episode Title}`

**Manual Import for existing files:**

- Series → Manual Import → select `/data/media/unprocessed/tv`
- Sonarr scans, shows matches, you correct errors, click Import

---

### Step 4 — Radarr: Initial Configuration

1. Open Radarr at `http://arr.tlesh.xyz:7878`

**Download Client:**

- Settings → Download Clients → Add → qBittorrent
  - Host: `gluetun`, Port: `8080`, same credentials as Step 2, Category: `radarr`

**Root Folder:**

- Settings → Media Management → Root Folders → Add
  - Path: `/data/media/movies`

**Naming Convention** (Settings → Media Management → Movie Naming):

- Enable: "Rename Movies"
- Recommended: `{Movie Title} ({Release Year})`

**Manual Import for existing files:**

- Movies → Manual Import → select `/data/media/unprocessed/movies`

---

### Step 5 — Lidarr: Initial Configuration

1. Open Lidarr at `http://arr.tlesh.xyz:8686`

**Download Client:**

- Settings → Download Clients → Add → qBittorrent
  - Host: `gluetun`, Port: `8080`, same credentials as Step 2, Category: `lidarr`

**Root Folder:**

- Settings → Media Management → Root Folders → Add
  - Path: `/data/media/music`

**Naming Convention** (Settings → Media Management → Track Naming):

- Enable: "Rename Tracks"
- Recommended album folder: `{Artist Name}/{Album Title} ({Release Year})`
- Recommended track: `{track:00} - {Track Title}`

**MusicBrainz (optional but recommended for better matching):**

- Settings → General — Lidarr uses MusicBrainz automatically; no account needed
- For better acoustic fingerprinting, beets handles this separately

**Add existing artists (do this before attempting any import):**

- Artists → Add New — search for and add every artist you have music for
- Lidarr must know about an artist before it can match or import tracks for them; attempting a manual import for an artist that isn't added will return zero results
- Set monitoring to "All Albums" if you want Lidarr to track future releases

**Manual Import for beets-processed files:**

- Artists → Manual Import → select `/data/media/unprocessed/music-ready`
- Review matches, confirm, Lidarr moves files to `/data/media/music/`

---

### Step 6 — Beets: Verify Configuration

After `task arr` deploys the beets container:

1. SSH to arr or use `docker exec` to verify the config was deployed:
   ```bash
   docker exec beets cat /config/config.yaml
   ```
2. Test with a dry-run on a small batch (omit `-q` so you can see the output):

   ```bash
   docker exec beets beet import --pretend /data/media/unprocessed/music
   ```

   This shows what beets _would_ do without making changes.

3. Run the real import via:

   ```bash
   task beets-import
   ```

4. Check `music-ready/` for tagged files, `music-review/` for anything beets couldn't match.

---

### Step 7 — Plex: Add Libraries

1. Open Plex and go to Settings → Libraries → Add Library

**TV Shows:**

- Type: TV Shows
- Add folder: `/data/media/tv`

**Movies:**

- Type: Movies
- Add folder: `/data/media/movies`

**Music:**

- Type: Music
- Add folder: `/data/media/music`

Plex will scan and match metadata on first add. Enable automatic library updates so Plex picks up new files as Sonarr/Radarr/Lidarr move them in.

---

### Step 8 — Seerr: Connect to Sonarr & Radarr

> **Note:** Seerr (Overseerr) supports TV and movies only — there is no Lidarr integration. Music is managed by dropping files manually into the pipeline, not through Seerr.

1. Open Seerr at `http://arr.tlesh.xyz:5055`
2. Settings → Services → Add Radarr:
   - URL: `http://radarr:7878`, API key from Radarr
   - Root folder: `/data/media/movies`
3. Settings → Services → Add Sonarr:
   - URL: `http://sonarr:8989`, API key from Sonarr
   - Root folder: `/data/media/tv`

---

## Ongoing Workflow

### Dropping new music files

1. Copy files to `/data/media/unprocessed/music/` (via SCP, SMB, or NFS from your Mac)
2. Run `task beets-import` from your Mac
3. Open Lidarr → Artists → Manual Import → `unprocessed/music-ready/` → review & confirm
4. Check `music-review/` for anything that needs manual attention — fix filenames and re-drop

### Dropping new TV/movie files

1. Copy files to `unprocessed/tv/` or `unprocessed/movies/`
2. Open Sonarr or Radarr → Manual Import → select the unprocessed dir → review & confirm

### Music that beets can't match

Files in `music-review/` are ones beets wasn't confident about. Options:

- Rename the file to a cleaner format (`Artist - Album - Track Title.flac`) and re-run `task beets-import`
- Use MusicBrainz Picard (desktop app) to tag manually, then re-drop into `unprocessed/music/`
- Import directly into Lidarr via manual import if the files are already organized enough

---

## Dashboard & Monitoring

### Glance (automated via Ansible)

Lidarr is added to the Infrastructure page monitor widget in `roles/glance/templates/glance.yml.j2`. Beets has no web UI and is not added. Running `task glance` will deploy the update.

### Uptime Kuma (manual)

Uptime Kuma v2 uses an unofficial WebSocket API — not reliable enough to automate from Ansible. After deploying the arr stack, add Lidarr manually:

1. Open Uptime Kuma at `http://uptime-kuma.tlesh.xyz:3001`
2. Add Monitor → HTTP(s):
   - Name: `Lidarr`
   - URL: `http://<arr-ip>:8686`
   - Heartbeat interval: 60s

---

## No Terraform Changes Required

The arr LXC (VM 106, bupu) has 2 CPU / 6 GB RAM / 100 GB disk. Lidarr and beets are both lightweight containers — no resource changes needed.
