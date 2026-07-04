# IP Address Management — Design

**Date:** 2026-06-20
**Status:** Approved (design)
**Author:** Tom Lesh + Claude

## Problem

The homelab has four systems that each hold IP / hostname facts, and they have
silently drifted out of sync:

| System    | Holds                                          | Edit surface          |
|-----------|------------------------------------------------|-----------------------|
| UniFi     | DHCP pool + reservations (by MAC), live leases | UniFi UI / `unifly`   |
| repo map  | human documentation (`docs/guides/ip-address-map.md`) | git (markdown)  |
| pi-hole   | hostname → IP (local split-horizon DNS)        | `roles/pi-hole/defaults` |
| Caddy     | hostname → backend IP:port (HTTPS)             | `roles/caddy/defaults`   |

Concrete drift found while scoping this work (all currently live):

| Issue            | IP map        | pi-hole   | Caddy                  |
|------------------|---------------|-----------|------------------------|
| **homeassistant**| `.35` (RPi)   | **`.125`**| —                      |
| **Caddy (.17)**  | *missing*     | `.17`     | `.17` services         |
| **uptime-kuma**  | *missing*     | → .17     | upstream **`.16`** (missing from map) |
| **arr**          | *missing*     | `.24`     | `.24:5055`             |
| **claude-code**  | `.26`         | *missing* | —                      |

The triggering incident: a new `claude-code` LXC was assigned `192.168.233.25`,
which the user's MacBook already holds via a DHCP lease — even though `.25` sits
inside the documented *static* range (`.1–.50`), implying UniFi's real DHCP pool
boundary does not match the documented `.51` start. The assignment was made
without checking UniFi or the map first.

The root cause is that **the repo map is prose, not data** — nothing can
mechanically compare it against the other three systems — and there is **no
pre-assignment check**.

## Goal

End-to-end consistency across UniFi ↔ repo ↔ pi-hole ↔ Caddy, achieved by:

1. A single **structured inventory** as the source of truth for infrastructure.
2. **Drift detection** that compares all four systems and reports mismatches.
3. A **pre-assignment check** so the next `.25`-class collision can't happen.

## Authority model — Hybrid

- **Infrastructure** (the `.1–.50` static range, IaC-managed hosts): the repo
  inventory YAML is authoritative.
- **Personal / transient devices** (MacBook, phones, family devices): UniFi
  stays authoritative. The inventory records them only as *claimed* entries so
  nothing is assigned over them.
- A reconcile tool flags drift in **both** directions.

We do **not** manage personal devices declaratively, and we do **not** write to
UniFi/pi-hole/Caddy (see Non-Goals).

## Scope — Phased

### Phase 1 (this spec)
Add the structured inventory + read-only check/reconcile tooling. **Working
roles are left untouched.** Immediate value: catches all the drift above and
prevents future collisions.

### Phase 2 (sketched, NOT built here)
Render `pihole_local_hosts`, `caddy_services`, and `ip-address-map.md` *from*
the inventory YAML (via `include_vars` + a generator or Jinja), so repo-internal
drift becomes structurally impossible. The Phase 1 inventory is placed in
`group_vars/` specifically so Phase 2 roles can consume it with no migration.

## Architecture

```
                 ┌─────────────────────────────────────┐
   source of      │  group_vars/all/network_inventory.yml │  ← single structured
   truth (infra)  │  (networks, hosts, MACs, DNS, …)       │     source for infra
                 └──────────────────┬────────────────────┘
                                    │ read by scripts/ip_inventory.py
        ┌───────────────────────────┼───────────────────────────┐
        ▼                           ▼                             ▼
  reconcile (live)         check (CI-safe)                 next (helper)
  + UniFi via unifly       inventory ↔ pihole ↔ caddy       "is .42 free?" /
  + leases/reservations    (no network)                     "next free static IP"
        │                           │
        ▼                           ▼
   drift report               drift report
  (Blocking/Advisory)        (Blocking/Advisory)
```

### Component 1 — Inventory file

**Location:** `group_vars/all/network_inventory.yml`

This requires converting `group_vars/all.yml` (currently a file) into a
`group_vars/all/` **directory** so Ansible merges multiple all-scoped files:

- `group_vars/all/connection.yml` ← existing `all.yml` content, moved verbatim
- `group_vars/all/network_inventory.yml` ← new

Schema:

