---
name: diagnose
description: Diagnose connectivity, service health, and container status for a homelab host or service. Use when troubleshooting unreachable hosts, failed services, or network issues.
disable-model-invocation: true
---

# Diagnose Homelab Host or Service

Run diagnostics on a specified host or service to identify issues.

## Usage

`/diagnose [host|service]` — e.g., `/diagnose plex`, `/diagnose glance`, `/diagnose tika`

## Steps

1. **Check Ansible connectivity**
   ```bash
   doppler run -- ansible <host_or_group> -m ping -i hosts
   ```

2. **Check container/VM status on Proxmox** (if applicable)
   ```bash
   doppler run -- ansible proxmox -m shell -a "pct list || qm list" -i hosts
   ```

3. **Check service status on the host**
   ```bash
   doppler run -- ansible <host> -m shell -a "systemctl status <service> --no-pager" -i hosts
   ```

4. **Check Tailscale connectivity**
   ```bash
   doppler run -- ansible <host> -m shell -a "tailscale status" -i hosts
   ```

5. **Check recent service logs** (last 50 lines)
   ```bash
   doppler run -- ansible <host> -m shell -a "journalctl -u <service> -n 50 --no-pager" -i hosts
   ```

6. **Verify host is reachable via Tailscale**
   ```bash
   ping -c 3 <tailscale-hostname>
   ```

## Common Hosts & Services

| Target | Host Group | Service |
|--------|-----------|---------|
| `plex` | `plex` | `plexmediaserver` |
| `glance` | `glance` | `glance` |
| `pihole` | `pihole` | `pihole-FTL` |
| `tailscale` | `tailscale` | `tailscaled` |
| `tika` / `bupu` / `sturm` | `proxmox` | — |

## After Diagnosis

- If connectivity issue: check Tailscale ACLs in `tailscale/policy.hujson`
- If config drift: run `/drift-detector` or `task check`
- If service failed: run `/deploy <target>` to re-apply Ansible role
