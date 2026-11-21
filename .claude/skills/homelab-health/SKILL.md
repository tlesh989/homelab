---
name: homelab-health
description: Read-only health audit of the homelab — guest RAM/swap sizing, Proxmox nodes, TrueNAS, recurring log errors, rogue LAN devices, and Uptime Kuma state. Use for periodic checkups or when suspecting resource pressure.
disable-model-invocation: true
---

# Homelab Health Audit

Report-only. Never changes hosts, config, or issues. Ends with a ranked report.

## Usage

`/homelab-health [memory|nodes|truenas|logs|network|uptime]` — no argument runs all sections.

## Rules

- Use `doppler run -- ...` for anything needing secrets; inventory is `-i hosts`.
- Run `ansible ... -m shell` with a `timeout` (no `-o`, it is deprecated), and `-b` for anything that needs root (`pvecm`, `pvesm`, `docker`); a host that fails to answer is itself a finding (🔴), not a reason to stop.
- Sections are independent — run them in parallel where possible.
- Never print secrets or public-domain hostnames.

## Sections

1. **memory** — the TrueNAS-swap lesson. Thresholds: 🔴 any swap in use or OOM kill, or RAM used >90%; 🟡 RAM used >85% or allocation >2x peak need.
   ```bash
   doppler run -- ansible 'all:!truenas:!unifi' -i hosts -b -m shell -a "free -m | awk '/Mem|Swap/'; cat /proc/pressure/memory; dmesg 2>/dev/null | grep -ci 'out of memory' || true"   # || true: grep -c exits 1 on a count of 0
   doppler run -- ansible proxmox -i hosts -m shell -a "pvesh get /cluster/resources --type vm --output-format json"   # allocated vs used per guest
   ```
   Compare against `memory` in `terraform/` for each guest and suggest the new size. Beszel on kaz (`:8090`) has longer history if a spike is in question.
2. **nodes** — per Proxmox node: RAM/swap, CPU, overcommit ratio (sum guest RAM / node RAM; 🟡 >1.0), storage fill (🟡 >80%, 🔴 >90%) for `truenas-lvm` and local, `systemctl --failed`, `pvecm status` quorum.
   ```bash
   doppler run -- ansible proxmox -i hosts -b -m shell -a "pvecm status | grep -E 'Quorate|Total votes'; pvesm status"
   ```
3. **truenas** (`ansalon`) — via the websocket API, not REST (`TRUENAS_HOST` in Doppler is a `wss://.../api/current` URL; use `truenas_api_client` from ansible's venv as `roles/truenas/library/truenas_api.py` does, with `TRUENAS_API_KEY`): pool status, last scrub age (🟡 >35d), SMART/disk alerts, active alerts, ARC size vs RAM, swap used (🔴 any), iSCSI/NFS session counts.
   Run calls with `doppler run -- "$(mise where pipx:ansible-core)/ansible-core/bin/python3" -I <script>`, logging in with `Client(uri=os.environ["TRUENAS_HOST"], verify_ssl=False)` + `c.call("auth.login_with_api_key", os.environ["TRUENAS_API_KEY"])`:
   - iSCSI: `iscsi.global.sessions` (list; each Proxmox node's storage IP should appear, 🔴 if one is missing). NFS: `nfs.client_count`.
   - ARC vs RAM: `reporting.netdata_get_data([{"name": "arcsize"}], {"unit": "HOUR", "aggregate": True})[0]["aggregations"]["mean"]["size"]` against `system.mem_info()["physmem_size"]`; the `memory` graph's `available` mean is free RAM. Relative `start`/`end` offsets are rejected — use `unit`.
4. **logs** — per host, last 24h, grouped so repeats surface:
   ```bash
   journalctl -p err --since -24h --no-pager -o cat | sed -E 's/[0-9]+/N/g' | sort | uniq -c | sort -rn | head -10
   ```
   Also `systemctl --failed` and `docker ps -a --filter status=restarting` (no `--format '{{...}}'` inside `ansible -a`: Jinja eats the braces). A pattern with count >=20, or seen on multiple days, is a finding — name the host, count and likely fix.
5. **network** — rogue/noisy devices:
   - ```bash
  doppler run -- sh -c 'UNIFI_URL=https://192.168.233.1 UNIFI_INSECURE=true mise exec -- unifly clients list --all -o json-compact' | grep -v '^Showing'
  ```
  (`unifly` reads `UNIFI_API_KEY` from Doppler; no config file or keyring.) Any client whose MAC is absent from the Doppler secret `KNOWN_DEVICES` (`mac|name|ip` lines; read it with `doppler secrets get KNOWN_DEVICES --plain`) is 🔴 unknown. Also flag clients with outsized tx/rx, rapid DHCP churn, or offline known devices.
   - Pi-hole (`PIHOLE_ADMIN_PASSWORD`): top clients; one client dominating queries (>40%) is 🟡. Pi-hole v6 API on `192.168.233.3:8080`: `POST /api/auth` with `{"password": ...}` → `.session.sid`, then `GET /api/stats/top_clients?count=10` with header `sid: <sid>` → `.clients[] {name, ip, count}` and `.total_queries`; `DELETE /api/auth` with the same header afterwards. Skip blocked domains: Pi-hole only serves local names (NextDNS filters), so blocked is always 0.
6. **uptime** — Uptime Kuma monitors currently down or flapping (see `docs/runbooks/uptime-kuma-monitors.md`). `/metrics` only accepts a Kuma API key (username/password basic auth gets 401), and none is in Doppler yet — until one is, report this section as unavailable.

If a section's tool or credential is unavailable (e.g. `unifly` not installed or UniFi unreachable), say so under that section and continue with what works.

## Report format

```
HOMELAB HEALTH — <date>
🔴 Act now   — <host>: <finding> → <suggested fix>
🟡 Watch     — ...
🟢 OK        — one line per section
```

Keep it ranked and terse. Finish by offering to file `bd create` issues for the 🔴/🟡 items — do not create them unprompted. Offer to add confirmed-good unknown clients to `KNOWN_DEVICES` in Doppler.
