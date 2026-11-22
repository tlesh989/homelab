# Uptime Kuma Monitor Recovery Runbook

Use this document to recreate all monitors if the Uptime Kuma data volume is lost.
Monitors are configured by hand in the UI — keep this file in sync when you add or change one.

**URL:** http://192.168.233.16:3001
**Notification:** Configure one Pushover notification channel first ("Default enabled" on).
  - Pushover API Token: `PUSHOVER_API_TOKEN` from Doppler
  - Pushover User Key: `PUSHOVER_USER_KEY` from Doppler

**Second notification — "Why is it down?" (Antigravity):** a Webhook notification, also "Default enabled"
and "Apply on all existing monitors". `homelab-alert-listener` on claude-code asks the Antigravity CLI for
the likely cause of each outage and pushes it to Pushover (one run per 15 minutes).
  - Post URL: `http://192.168.233.22:8765/`, Request Body: "Preset - application/json"
  - Additional Headers: `{"Authorization": "Bearer <KUMA_WEBHOOK_TOKEN from Doppler>"}`

**Global settings for all monitors (unless noted):**
- Heartbeat interval: 60 seconds
- Retries: 0
- Accepted status codes: 200-299
- HTTP monitors target IPs, not `*.tlesh.xyz` names, so a DNS outage doesn't mask service health.
  DNS and the Caddy proxy path are covered separately under **DNS & Proxy**.

---

## DNS & Proxy

Catch name-resolution and reverse-proxy failures that the IP-based monitors can't see
(e.g. Pi-hole losing its local records — homelab-q1q, or the wildcard cert expiring — homelab-dt8).

| Name | Type | Settings | Notes |
|---|---|---|---|
| DNS: Pi-hole | DNS | Hostname `glance.tlesh.xyz`, Resolver `192.168.233.3`, Port 53, Record type A | Condition: record equals `192.168.233.17` |
| DNS: Gateway | DNS | Hostname `glance.tlesh.xyz`, Resolver `192.168.233.1`, Port 53, Record type A | Condition: record equals `192.168.233.17`. The path clients use (gateway → Pi-hole for `tlesh.xyz`) |
| DNS: Pi-hole upstream | DNS | Hostname `example.com`, Resolver `192.168.233.3`, Port 53, Record type A | Pi-hole can resolve public names |
| Glance (Caddy) | HTTP(s) | URL `https://glance.tlesh.xyz` | Enable "Certificate Expiry Notification". End-to-end: DNS + Caddy + wildcard cert |

After adding a DNS monitor, prove it can fail: temporarily change the hostname to
`nonexistent.tlesh.xyz` (Pi-hole answers NXDOMAIN) and confirm it goes red, then revert.

## Core Services

| Name | Type | Target | Notes |
|---|---|---|---|
| Pi-hole | TCP Port | `192.168.233.3` port 53 | Only proves FTL is listening — see DNS & Proxy for resolution |
| Plex | HTTP(s) | http://192.168.233.12:32400/identity | |
| Home Assistant | HTTP(s) | http://192.168.233.23 | HAOS VM; UI is on port 80 (`:8123` only redirects to it) |

## Infrastructure

| Name | Type | Target | Notes |
|---|---|---|---|
| Tika | HTTP(s) | https://192.168.233.7:8006 | Enable "Ignore TLS/SSL error" |
| Bupu | HTTP(s) | https://192.168.233.8:8006 | Enable "Ignore TLS/SSL error" |
| Sturm | HTTP(s) | https://192.168.233.9:8006 | Enable "Ignore TLS/SSL error" |
| TrueNAS | HTTP(s) | http://192.168.233.6 | |

## Apps

| Name | Type | Target | Notes |
|---|---|---|---|
| n8n | HTTP(s) | http://192.168.233.10:5678 | |
| FreshRSS | HTTP(s) | http://192.168.233.10:8002 | |
| Wallos | HTTP(s) | http://192.168.233.10:8282 | |
| BookOrbit | HTTP(s) | http://192.168.233.10:8091 | |
| PriceBuddy | HTTP(s) | http://192.168.233.10:8092 | |

## Arr Stack

| Name | Type | Target | Notes |
|---|---|---|---|
| Sonarr | HTTP(s) | http://192.168.233.24:8989 | |
| Radarr | HTTP(s) | http://192.168.233.24:7878 | |
| Prowlarr | HTTP(s) | http://192.168.233.24:9696 | |
| Bazarr | HTTP(s) | http://192.168.233.24:6767 | |
| Lidarr | HTTP(s) | http://192.168.233.24:8686 | |
| Beets | HTTP(s) | http://192.168.233.24:8337 | |
| Seerr | HTTP(s) | http://192.168.233.24:5055 | |
| qBittorrent | HTTP(s) | http://192.168.233.24:8080 | |
| Tdarr | HTTP(s) | http://192.168.233.24:8265 | |

## Monitoring

| Name | Type | Target | Notes |
|---|---|---|---|
| Beszel | HTTP(s) | http://192.168.233.10:8090 | |
| Dozzle | HTTP(s) | http://192.168.233.10:8025 | |
| Uptime Kuma | HTTP(s) | http://192.168.233.16:3001 | Ungrouped; self-check only — can't alert if Kuma itself is down |
