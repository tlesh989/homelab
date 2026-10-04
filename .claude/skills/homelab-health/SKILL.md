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
- Run `ansible ... -m shell` with `-o` and a `timeout`; a host that fails to answer is itself a finding (🔴), not a reason to stop.
- Sections are independent — run them in parallel where possible.
- Never print secrets or public-domain hostnames.

## Sections

1. **memory** — the TrueNAS-swap lesson. Thresholds: 🔴 any swap in use or OOM kill, or RAM used >90%; 🟡 RAM used >85% or allocation >2x peak need.
   ```bash
   doppler run -- ansible 'all:!truenas:!unifi' -i hosts -o -m shell -a "free -m | awk '/Mem|Swap/'; cat /proc/pressure/memory; dmesg 2>/dev/null | grep -ci 'out of memory'"
   doppler run -- ansible proxmox -i hosts -m shell -a "pvesh get /cluster/resources --type vm --output-format json"   # allocated vs used per guest
   ```
   Compare against `memory` in `terraform/` for each guest and suggest the new size. Beszel on kaz (`:8090`) has longer history if a spike is in question.
2. **nodes** — per Proxmox node: RAM/swap, CPU, overcommit ratio (sum guest RAM / node RAM; 🟡 >1.0), storage fill (🟡 >80%, 🔴 >90%) for `truenas-lvm` and local, `systemctl --failed`, `pvecm status` quorum.
3. **truenas** (`ansalon`) — via the API (`TRUENAS_HOST`, `TRUENAS_API_KEY`): pool status, last scrub age (🟡 >35d), SMART/disk alerts, active alerts, ARC size vs RAM, swap used (🔴 any), iSCSI/NFS session counts.
4. **logs** — per host, last 24h, grouped so repeats surface:
   ```bash
   journalctl -p err --since -24h --no-pager -o cat | sed -E 's/[0-9]+/N/g' | sort | uniq -c | sort -rn | head -10
   ```
   Also `systemctl --failed` and `docker ps -a --format '{{.Names}} {{.Status}}' | grep -i restart`. A pattern with count >=20, or seen on multiple days, is a finding — name the host, count and likely fix.
5. **network** — rogue/noisy devices:
   - `doppler run -- unifly clients list -o json`; any client whose MAC/IP/name is absent from `docs/known-hosts.md` is 🔴 unknown. Also flag clients with outsized tx/rx, rapid DHCP churn, or offline known devices.
   - Pi-hole (`PIHOLE_ADMIN_PASSWORD`): top clients and top blocked domains; one client dominating queries (>40%) is 🟡.
6. **uptime** — Uptime Kuma monitors currently down or flapping (`AUTOKUMA_USERNAME`/`AUTOKUMA_PASSWORD`; see `docs/runbooks/uptime-kuma-monitors.md`).

If a section's tool or credential is unavailable (e.g. `unifly` not installed), say so under that section and continue with what works.

## Report format

```
HOMELAB HEALTH — <date>
🔴 Act now   — <host>: <finding> → <suggested fix>
🟡 Watch     — ...
🟢 OK        — one line per section
```

Keep it ranked and terse. Finish by offering to file `bd create` issues for the 🔴/🟡 items — do not create them unprompted. Offer to append confirmed-good unknown clients to `docs/known-hosts.md`.
