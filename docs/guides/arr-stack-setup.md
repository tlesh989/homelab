# Arr Stack Manual Setup Guide

This guide covers every one-time configuration step required after `task arr` deploys the stack, explains how the download-to-Plex pipeline works end-to-end, and answers how qBittorrent seeding, file movement, and automation all fit together.

All services are accessible at `arr.tlesh.xyz:<port>` over Tailscale.

---

## How the Pipeline Works

Before diving into setup steps, here's the full picture so the individual settings make sense.

### Download pipeline (Sonarr / Radarr / Lidarr initiated)

```text
Seerr request  ──OR──  you add item directly in Sonarr/Radarr/Lidarr
         ↓
Prowlarr finds a release, passes torrent to qBittorrent
         ↓
qBittorrent downloads → /data/downloads/incomplete/   (local LXC disk)
         ↓  (download finishes)
File moves to /data/downloads/complete/<category>/    (still local disk)
         ↓  (arr app detects completion via API polling)
Sonarr/Radarr/Lidarr COPIES the file to /data/media/tv|movies|music/  (NFS)
         ↓
File is renamed and organized in the NFS library
         ↓
Plex detects new file (library auto-scan) → adds to library
         ↓
qBittorrent continues seeding from /data/downloads/complete/
until ratio ≥ 2  OR  seeding time ≥ 48 hours, whichever comes first
         ↓
qBittorrent auto-stops torrent; arr app removes it and deletes local file
```

**Key point:** `/data/downloads` is on the local 100 GB LXC disk; `/data/media` is the TrueNAS NFS mount. Because they're different filesystems, hardlinking is not possible — arr apps always **copy** when importing from downloads. The original file stays in downloads while seeding continues.

### Manual import pipeline (files you drop in yourself)

```text
You copy files to /data/media/unprocessed/tv|movies|music/  (NFS — accessible from Mac)
         ↓
For TV/Movies: Open Sonarr or Radarr → Manual Import → select the unprocessed dir
For Music:     Run `task beets-import` first (see Step 6), then Lidarr → Manual Import
         ↓
Arr app moves/renames files to /data/media/tv|movies|music/
         ↓
Plex picks up files
```

---

## Step 1 — qBittorrent: Initial Configuration

Open qBittorrent at `http://arr.tlesh.xyz:8080`.

### Change credentials

Default: `admin` / `adminadmin` — change immediately.

- **Tools → Options → Web UI** → update username and password
- Save the credentials somewhere safe — Sonarr, Radarr, and Lidarr all need them.

### Configure download directories

**Tools → Options → Downloads:**

| Setting | Value |
|---------|-------|
| Default save path | `/data/downloads/complete` |
| Keep incomplete torrents in | `/data/downloads/incomplete` |
| Default Torrent Management Mode | `Automatic` |

Enable: **"Keep incomplete torrents in:"** and set it to `/data/downloads/incomplete`.

This ensures actively-downloading files stay in `incomplete/` and are moved to `complete/` only when 100% done. In qBittorrent 4.6+ the old "Move completed downloads to:" field is gone — setting the **Default save path** to `complete/` with **Automatic** torrent management achieves the same result.

### Configure seeding limits

**Tools → Options → BitTorrent** (the seeding behavior section):

| Setting | Value |
|---------|-------|
| Seeding goals — Share ratio limit | `2.0` |
| Seeding goals — Seeding time limit | `2880` minutes (= 48 hours) |
| Condition | **"then"** → select **Stop torrent** |

Check **both** boxes so the rule fires on whichever limit is reached first (ratio ≥ 2 **or** 48 hours, not and). Set the action to **"Stop torrent"** — this signals to the arr apps that seeding is done, which triggers them to clean up the download.

> **Why "Stop" and not "Remove"?**
> The arr apps (Sonarr/Radarr/Lidarr) poll qBittorrent and handle removal themselves. Setting qBittorrent to "Remove" can race with the arr app's cleanup logic and leave orphaned entries. "Stop" (called "Pause" in qBittorrent versions before 4.6) is the safe default.

### Categories

