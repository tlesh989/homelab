# Uptime Kuma + Pushover Notifications Design

**Date:** 2026-03-20
**Status:** Approved

## Overview

Deploy Uptime Kuma as a dedicated monitoring service to send Pushover notifications when homelab services fail and do not self-recover. The monitor runs on its own LXC container so it survives failures of the services it watches.

## Goals

- Alert via Pushover when a service is down and Docker's restart policy has not recovered it
- Cover the full homelab: arr stack, core services, and infrastructure nodes
- Reuse existing Pushover credentials already in Doppler (used by Watchtower)
- Fit the existing Terraform + Ansible + Doppler workflow

## Non-Goals

- UniFi DHCP integration (tracked separately as `homelab-44m`)
- Automatic monitor provisioning via API (manual UI setup is sufficient for 18 monitors)
- TrueNAS disk/SMART health alerts (handled by Netdata's TrueNAS collector)
- Netdata replacement (Netdata remains for metrics; Uptime Kuma handles availability alerting)

## Architecture

### Infrastructure

| Property | Value |
|---|---|
| Hostname | `uptime-kuma.tlesh.xyz` |
| IP | `192.168.233.16` |
| VM ID | `116` (matches last octet; confirm no conflict at implementation time) |
| MAC address | `BC:24:11:xx:xx:xx` convention (assign a unique value following existing containers) |
| Proxmox node | `sturm` |
| Container type | LXC |
| Resources | 1 vCPU, 512MB RAM, 8GB disk (matches project convention; Uptime Kuma history is lightweight) |
| Data path | `/opt/uptime-kuma/data` |
| Port | `3001` (LAN/Tailscale only, no public exposure) |

### Deployment Stack

- **Terraform**: `terraform/uptime-kuma.tf` — provisions the LXC, following the `pi-hole.tf` pattern
- **Ansible**: `roles/uptime-kuma` — deploys Uptime Kuma via Docker Compose using `geerlingguy.docker` (already a Galaxy dependency)
- **Secrets**: `PUSHOVER_API_TOKEN` and `PUSHOVER_USER_KEY` from Doppler (shared with Watchtower — no new secrets needed)
- **Task**: new `task uptime-kuma` entry in `Taskfile.yml`

## Monitor Configuration

**Alert policy:** HTTP check every 60 seconds, notify after 3 consecutive failures (~3 minutes to alert). Filters brief Docker restart blips while catching genuine outages.

**Notification:** Single Pushover notification channel shared by all monitors.

### ARR Stack (`arr.tlesh.xyz`)

| Monitor | URL | Check Type |
|---|---|---|
| Sonarr | `http://arr.tlesh.xyz:8989/api/v3/health` | HTTP |
| Radarr | `http://arr.tlesh.xyz:7878/api/v3/health` | HTTP |
| Prowlarr | `http://arr.tlesh.xyz:9696/api/v1/health` | HTTP |
| Bazarr | `http://arr.tlesh.xyz:6767/api/v1/system/health` | HTTP |
| Seerr | `http://arr.tlesh.xyz:5055/api/v1/status` | HTTP |
| qBittorrent | `http://arr.tlesh.xyz:8080` | HTTP |
| FlareSolverr | `http://arr.tlesh.xyz:8191` | HTTP |
| Gluetun VPN | `http://arr.tlesh.xyz:8000/v1/publicip/ip` | HTTP (response = VPN IP means tunnel is up) — **verify port 8000 is exposed in Docker Compose before using** |

### Core Services

| Monitor | URL | Check Type |
|---|---|---|
| Plex | `http://plex.tlesh.xyz:32400/identity` | HTTP |
| Pi-hole | `http://pi-hole.tlesh.xyz/admin` | HTTP |
| Glance | `http://glance.tlesh.xyz:8080` | HTTP |
| Netdata | `http://netdata.tlesh.xyz:19999` | HTTP |

### Infrastructure

| Monitor | URL | Check Type |
|---|---|---|
| Proxmox tika | `https://tika.tlesh.xyz:8006` | HTTP (accept self-signed cert) |
| Proxmox bupu | `https://bupu.tlesh.xyz:8006` | HTTP (accept self-signed cert) |
| Proxmox sturm | `https://sturm.tlesh.xyz:8006` | HTTP (accept self-signed cert) |
| TrueNAS | `http://ansalon.tlesh.xyz` | HTTP |

**Total: 18 monitors**

## Monitor Provisioning

Monitors are configured manually via the Uptime Kuma web UI after first deploy. A runbook at `docs/runbooks/uptime-kuma-monitors.md` documents all 18 monitors for recovery if the data volume is lost.

**Rationale for manual setup:** Uptime Kuma has no official provisioning API. The unofficial Python Socket.IO wrapper is fragile and breaks on version upgrades. 18 monitors is a one-time ~10 minute setup.

## Implementation Tasks

| Task | Dependency |
|---|---|
| Terraform: `uptime-kuma.tf` LXC on sturm | — |
| Ansible: `roles/uptime-kuma` Docker Compose role | — |
| Ansible: host group, inventory entry, Taskfile task | roles/uptime-kuma |
| Docs: `uptime-kuma-monitors.md` runbook | — |
| Manual: first deploy, configure Pushover + 18 monitors in UI | All above |

## Definition of Done

- `task syntax` and `task lint` pass
- `task check` dry-run shows expected changes for `uptime_kuma` host group only
- `terraform/uptime-kuma.tf` passes `task test` (fmt + validate)
- Uptime Kuma accessible at `http://192.168.233.16:3001`
- All 18 monitors green
- Test Pushover notification received
