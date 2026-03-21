# Uptime Kuma Monitor Recovery Runbook

Use this document to recreate all monitors if the Uptime Kuma data volume is lost.

**URL:** http://192.168.233.16:3001
**Notification:** Configure one Pushover notification channel first.
  - Pushover API Token: `PUSHOVER_API_TOKEN` from Doppler
  - Pushover User Key: `PUSHOVER_USER_KEY` from Doppler

**Global settings for all monitors:**
- Type: HTTP(s)
- Heartbeat interval: 60 seconds
- Retries before alert: 3
- Accepted status codes: 200-299

---

## ARR Stack

| Name | URL | Notes |
|---|---|---|
| Sonarr | http://arr.tlesh.xyz:8989/api/v3/health | |
| Radarr | http://arr.tlesh.xyz:7878/api/v3/health | |
| Prowlarr | http://arr.tlesh.xyz:9696/api/v1/health | |
| Bazarr | http://arr.tlesh.xyz:6767/api/v1/system/health | |
| Seerr | http://arr.tlesh.xyz:5055/api/v1/status | |
| qBittorrent | http://arr.tlesh.xyz:8080 | |
| FlareSolverr | http://arr.tlesh.xyz:8191 | |
| Gluetun VPN | http://arr.tlesh.xyz:8000/v1/publicip/ip | Response body should contain a ProtonVPN IP |

## Core Services

| Name | URL | Notes |
|---|---|---|
| Plex | http://plex.tlesh.xyz:32400/identity | |
| Pi-hole | http://pi-hole.tlesh.xyz/admin | |
| Glance | http://glance.tlesh.xyz:8080 | |
| Netdata | http://netdata.tlesh.xyz:19999 | |

## Infrastructure

| Name | URL | Notes |
|---|---|---|
| Proxmox tika | https://tika.tlesh.xyz:8006 | Enable "Ignore TLS/SSL error" |
| Proxmox bupu | https://bupu.tlesh.xyz:8006 | Enable "Ignore TLS/SSL error" |
| Proxmox sturm | https://sturm.tlesh.xyz:8006 | Enable "Ignore TLS/SSL error" |
| TrueNAS | http://ansalon.tlesh.xyz | |
