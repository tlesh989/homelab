# Gotchas

Things that bit us once and will again. One entry per gotcha: **symptom → cause → what to do**.
Long stories live in the linked bead or PR. If a lint rule or `.claude/rules/` already enforces it,
it doesn't belong here. Public repo: no `.net` hostnames, no household details.

## Proxmox / LXC

- **Guest eth0 receives frames tagged for other VLANs (60, 40, …)** → on a VLAN-aware `vmbr0`, Proxmox
  trunks every untagged guest NIC to VLANs 2-4094 (hardcoded, `bridge-vids` doesn't limit it) → keep
  `vmbr0` non-VLAN-aware; `tag=N` NICs still work via the auto `vmbr0vN` bridge. (homelab-ngq)
- **`terraform plan` wants to `+ create` an existing LXC** → it migrated to another node; bpg reads the
  node in state and finds nothing (`ignore_changes = [node_name]` doesn't help) → **don't apply**.
  Check the live node (`pvesh get /cluster/resources --type vm`), set `node_name`, then
  `terraform state rm` + `terraform import <resource> <node>/<vmid>`. (#304)
- **`tailscaled` won't start in an LXC** → no `/dev/net/tun`, and bpg can't set raw LXC config → add to
  `/etc/pve/lxc/<vmid>.conf`, then `pct shutdown` + `pct start`:

  ```text
  lxc.cgroup2.devices.allow: c 10:200 rwm
  lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
  ```

- **NFS mount missing in an LXC after reboot** → `x-systemd.automount` is unsupported (no autofs in LXC)
  and stops the plain mount being wanted by `remote-fs.target` → LXCs use `_netdev` only; copy
  `roles/plex` mount opts. VMs (kaz) may keep automount. Containers bind-mounting the path need a
  restart once it mounts. (#296)
- **Beszel agent on a Proxmox host rejected as a duplicate (code 1000)** → LXCs inherit the host's
  hardware UUID, so host and guest share a fingerprint → write a unique 48-hex fingerprint to
  `/var/lib/beszel-agent/fingerprint` on the host and restart the agent. Ansible doesn't touch it.
- **HA guests stuck in `error` after an outage** → `ha-manager set <sid> --state disabled`, then
  `--state started`. If rootfs is on `vm_data` (per-node), the `.conf` must sit on the node holding
  the dataset. Guests start only after storage is up (`pve-wait-storage`); HA uses
  `shutdown_policy=freeze`.

## Ansible

- **`... is undefined` for a fact** → `ansible.cfg` sets `gathering = explicit` → in-house roles add a
  narrow `setup: gather_subset: [pkg_mgr]` task; Galaxy roles (e.g. `geerlingguy.ntp`) need
  `gather_facts: true` on the play.
- **Ansible to Proxmox hosts gets "Connection refused" while manual SSH works** → OpenSSH 9.8
  `PerSourcePenalties` blocks the controller after wrong-key attempts → wait ~60s. Never drop
  `-o IdentitiesOnly=yes` from `ansible.cfg`; the proxmox role exempts the management subnet.
- **`Permission denied (publickey)` on a freshly bootstrapped LXC** → Doppler `SSH_PUBLIC_KEY` must be
  the public half of `~/.ssh/ansible_ed25519` → compare fingerprints with `ssh-keygen -y -f`.
- **A static IP changed and the name stopped resolving** → Pi-hole is authoritative for `*.tlesh.xyz` →
  update `pihole_local_hosts` (roles/pi-hole) and `docs/guides/ip-address-map.md`, then `task pi-hole`.
- **`--check` dry-run fails in beszel** → `roles/beszel` isn't check-mode safe → `--start-at-task` past it.
- **`couldn't resolve module/action 'ansible.posix...'` (or another collection)** → collections load
  only from `galaxy_collections/` (`collections_path` in `ansible.cfg`; the old plural key was silently
  ignored, so `~/.ansible/collections` masked undeclared ones) → declare it in `requirements.yml`,
  then `task reqs`.
- **Hosts run older image versions than the role defaults** → merged Renovate bumps are only applied
  when someone runs the playbook, and Docker deploy tasks skip in `--check` (`when: not
  ansible_check_mode`), so `task check` hides the drift → deploy the host. (homelab-fiq)
- **Ubuntu hosts pile up security updates; unattended-upgrades logs "No packages found"** → a missing
  `;` in the Origins-Pattern block silently drops that origin (geerlingguy.security < 3.0.2; hosts keep
  the old file until the role is re-applied) → check
  `sudo unattended-upgrade --dry-run -d | grep "Allowed origins"`, then apply the role fleet-wide. (homelab-sst)
- **Plex stuck on an old version, `apt update` says "no longer has a Release file"** → Plex moved its
  repo from `downloads.plex.tv/repo/deb` to `repo.plex.tv/deb/` with a new key (`PlexSign.v2.key`) →
  remove the old `.list` and key files, add the new source with `signed-by`, then `apt-get update`;
  `roles/plex` does this since PR #406. (homelab-yx4)
- **truenas role: `truenas_api_client is required`** → it lives in ansible's mise venv (`with` on
  `pipx:ansible-core`); `mise install` skips a changed `with` when the version is unchanged →
  `mise install -f pipx:ansible-core`.

## Networking / UniFi

- **Guest (ginseng) devices on the Express 7's built-in Wi-Fi can't be reached from wired guest
  hosts** (their outbound traffic still works) → loss is inside the Express 7, not the trunk → ginseng
  is not broadcast from the Express 7. (homelab-qey)
- **`unifly` session commands fail with "Two-factor authentication token required"** → use the
  integration API, or raw HTTP to `/proxy/network/api/s/default/rest/...` with `X-API-KEY`.
- **Firewall policy CREATE rejected** → payloads are flat while GET responses are nested
  (`source_zone_id`, not `source.zone_id`); `ip_version` is `IPV4`/`IPV6`/`IPV4_AND_IPV6`;
  `connection_states` must be non-empty.
- **SSID update via API throws `MLO setting requires all of [...]`** (Express 7) → rebind SSIDs in the UI.
- **A server gets TLS errors for one external site, and the cert issuer is "UniFi SSL Certificate Authority"**
  (DNS answers `203.0.113.250` / `2001:db8:1000::fa`) → a UniFi content filter is sinkholing it. A filter
  with `network_ids` set covers the whole network, not just its listed MACs → add the domain to the
  filter's allow list in the UI. NextDNS logs still show these queries as allowed. (sonarr → thexem.info)

## Minecraft (Bedrock)

- **World shows in LAN Games but joining fails with codeword "Boat"** → the discovery reply has
  `AcceptsOnlineAuth=00`, so the client gives up without connecting. Every fresh BDS start reports
  `00` until a join from outside the LAN succeeds; restarts and reboots don't fix it, and restarting
  (including the 03:00 auto-update) resets it → join once by public hostname from off-LAN (e.g.
  cell data). Only the host receiving the public forwards can be fixed this way. (homelab-6z2)
- **`transport=raknet`** → BDS 1.26.52 logs "NetherNet is the only supported transport"; clients can't
  connect. Stay on NetherNet.
- **Join by IP fails** → NetherNet signaling goes through Caddy TLS on 19132, which needs the public
  hostname (SNI). Use the hostname.

## TrueNAS

- **`/api/v2.0/smart/*` returns 404** → SCALE 25.10 removed SMART from REST → use the UI or `midclt`.
  iSCSI target groups are set with `PUT /iscsi/target/id/{id}` (`groups` array); there is no
  `/iscsi/targetgroup`.

## Tooling

- **Claude Code hook doesn't block** → PreToolUse must `exit 2` (not 1); input arrives as JSON on
  stdin (no `$CLAUDE_TOOL_INPUT_*`); matchers match tool names, not paths. Never allow `Bash(bash:*)`,
  because `bash -c` bypasses every deny rule.
- **`bd` refuses pending schema migrations after an upgrade** → migrate on **one** clone only
  (`bd export --all -o <backup> && bd migrate --force && bd dolt push`); other clones `bd dolt pull`.
  Migrating on two clones forks the schema.
- **`unifly: GLIBC_2.43 not found`** → unifly 0.12.0+ release binaries need glibc 2.43; Ubuntu 24.04
  has 2.39 → pinned to 0.11.0, capped in `renovate.json`. Lift once upstream ships a compatible
  build. (homelab-lhs)
- **Shell loop over filenames skips files** → media names contain spaces and quotes → `find ... -print0 |
  while IFS= read -r -d "" f; do ...; done`.
