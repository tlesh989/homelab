# Gotchas

Things that bit us once and will again. One entry per gotcha: **symptom → cause → what to do**.
Long stories live in the linked bead or PR. If a lint rule or `.claude/rules/` already enforces it,
it doesn't belong here. Public repo: no `.net` hostnames, no household details.

## Proxmox / LXC

- **Service misbehaves after a NIC was added to a running LXC** → Terraform hot-plugs
  `network_interface` changes; processes started before keep stale network state → `pct reboot <vmid>`
  after any NIC change. (homelab-6z2)
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

## Minecraft (Bedrock)

- **World shows in LAN Games but joining fails with codeword "Boat"** → the server's discovery reply
  says "not joinable"; the client gives up without connecting. Seen after a NIC hot-plug → reboot the
  LXC. (homelab-6z2)
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
- **Shell loop over filenames skips files** → media names contain spaces and quotes → `find ... -print0 |
  while IFS= read -r -d "" f; do ...; done`.
