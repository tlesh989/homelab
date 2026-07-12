# RustDesk Server OSS — Design

## Problem

RustDesk is installed on a Windows 11 Home PC for remote access, but connecting through
RustDesk's public relay throws a "for testing purposes only" warning on every session. We
want a private, self-hosted RustDesk server so remote sessions run over infrastructure we
control instead of RustDesk's public relay.

This is scoped to the server deployment only. Ansible-managed configuration of the Windows
PC itself (settings, installed apps) is a separate, later effort — Windows has no
SSH/WinRM configured today and is a different problem space.

## Non-goal: saved connections

Saving a connection so you don't have to re-enter the ID/OTP each time is a RustDesk
**client** feature (permanent password + Address Book), independent of which relay server
is in use. It works against the public relay today and isn't a reason to self-host. The
actual driver for self-hosting is avoiding the public-relay "testing only" limitation and
keeping remote-access traffic on infrastructure we control.

## Connectivity assumption

The controlling client (Mac) and the Windows PC will always be reachable via home LAN or
Tailscale — never over the raw public internet. This rules out any need for port
forwarding or public exposure.

kaz (the target host) already runs a native Tailscale client and is reachable at
`100.70.205.92` (confirmed via `tailscale ping`, direct connection — not relayed).

## Approach

Deploy the official `rustdesk/rustdesk-server` Docker images (`hbbs` + `hbbr`) to kaz,
following the existing `roles/n8n` Ansible role pattern for Docker services on kaz.

**Rejected alternatives:**
- Third-party all-in-one image with a web admin UI — unofficial, lags upstream releases,
  adds an unnecessary web UI/attack surface for a feature (device visibility) not needed.
- Native (non-Docker) install on a dedicated LXC — doesn't fit the "non-critical Docker
  services live on kaz" pattern already established for services like n8n and glance.

## Architecture

- New Ansible role: `roles/rustdesk`
- Two containers via `community.docker.docker_container`:
  - `hbbs` — rendezvous/ID server; handles client registration and NAT traversal
  - `hbbr` — relay; handles traffic when direct P2P fails
- Image: `rustdesk/rustdesk-server`, pinned to a major version tag (e.g. `:1`), per
  `docker.md` tagging convention. Watchtower already covers all containers on kaz — no
  separate Watchtower entry needed.
- **Network exposure**: published ports bound to kaz's Tailscale IP specifically
  (`100.70.205.92:<port>:<port>`), not `0.0.0.0`. This makes the service unreachable from
  the LAN interface entirely — Tailscale-only, no public exposure, no port forwarding.
- Ports (default RustDesk scheme): `21115/tcp`, `21116/tcp+udp`, `21117/tcp`,
  `21118/tcp`, `21119/tcp`
- Named Docker volume for `hbbs`'s persistent ed25519 keypair. This is the trust root
  for the whole setup — losing it breaks every client's saved server connection, and
  leaking it lets someone stand up a rogue relay your clients would trust. Generated
  in-container on first run; not templated, stored in Doppler, or committed to the repo.

## Variables (`roles/rustdesk/defaults/main.yml`)

| Variable | Purpose |
|---|---|
| `rustdesk_version` | Pinned major image tag (e.g. `"1"`) |
| `rustdesk_tailscale_ip` | kaz's Tailscale IP; scopes all port bindings |
| `rustdesk_data_path` | Host path for the `hbbs` key-persistence volume |

Port numbers are fixed defaults in the role (standard RustDesk scheme), not expected to
vary.

## Tasks (`roles/rustdesk/tasks/main.yml`)

1. Create data directory for key persistence (`ansible.builtin.file`, owned/chmod'd
   appropriately, `become: true`)
2. Deploy `hbbs` container — ports bound to `rustdesk_tailscale_ip`, volume mounted,
   `restart_policy: always`
3. Deploy `hbbr` container — same image, relay-mode args, ports bound to
   `rustdesk_tailscale_ip`

Follows the existing `roles/n8n` structure and Docker Python SDK / `become: true`
conventions.

## Data flow

1. RustDesk client (Mac/iPhone) connects to `hbbs` on kaz over Tailscale (port 21116) to
   look up the Windows PC's registered ID and attempt direct P2P hole-punch.
2. If P2P fails, traffic falls back through `hbbr` as a relay — still entirely over
   Tailscale, never touching the public internet.
3. The Windows client is configured once with kaz's Tailscale IP and `hbbs`'s public key
   (from the generated keypair) as its ID/relay server, replacing RustDesk's public
   server.

## Security

- No public or LAN exposure — ports are bound only to the Tailscale interface IP.
- The `hbbs` keypair is not shared via bind-mount, Doppler, or committed anywhere; it
  stays host-local in the named volume.

## Verification

1. `task syntax && task lint` for the new role
2. `task rustdesk -- --check` dry-run, then `task rustdesk` to apply
3. `docker logs hbbs` on kaz shows key generation with no bind errors
4. Configure both RustDesk clients (Mac controller, Windows target) to point at the new
   server and confirm a live test connection succeeds without the "testing purposes
   only" warning

## New Service Checklist

- **Watchtower**: already covers all containers on kaz — no action needed
- **Uptime Kuma**: add a TCP port monitor for `100.70.205.92:21116` (hbbs)
- **Glance**: not applicable — RustDesk server has no web UI