```yaml
networks:
  main:
    cidr: 192.168.233.0/24
    dhcp_pool: ["192.168.233.51", "192.168.233.220"]
    static:    ["192.168.233.1",  "192.168.233.50"]
    personal:  ["192.168.233.240", "192.168.233.250"]
  iot:     { cidr: 192.168.40.0/24,  dhcp_pool: ["192.168.40.10", "192.168.40.200"] }
  storage: { cidr: 192.168.220.0/24 }   # no DHCP, static only

hosts:
  - name: tika
    ip: 192.168.233.7
    mac: null                 # static IP via cloud-init → no reservation expected
    assignment: static        # static | reservation | dynamic-noted
    managed_by: terraform     # terraform | ansible | unifi | manual
    dns: [tika.tlesh.xyz]
    notes: "Proxmox node"
  - name: macbook
    ip: 192.168.233.25
    mac: null
    assignment: dynamic-noted # UniFi owns it; recorded so nothing claims .25
    managed_by: manual
    dns: []
    notes: "Personal device — do not assign to infrastructure"
```

`assignment` drives the reconcile logic:
- `static` — IP set by cloud-init/Terraform; **no** UniFi reservation expected,
  but the IP MUST fall in a static range that UniFi's DHCP pool never serves.
- `reservation` — UniFi MUST have a matching MAC↔IP reservation.
- `dynamic-noted` — UniFi owns it; inventory only reserves the slot logically.

### Component 2 — `scripts/ip_inventory.py`

One Python script (PyYAML; already a dependency surface via `requirements.txt`)
with three subcommands. UniFi data comes from `unifly` (JSON) via `subprocess`.

**`check`** — repo-internal, no network, CI-safe. Loads the inventory plus
`roles/pi-hole/defaults/main.yml` (`pihole_local_hosts`) and
`roles/caddy/defaults/main.yml` (`caddy_services`). Flags:
- duplicate IPs within the inventory
- a host's IP differing between inventory / pi-hole / caddy (→ homeassistant
  `.35` vs `.125`)
- pi-hole A records or caddy upstreams pointing at IPs absent from the inventory
  (→ `.16`, `.24`, `.17`)
- inventory hosts with no pi-hole / caddy presence (advisory)

Exits non-zero on any Blocking finding so it can gate CI.

**`reconcile`** — everything `check` does **plus** live UniFi:
- `assignment: reservation` hosts: confirm a UniFi reservation exists with the
  matching MAC↔IP
- detect IPs in a documented *static* range that UniFi handed out *dynamically*
  (this is how `.25` slipped through — surfaces a wrong DHCP-pool boundary)
- verify UniFi's actual DHCP pool boundaries match the documented ranges
- list UniFi clients with an IP not present in the inventory (advisory —
  candidate undocumented devices)

Local-only (UniFi is unreachable from GitHub CI). If `unifly` auth/connection
fails, the UniFi section is skipped with a warning and the repo checks still run.

**`next`** — pre-assignment helper:
- `next` → prints the lowest free IP in the main static range, computed from
  inventory ∪ live UniFi leases/reservations
- `next <ip>` → reports whether that specific IP is free

### Component 3 — Task commands

Wire into `Taskfile.yml`:

```
task ip:check        # repo-internal consistency (CI-safe)
task ip:reconcile    # check + live UniFi drift
task ip:next         # next free static IP
task ip:next -- <ip> # is <ip> free?
```

`task ip:check` is added to the CI path (`task ci` / `.github/workflows/ci.yml`)
as a non-network gate. `reconcile` / `next` stay local-only.

### Output format

Findings grouped **Blocking** (IP conflict, reservation MAC↔IP mismatch, dynamic
lease inside a static range) vs **Advisory** (undocumented client, host offline,
unknown MAC), mirroring the existing `drift-detector` agent convention. Blocking
findings set a non-zero exit code.

### Error handling

- `unifly` missing/unauthenticated → warn, skip UniFi section, run repo checks,
  exit code reflects repo findings only.
- Malformed inventory YAML → hard error with the offending key.
- A `reservation` host with `mac: null` → Blocking ("reservation requires MAC").

## Non-Goals (YAGNI)

- No writes to UniFi, pi-hole, or Caddy (read-only throughout Phase 1).
- No declarative management of personal devices.
- No daemon/service — on-demand `task` commands only.
- Phase 2 (render-from-YAML) is sketched, not implemented.

## Verification (Definition of Done)

- `group_vars/all/` directory loads cleanly (`task syntax`, `task lint`, a spot
  `task check` shows no unexpected diff from the `all.yml` → `all/` move).
- `python scripts/ip_inventory.py check` reports the five known drifts above and
  exits non-zero.
- `task ip:reconcile` runs against live UniFi and flags the `.25` static-range
  dynamic lease.
- `task ip:next` returns a free static IP that is confirmed free in UniFi.
- The known drifts are then resolved (inventory + pi-hole/caddy reconciled) so a
  clean `task ip:check` exits zero.
