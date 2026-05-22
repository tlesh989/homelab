# Barlo Remote Site Server Design

**Date:** 2026-05-21
**Status:** Approved

## Overview

Provision a Zimablade server ("barlo", Ubuntu 26.04 LTS) for deployment at a remote location (bakery). Barlo needs a minimal GNOME desktop with Google Chrome for managing Chromecast display devices, RDP remote access over Tailscale, and local network monitoring with Pushover alerts.

## Inventory & Host Configuration

**`./hosts`** — add a `[barlo]` group following the existing per-host pattern:

```ini
[barlo]
barlo.tlesh.xyz ansible_host=192.168.233.126
```

Add `barlo` to `[exporters:children]` so `node_exporter` deploys automatically via the existing exporters play.

**`group_vars/barlo.yml`** — barlo-specific vars:
- `package_list`: host-specific packages
- `uptime_kuma_timezone: America/Detroit`

**Post-move**: after barlo arrives at the bakery and Tailscale is enrolled, update `ansible_host` from `192.168.233.126` to `barlo.dunker-hops.ts.net` so Ansible reaches it over the tailnet.

**Tailscale remote access**: use `barlo.dunker-hops.ts.net` (MagicDNS). Tailscale is IP-independent — enroll at home via Ansible, move the box, it just works.

## New Role: `roles/desktop`

Encapsulates GNOME minimal desktop + xrdp + Google Chrome. Not inlined in the play — enough moving parts to warrant isolation, and potentially reusable.

### Tasks

1. **GNOME minimal** — install `ubuntu-desktop-minimal` (pulls in GDM3 + GNOME session). Set GDM as the default display manager.

2. **xrdp**
   - Install `xrdp` + `xorgxrdp` from Ubuntu repos
   - Add `xrdp` user to `ssl-cert` group (required for TLS cert access)
   - Deploy `/etc/xrdp/startwm.sh` via template to launch a GNOME session
   - Add a polkit rule to suppress the "color managed device" auth popup (known GNOME/xrdp gotcha)
   - Enable and start the `xrdp` service

3. **Google Chrome**
   - Add Google's apt signing key to `/etc/apt/keyrings/google.gpg`
   - Add apt source to `/etc/apt/sources.list.d/google-chrome.list`
   - Install `google-chrome-stable`
   - Idempotent apt-repo approach (not a downloaded .deb)

### Role Defaults

```yaml
desktop_xrdp_port: 3389
desktop_gnome_packages:
  - ubuntu-desktop-minimal
```

**Connect from Mac**: Microsoft Remote Desktop → `barlo.dunker-hops.ts.net:3389`

## Monitoring: `roles/uptime_kuma` (reused)

Apply the existing `uptime_kuma` role to barlo unchanged. No role modifications needed.

Uptime Kuma runs on barlo, accessible at `barlo.dunker-hops.ts.net:3001` over Tailscale. Monitoring survives internet outages — alerts fire when connectivity restores and Uptime Kuma reconnects to Pushover.

### Monitors (configured via web UI post-deployment)

| Monitor | Type | Target |
|---|---|---|
| Bakery internet | HTTP(S) | `https://google.com` |
| Bakery router/gateway | Ping | Set after deployment |
| Chromecast (TV 1) | Ping | Set after DHCP reservations in bakery UniFi |
| Chromecast (TV N) | Ping | Set after DHCP reservations in bakery UniFi |

**Pushover**: configured in Uptime Kuma web UI under Notifications — no Ansible credentials needed.

**node_exporter**: deployed automatically via the `exporters` play. Existing Prometheus/Grafana stack will graph barlo's health over Tailscale.

## `main.yml` Play

```yaml
- name: setup barlo remote site server
  hosts: barlo
  become: true
  roles:
    - role: ansible_user
    - role: packages
    - role: users
    - role: geerlingguy.ntp
    - role: geerlingguy.security
    - role: artis3n.tailscale.machine
      when: not ansible_check_mode
    - role: desktop
    - role: uptime_kuma
```

`node_exporter` is excluded here — it runs via the existing `exporters` play.

## Taskfile

```yaml
barlo:
  desc: Deploy to barlo remote site server
  cmds:
    - task: ansible
      vars: { PLAYBOOK: "main.yml", LIMIT: "barlo", CLI_ARGS: "{{.CLI_ARGS}}" }
```

## Deployment Sequence

1. `task bootstrap -- --limit barlo.tlesh.xyz -k -K` — creates `ansible` user, installs SSH key, disables password auth
2. `task syntax && task lint` — validate
3. `task barlo -- --check` — dry-run
4. `task barlo` — full deploy
5. Tailscale enrolls via auth key from Doppler (handled by `artis3n.tailscale.machine`)
6. Configure Uptime Kuma monitors + Pushover via web UI at `barlo.tlesh.xyz:3001`

## Post-Move Checklist

- [ ] Update `ansible_host` in `./hosts` to `barlo.dunker-hops.ts.net`
- [ ] Set DHCP reservations for Chromecast devices in bakery UniFi
- [ ] Add Chromecast ping monitors in Uptime Kuma
- [ ] Add bakery router/gateway ping monitor in Uptime Kuma
- [ ] Verify Pushover alerts firing from `barlo.dunker-hops.ts.net:3001`
- [ ] Verify RDP connection from Mac via `barlo.dunker-hops.ts.net:3389`

## Out of Scope

- Managing the bakery UniFi gear via Ansible (separate network/site)
- Caddy/TLS for Uptime Kuma (Tailscale handles transport security)
- Glance/Watchtower (barlo has no Docker services needing auto-update)
