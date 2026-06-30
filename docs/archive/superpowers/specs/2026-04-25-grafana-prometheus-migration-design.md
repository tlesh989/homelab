# Grafana + Prometheus Migration Design

**Date:** 2026-04-25
**Beads issue:** homelab-9uw
**Status:** Approved

## Why

Netdata's auto-discovery dashboard is too busy and complex for homelab use. Moving to Grafana + Prometheus gives full control over what's displayed and enables integrating all homelab services (Plex, arr stack, Minecraft, Proxmox, UniFi) into a single clean dashboard. Decommissioning the Netdata LXC (.23 on sturm) frees resources for high-performance workloads.

## Architecture

### Components

| Component | Host | Role |
|-----------|------|------|
| Prometheus | kaz (.10) | Metrics scraper and TSDB |
| Grafana | kaz (.10) | Dashboard UI |
| node_exporter | All Proxmox nodes + LXCs | System metrics (CPU, mem, disk, net) |
| exportarr | bupu | Sonarr / Radarr / Lidarr metrics |
| Caddy site | tika (.17) | TLS reverse proxy for grafana.tlesh.xyz |

Prometheus uses a **pull model** — it scrapes all exporters by IP:port on a configured interval. No pushgateway.

### Scrape targets

| Exporter | Port | Hosts |
|----------|------|-------|
| node_exporter | 9100 | All hosts in `exporters` inventory group |
| exportarr (Sonarr) | 9707 | bupu |
| exportarr (Radarr) | 9708 | bupu |
| exportarr (Lidarr) | 9709 | bupu |

Future exporters (pve-exporter, unpoller, mc_monitor, Tautulli) are out of scope for this PR and tracked separately.

### Access

Grafana accessible at `grafana.tlesh.xyz` via Caddy reverse proxy (TLS via existing acme wildcard cert). Tailscale-only access is sufficient — no public DNS required.

## Role Structure

### `roles/monitoring/` — deployed to kaz

```
defaults/main.yml          # versions, ports, data paths, retention, Grafana admin password var
tasks/main.yml             # create dirs, deploy Prometheus + Grafana containers
templates/
  prometheus.yml.j2        # scrape config templated from exporters group + static targets
  grafana-datasource.yml.j2
  grafana-dashboards.yml.j2
files/dashboards/          # community dashboard JSON files
  node-exporter-full.json  # grafana.com/dashboards/1860
  exportarr-sonarr.json
  exportarr-radarr.json
  exportarr-lidarr.json
```

Containers follow the existing `community.docker.docker_container` pattern (same as n8n, glance). Both containers get named Docker volumes for persistent data.

### `roles/node_exporter/` — deployed to `exporters` group

```
defaults/main.yml   # version, port (9100)
tasks/main.yml      # apt install prometheus-node-exporter, systemd enable + start
```

### `roles/exportarr/` — deployed to bupu

```
defaults/main.yml   # version, ports per app, arr API key var names
tasks/main.yml      # one docker_container task per arr app
```

### Inventory additions

```ini
[exporters]
tika
bupu
sturm
# + all LXC container hostnames

[monitoring]
kaz
```

## Grafana Provisioning

Community dashboards are provisioned at deploy time via Grafana's provisioning system:

- **Datasource:** Prometheus at `http://prometheus:9090` (Docker internal network)
- **Dashboard provider:** reads from `/etc/grafana/provisioning/dashboards/`
- **Dashboard JSON files:** baked into `roles/monitoring/files/dashboards/` and copied to the container volume at deploy time

Dashboard IDs to download:
- Node Exporter Full: [1860](https://grafana.com/grafana/dashboards/1860)
- exportarr Sonarr/Radarr/Lidarr: community dashboards from exportarr repo

## Migration Sequence

### Phase 1 — Deploy new stack (PR 1)

1. Add `exporters` and `monitoring` inventory groups
2. Deploy `node_exporter` to all hosts in `exporters` group
3. Deploy `monitoring` role to kaz (Prometheus + Grafana containers)
4. Deploy `exportarr` role to bupu
5. Add `grafana.tlesh.xyz` Caddy site block (reverse proxy to kaz:3000)
6. Add pi-hole DNS entry: `grafana.tlesh.xyz` → 192.168.233.10 (kaz)
7. Add Grafana to Uptime Kuma monitor + Glance dashboard
8. Netdata continues running — no changes

### Phase 2 — Verify (manual, ~1 day)

- Confirm all scrape targets healthy at Prometheus `/targets`
- Confirm dashboards populated in Grafana
- Only proceed to Phase 3 after verification

### Phase 3 — Decommission (PR 2)

**Code changes (in PR):**
- Delete `terraform/netdata.tf`
- Remove netdata plays from `main.yml`
- Remove `task netdata` from `Taskfile.yml`
- Remove `roles/netdata/` directory
- Remove `group_vars/netdata.yml` and netdata vars from `group_vars/proxmox.yml`
- Remove netdata Caddy site from `roles/caddy/defaults/main.yml`
- Remove `192.168.233.17 netdata.tlesh.xyz` from `roles/pi-hole/defaults/main.yml`

**Manual steps (after PR merges):**
- Run `task apply` in `terraform/` to destroy the Netdata LXC (vm_id 105, 192.168.233.23 on sturm)
- Remove `NETDATA_STREAM_API_KEY` from Doppler

## Acceptance Criteria

- Grafana accessible at `grafana.tlesh.xyz` via Caddy
- All exporters shipping data to Prometheus (targets page shows all green)
- Dashboards cover: system (node_exporter), arr stack (exportarr)
- Netdata LXC decommissioned from sturm, freeing resources