The arr apps create their own categories (`sonarr`, `radarr`, `lidarr`) automatically on their first grab. No manual setup required in qBittorrent.

---

## Step 2 — Prowlarr: Add Indexers

Open Prowlarr at `http://arr.tlesh.xyz:9696`.

Prowlarr is the central indexer manager — you configure trackers here once and it syncs them to Sonarr, Radarr, and Lidarr automatically.

### Add indexers

1. **Indexers → Add Indexer**
2. Add your preferred indexers. Public trackers require no account. Private trackers need credentials.
3. Test each indexer after adding to confirm connectivity.

### Connect apps to Prowlarr

**Settings → Apps → Add Application** — add each arr app:

| App | Internal URL | API Key location |
|-----|-------------|-----------------|
| Sonarr | `http://sonarr:8989` | Sonarr → Settings → General → API Key |
| Radarr | `http://radarr:7878` | Radarr → Settings → General → API Key |
| Lidarr | `http://lidarr:8686` | Lidarr → Settings → General → API Key |

After adding all three, click **Sync App Indexers** — Prowlarr pushes the indexer list to each app.

> You said you've already connected these via API keys, so this step may already be done. Verify by checking that Sonarr/Radarr/Lidarr each show indexers under **Settings → Indexers**.

---

## Step 3 — Sonarr: Initial Configuration

Open Sonarr at `http://arr.tlesh.xyz:8989`.

### Download client

**Settings → Download Clients → Add → qBittorrent:**

