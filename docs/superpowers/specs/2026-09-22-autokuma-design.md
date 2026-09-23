# AutoKuma: automated Uptime Kuma monitor management

## Problem

Every new Docker service requires manually adding an Uptime Kuma monitor
(and manually removing it when the service is decommissioned — missed on
the CouchDB removal in #301, and would have been missed again for
calibre-web-automated's removal if not caught in review). Monitors drift
out of sync with what's actually deployed.

## Goal

Uptime Kuma monitors for every user-facing Docker service are created and
removed automatically, driven by the same docker-compose definitions that
already deploy the service — no separate manual step, no drift.

## Non-goals

- Background-only containers (gluetun, watchtower, dozzle-agent,
  beszel-agent, cloudflare_ddns) do not get monitors — matches the
  existing "New Service Checklist" scope (web-UI services only).
- Not replacing Kuma itself, Pushover notification config, or Glance/Caddy
  entries — those stay manual as today.
- Not monitoring non-Docker services (plex, minecraft, caddy, pi-hole are
  native installs, out of scope for AutoKuma).

## Architecture

One AutoKuma instance per Docker host — not a single centralized instance
reaching out over the network. Each instance reads its own host's local
`/var/run/docker.sock` (read-only mount) and pushes monitor state to the
single central Uptime Kuma server at `uptime-kuma.tlesh.xyz:3001`.

This mirrors the existing per-host pattern already used for Watchtower and
the Dozzle agents in this repo, and avoids exposing any host's Docker
daemon over TCP (the alternative — a single centralized AutoKuma reaching
out to remote hosts via `AUTOKUMA__DOCKER__HOSTS=tcp://...`) which would
require TLS cert management per host and a new network-exposed attack
surface. Rejected as inconsistent with "minimum change" and the existing
security posture.

### Hosts

AutoKuma deploys to every host that runs `community.docker.docker_container`
or `community.docker.docker_compose` today: **kaz, arr, tdarr_node,
uptime-kuma**. (barlo also runs the `uptime_kuma` role but is currently an
offline/commented-out remote site host — excluded from this rollout;
revisit if it comes back online.)

## New role: `roles/autokuma`

- Image: `ghcr.io/bigboot/autokuma`, pinned to a specific release tag (not
  `latest`, per `.claude/rules/docker.md`).
- Volumes: `/var/run/docker.sock:/var/run/docker.sock:ro`
- Env:
  - `AUTOKUMA__KUMA__URL: "http://{{ hostvars['uptime-kuma.tlesh.xyz'].ansible_host }}:{{ uptime_kuma_port }}"`
  - `AUTOKUMA__KUMA__USERNAME: "{{ lookup('env', 'AUTOKUMA_USERNAME') }}"`
  - `AUTOKUMA__KUMA__PASSWORD: "{{ lookup('env', 'AUTOKUMA_PASSWORD') }}"`
- `restart_policy: unless-stopped`, included in each host's Watchtower
  coverage like every other container (no separate Watchtower wiring
  needed — Watchtower already watches the whole host).
- Added to `main.yml` for the `kaz`, `arr`, `tdarr_node`, and
  `uptime-kuma` plays, ordered before the app roles on each host (mirrors
  `gluetun` preceding `qbittorrent` in the `arr` role) — not required for
  correctness since AutoKuma reconciles on Docker events, but keeps
  ordering intuitive.

## Credentials

New dedicated Uptime Kuma user (created once, manually, in the Kuma UI —
documented as a pre-deploy manual step like `BOOKORBIT_SETUP_BOOTSTRAP_TOKEN`
today) with just enough access to manage monitors. Credentials stored as
new Doppler secrets:

- `AUTOKUMA_USERNAME`
- `AUTOKUMA_PASSWORD`

Not reusing the personal admin login, so automation doesn't hold full
admin credentials.

## Label retrofit

Every existing web-UI Docker service gets a `kuma.*` label block added
directly to its `docker-compose.yml.j2` (or `docker_container` task)
alongside its existing port/env vars — no new role variables needed since
labels reference variables already defined in each template.

Monitor `<id>` = container name (already unique per role). Type `http`,
pointed at the container's internal port:

```yaml
labels:
  kuma.qbittorrent.http.name: "qBittorrent"
  kuma.qbittorrent.http.url: "http://qbittorrent:{{ arr_qbittorrent_port }}"
```

Tagged by host so Kuma's dashboard stays organized the way manually
grouped monitors are today:

```yaml
  kuma.qbittorrent.http.tags: "arr"
```

Services in scope (every container with a web UI, across all Docker
roles): arr stack (qbittorrent, sonarr, radarr, prowlarr, bazarr, seerr,
lidarr, beets, tdarr webui), bookorbit-app, uptime-kuma itself, n8n,
freshrss, wallos, rustdesk, syncthing, dozzle_hub. Background-only
containers (gluetun, watchtower, dozzle-agent, beszel-agent,
cloudflare_ddns, autokuma itself) get no labels — see Non-goals.

## Notifications

Not part of the label retrofit. Kuma's "default notification" setting
(Pushover, already configured server-side per `group_vars/uptime-kuma.yml`)
applies to all monitors including AutoKuma-created ones automatically —
configured once in the Kuma UI, not per-label.

## Rollout & error handling

- Manual pre-step (you, before first deploy): create the `autokuma` Kuma
  user in the UI, add `AUTOKUMA_USERNAME`/`AUTOKUMA_PASSWORD` to Doppler.
- `roles/autokuma` is idempotent like every other docker role in this
  repo — no special failure handling beyond what
  `community.docker.docker_container` already provides.
- Full rollout in one pass: deploy `roles/autokuma` to all four hosts and
  add labels to every in-scope service in the same change.
- Rollback: `docker rm -f autokuma` on affected host(s) and drop the role
  from `main.yml`. No state is left behind — monitors AutoKuma created
  simply stop updating and can be left or deleted from the Kuma UI; if
  AutoKuma is redeployed later it reconciles by `<id>` and won't create
  duplicates.

## Testing

- `task syntax && task lint`
- `task check` dry-run across all four hosts
- Deploy, verify each AutoKuma container comes up and logs a successful
  Kuma login
- Verify monitors appear in Kuma's UI for a sample of labeled services
  (one per host)
- Remove a label from one test service, verify AutoKuma deletes its
  monitor
