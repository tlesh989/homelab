# Glance: Netdata Infrastructure Page

**Date:** 2026-03-19
**Branch:** feature/glance-netdata

## Problem

The Glance dashboard currently only has a Home page. There is no at-a-glance view of homelab infrastructure health — users must navigate directly to Proxmox or Netdata to check node status.

## Solution

Add an **Infrastructure** page to the Glance dashboard with two widgets:

1. **`monitor` widget** — HTTP health checks for all critical services:
   - Proxmox nodes: tika (`.7`), bupu (`.8`), sturm (`.9`) — HTTPS/8006, `allow-insecure: true`
   - TrueNAS (ansalon, `.6`) — HTTPS
   - Netdata parent (`.23`) — HTTP/19999
   - Pi-hole (`.3`) — HTTP

2. **`custom-api` widget** — Live metrics from Netdata's `/api/v1/info` endpoint:
   - Number of nodes being monitored (`mirrored_hosts` array length)
   - Active alarm counts (critical / warning)

## Netdata API

- Endpoint: `http://192.168.233.23:19999/api/v1/info`
- No auth required (internal network)
- Key fields: `.hostname`, `.mirrored_hosts[]`, `.alarms.critical`, `.alarms.warning`

## Jinja2 / Go Template Escaping

The Glance config uses Go template syntax (`{{ }}`), which conflicts with Jinja2.
All Go template expressions in `glance.yml.j2` are wrapped in `{% raw %}...{% endraw %}`.

## Files Changed

- `roles/glance/templates/glance.yml.j2` — add Infrastructure page