| Field | Value |
|-------|-------|
| Host | `gluetun` (qBittorrent runs inside Gluetun's network namespace — NOT `localhost` or `qbittorrent`) |
| Port | `8080` |
| Username / Password | from Step 1 |
| Category | `sonarr` |
| Recent Priority | Last |
| Older Priority | Last |

Enable: **"Remove Completed"** — this tells Sonarr to remove the torrent from qBittorrent (and delete the local file) once the download is imported **and** seeding has finished (i.e., qBittorrent has stopped it per your seeding limits).

### Root folder

**Settings → Media Management → Root Folders → Add:**

- Path: `/data/media/tv`

### Naming

**Settings → Media Management → Episode Naming:**

- Enable: **Rename Episodes**
- Standard episode format: `{Series Title} - S{season:00}E{episode:00} - {Episode Title}`
- Season folder format: `Season {season:00}`

### Completed download handling

**Settings → Download Clients → (gear icon) → Completed Download Handling:**

- Enable: **Remove** — Sonarr auto-removes the import task once complete

---

## Step 4 — Radarr: Initial Configuration

Open Radarr at `http://arr.tlesh.xyz:7878`.

### Download client

**Settings → Download Clients → Add → qBittorrent:**

| Field | Value |
|-------|-------|
| Host | `gluetun` |
| Port | `8080` |
| Username / Password | from Step 1 |
| Category | `radarr` |

Enable **Remove Completed** as with Sonarr.

### Root folder

**Settings → Media Management → Root Folders → Add:**

- Path: `/data/media/movies`

### Naming

**Settings → Media Management → Movie Naming:**

- Enable: **Rename Movies**
- Standard movie format: `{Movie Title} ({Release Year})`

---

## Step 5 — Lidarr: Initial Configuration

Open Lidarr at `http://arr.tlesh.xyz:8686`.

### Download client

**Settings → Download Clients → Add → qBittorrent:**

| Field | Value |
|-------|-------|
| Host | `gluetun` |
| Port | `8080` |
| Username / Password | from Step 1 |
| Category | `lidarr` |

Enable **Remove Completed**.

### Root folder

**Settings → Media Management → Root Folders → Add:**

- Path: `/data/media/music`

### Naming

**Settings → Media Management → Track Naming:**

- Enable: **Rename Tracks**
- Album folder: `{Artist Name}/{Album Title} ({Release Year})`
- Track format: `{track:00} - {Track Title}`

### Add artists before importing

Lidarr must know about an artist **before** it can match or import files for them. If you attempt a manual import for an artist that isn't added, Lidarr returns zero results.

**Artists → Add New** — search for and add every artist you have music for. Set monitoring to **All Albums** if you want Lidarr to track future releases automatically.

---

## Step 6 — Beets: Verify and Test

Beets is a music tagger that runs as a Docker container and uses MusicBrainz to identify and clean up music files before Lidarr imports them.

### Verify the config deployed

```bash
# SSH to arr LXC, or from your Mac:
doppler run -- ansible arr -m shell -a "docker exec beets cat /config/config.yaml"
```

You should see:

```yaml
directory: /data/media/unprocessed/music-ready
library: /config/musiclibrary.db
import:
  move: yes
  quiet: yes
  log: /config/import.log
plugins: fetchart embedart
```

### Test with a dry-run

Before running a real import, verify beets can match your files:

```bash
# Drop a few files into /data/media/unprocessed/music/ first, then:
doppler run -- ansible arr -m shell -a \
  "docker exec beets beet import --pretend /data/media/unprocessed/music"
```

`--pretend` shows what beets would do without moving anything.

### Run a real import

```bash
task beets-import
```

This command (defined in `Taskfile.yml`):

1. Runs `beet import -q` on `/data/media/unprocessed/music/`
2. High-confidence matches are tagged and moved to `unprocessed/music-ready/`
3. Low-confidence and unmatched files are swept to `unprocessed/music-review/`

After running:

- **`music-ready/`** — open Lidarr → Artists → Manual Import → point at this dir
- **`music-review/`** — files beets couldn't confidently match (see below)

### Handling music-review files

Options for files beets couldn't match:

1. **Rename the file** to `Artist - Album - Track Title.flac` format and re-run `task beets-import`
2. **Use MusicBrainz Picard** (desktop app) to tag manually, then drop the tagged files back into `unprocessed/music/` and re-run
3. **Import directly via Lidarr** manual import if the files are already organized well enough

---

## Step 7 — Plex: Add Libraries

Open Plex and go to **Settings → Libraries → Add Library**.

Add three libraries:

| Library Type | Name | Folder |
|-------------|------|--------|
| TV Shows | TV | `/data/media/tv` |
| Movies | Movies | `/data/media/movies` |
| Music | Music | `/data/media/music` |

After adding each library, Plex will scan and match metadata automatically.

### Enable automatic library updates

**Settings → Troubleshooting → "Run Scanner Periodically"** — enable this so Plex picks up new files without manual intervention. Sonarr/Radarr/Lidarr also notify Plex directly via the API after each import (once you add Plex as a connection in each arr app — see Step 8).

---

## Step 8 — Connect Arr Apps to Plex (Auto-Scan Trigger)

Without this step, Plex won't pick up new files until its periodic scanner runs. With it, Sonarr/Radarr/Lidarr ping Plex immediately after each import.

In **Sonarr, Radarr, and Lidarr**, go to **Settings → Connect → Add → Plex Media Server:**

| Field | Value |
|-------|-------|
| Host | Plex LXC IP or `plex.tlesh.xyz` |
| Port | `32400` |
| Auth Token | Get from Plex: Account → Privacy → (scroll to) "Plex token" link, or check `https://plex.tv/api/resources?X-Plex-Token=<token>` |

Test the connection, then save. After this, every time an arr app imports a file, it tells Plex to rescan that specific library — new content appears in Plex within seconds.

---

## Step 9 — Seerr: Connect to Sonarr and Radarr

Open Seerr at `http://arr.tlesh.xyz:5055`.

> Seerr supports TV and movies only — there is no Lidarr integration. Music requests are managed by dropping files manually into the pipeline.

**Settings → Services → Add Radarr:**

- URL: `http://radarr:7878`
- API key from Radarr → Settings → General
- Default root folder: `/data/media/movies`
- Default quality profile: your preferred profile

**Settings → Services → Add Sonarr:**

- URL: `http://sonarr:8989`
- API key from Sonarr → Settings → General
- Default root folder: `/data/media/tv`
- Default quality profile: your preferred profile

---

## Step 10 — Bazarr: Connect to Sonarr and Radarr

Open Bazarr at `http://arr.tlesh.xyz:6767`.

**Settings → Sonarr:**

- Enable: yes
- Host: `sonarr`, Port: `8989`
- API key from Sonarr

**Settings → Radarr:**

- Enable: yes
- Host: `radarr`, Port: `7878`
- API key from Radarr

**Settings → Languages:**

- Add your desired subtitle languages (e.g., English)
- Set a language profile and assign it as the default for Sonarr and Radarr

Bazarr will then automatically search for and download subtitles for all existing and new content.

---

## Step 11 — Uptime Kuma: Add Lidarr Monitor

Uptime Kuma uses an unofficial WebSocket API that can't be automated from Ansible, so this is a one-time manual step.

1. Open Uptime Kuma at `http://uptime-kuma.tlesh.xyz:3001`
2. **Add Monitor → HTTP(s):**
   - Name: `Lidarr`
   - URL: `http://arr.tlesh.xyz:8686`
   - Heartbeat interval: 60s

---

## Directory Reference

```text
/data/downloads/                    ← Local LXC disk (NOT NFS)
├── incomplete/                     ← qBittorrent active downloads
└── complete/                       ← qBittorrent finished, seeding here
    ├── sonarr/                     ← (category subdirs created by arr apps)
    ├── radarr/
    └── lidarr/

/data/media/                        ← TrueNAS NFS mount (192.168.220.6)
├── tv/                             ← Sonarr library, Plex reads here
├── movies/                         ← Radarr library, Plex reads here
├── music/                          ← Lidarr library, Plex reads here
└── unprocessed/                    ← Manual import staging
    ├── tv/                         ← Drop zone for Sonarr manual import
    ├── movies/                     ← Drop zone for Radarr manual import
    ├── music/                      ← Drop zone → beets processes here
    ├── music-ready/                ← beets output → Lidarr manual import
    └── music-review/               ← beets low-confidence files
```

---

## Ongoing Workflows

### New content via Seerr (fully automated)

1. Request in Seerr → Sonarr/Radarr picks it up → Prowlarr finds a release → qBittorrent downloads it → arr app imports it to library → Plex notification → done.

### New TV or movie files you already have

1. Copy files to `/data/media/unprocessed/tv/` or `unprocessed/movies/` (accessible from Mac via NFS or SCP)
2. Open Sonarr or Radarr → **Manual Import** → select the unprocessed directory
3. Review matches, correct any errors, confirm
4. Files are moved to `tv/` or `movies/` and Plex is notified

### New music files you already have

1. Copy files to `/data/media/unprocessed/music/`
2. Run `task beets-import` from your Mac
3. Open Lidarr → **Artists → Manual Import** → select `/data/media/unprocessed/music-ready/`
4. Review and confirm; files move to `music/` and Plex is notified
5. Check `music-review/` for anything that needs manual attention

### qBittorrent seeding summary

After a download completes and is imported to the Plex library:

- qBittorrent continues seeding the original file from `/data/downloads/complete/`
- Seeding stops when **ratio ≥ 2** or **48 hours** elapses, whichever comes first
- qBittorrent stops the torrent
- Sonarr/Radarr/Lidarr detect the stopped state on their next poll and trigger cleanup: the torrent is removed from qBittorrent and the local file in `complete/` is deleted
- The Plex library copy in `/data/media/` is unaffected — it was copied, not moved

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Files stuck in `incomplete/` | qBittorrent VPN — verify Gluetun is up: `docker logs gluetun` |
| Arr app can't reach qBittorrent | Ensure Host is `gluetun`, not `qbittorrent` or `localhost` |
| Import fails with "no files found" | Verify volume mounts: both `/data/downloads` and `/data/media` must be mounted in the container |
| Music import finds no matches in Lidarr | Artist must be added in Lidarr first before manual import works |
| Plex doesn't show new files | Verify Plex connection in arr app → Settings → Connect; trigger a manual library scan |
| Beets matches wrong album | Check `music-review/` and use MusicBrainz Picard to tag manually, then re-drop into `unprocessed/music/` |
