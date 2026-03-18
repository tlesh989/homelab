# Proxmox + TrueNAS Infrastructure Optimization Design

**Date:** 2026-03-18
**Status:** Approved for implementation planning

---

## Context

Three-node Proxmox cluster (tika, bupu, sturm) backed by a UGREEN DXP4800 Plus NAS running TrueNAS SCALE 25.x. All LXC root disks currently live on local storage. iSCSI shared storage is configured but untested and unused. TrueNAS is an unvalidated replacement for a previous Synology NAS.

### Hardware summary

| Node | Hardware | RAM | Role |
|------|----------|-----|------|
| tika (.7) | KAMRUI AK2 Plus, N100 | 16GB | Proxmox node; runs tailscale LXC |
| bupu (.8) | KAMRUI AK2 Plus, N100 | 16GB | Proxmox node; mostly idle |
| sturm (.9) | ACEMAGICIAN Kron Mini K1, Ryzen 7 5825U | 32GB | Proxmox node; runs all LXCs |

Each mini PC has two internal disks: a smaller SSD for the Proxmox OS, and a 512GB data disk.

**TrueNAS NAS:** UGREEN DXP4800 Plus, 4×4TB RAID5 (~12TB usable). Provides iSCSI block storage (`pve-iscsi` LVM VG — must be connected and visible on all three cluster nodes for HA to work) and will provide NFS shares for media.

---

## Goals

- Validate the TrueNAS storage stack before any workloads depend on it
- Get Plex working end-to-end with media on TrueNAS NFS
- Add observability across the cluster and NAS (currently none)
- Enable HA for critical services (pi-hole) using iSCSI shared storage
- Ensure LXC/VM data lives on the correct disk on each node

---

## Approach: Foundation First (Option A)

Three sequential phases, each independently valuable.

---

## Phase 1: Local Storage Setup + Storage Validation + Observability

### 1a. Local data disk setup (prerequisite)

Each mini PC has a 512GB data disk that must be configured as a dedicated Proxmox storage pool before any LXC/VM data is placed on it. LXC root disks must NOT live on the OS disk (`local`/`local-lvm`).

- Add the 512GB disk on each node as an LVM-thin storage pool (e.g., `local-data`)
- Configure it as the default storage target for new LXCs/VMs on each node
- Managed via `roles/proxmox` Ansible role
- Verifiable via `pvesh get /nodes/<node>/storage` or Terraform `proxmox_virtual_environment_storage`

**This is a hard prerequisite for all subsequent phases.**

### 1b. iSCSI storage validation

**Prerequisite:** Verify that the iSCSI target is connected and `pve-iscsi` LVM VG is visible on all three nodes (tika, bupu, sturm), not just sturm. Proxmox HA requires the shared storage to be accessible from every potential failover node. Check with `pvesh get /nodes/<node>/storage` on each node.

**Multipath:** Verify `multipathd` status on each node. If the iSCSI initiator creates duplicate device nodes, multipath must be correctly configured or explicitly disabled. Check with `multipath -ll`.

Run `fio` benchmarks against the `pve-iscsi` LVM VG on sturm before migrating any workloads to it.

Benchmark targets:
- Sequential read/write throughput (128K block, queue depth 32)
- Random 4K IOPS (queue depth 1 and 32)
- Latency (clat/lat percentiles at 4K random read)

Pass criteria (calibrated for 1GbE network — adjust up if 10GbE is in use):
- Sequential write ≥ 100MB/s
- Random 4K read IOPS ≥ 500
- 99th percentile latency < 10ms

If benchmarks fail or show instability, investigate TrueNAS iSCSI config, network path, and jumbo frames before proceeding to Phase 3.

**Multipath configuration:** Rather than just checking `multipathd` status, define an explicit `/etc/multipath.conf` via `roles/proxmox` Ansible role. Set `path_grouping_policy` to `failover` (single path to TrueNAS) and blacklist local NVMe/SATA drives so multipath only manages TrueNAS LUNs. This prevents path thrashing if TrueNAS restarts an iSCSI portal.

**Corosync / 1GbE saturation:** If all nodes share a single 1GbE NIC, iSCSI and NFS traffic can starve Corosync (UDP 5404–5405), causing a node to ghost and trigger a false HA failover. Monitor network latency via Netdata after Phase 1. If false fencing events occur in Phase 3, implement QoS with `tc` to prioritize Corosync traffic over storage traffic.

### 1c. TrueNAS NFS share for Plex media

- Create a TrueNAS dataset for Plex media (e.g., `tank/media/plex`)
- Export as NFS share, restricted to Proxmox node IPs
- Mount on sturm via `/etc/fstab` with both `_netdev` and `x-systemd.automount` options. `x-systemd.automount` mounts the share on-demand when the Plex LXC first accesses the bind mount path, preventing the Proxmox host boot sequence from hanging if TrueNAS is offline or still booting at the same time
- Pass through to Plex LXC as a bind mount (`mp` config)
- Add to `roles/truenas` Ansible role and `roles/plex` for the bind mount config

### 1d. Observability: Netdata

Add a lightweight monitoring LXC on sturm.

**Tool choice: Netdata** (over Prometheus+Grafana)
- Zero-config to useful metrics; runs on 512MB RAM
- Native Proxmox and TrueNAS integrations
- Parent-child streaming: all three Proxmox nodes report into one Netdata LXC
- TrueNAS Netdata plugin: pool health, SMART status, iSCSI metrics

**Implementation:**
- Terraform: provision `netdata` LXC on sturm (local-data storage, 512MB RAM, 8GB disk)
- Ansible `roles/netdata`: install Netdata, configure as parent; install Netdata agent on tika/bupu/sturm as children streaming to parent
- TrueNAS: enable Netdata plugin in TrueNAS reporting settings
- Glance: add Netdata dashboard link as a tile

**Phase 1 deliverables:**
- [ ] 512GB data disks configured as `local-data` on all three nodes
- [ ] fio benchmark results documented
- [ ] Plex NFS share mounted and accessible in Plex LXC
- [ ] Netdata LXC running, all nodes reporting, TrueNAS metrics visible

---

## Phase 2: Plex + Hardware Transcoding

### Plex LXC configuration

- Plex LXC is already privileged (unprivileged: no) — no change needed
- Bind mount for NFS media path added in Phase 1
- Configure Plex library to use the NFS-mounted media path

### Hardware transcoding via VAAPI

The Ryzen 7 5825U in sturm has an integrated Radeon GPU (Vega) supporting VAAPI.

- Verify GPU accessibility on Proxmox host: `vainfo`
- Pass VAAPI device (`/dev/dri/renderD128`) into Plex LXC via LXC `dev` config and `lxc.cgroup2.devices.allow`
- Ensure the `render` group GID inside the LXC matches the host GID — privileged LXCs share the host UID/GID namespace, so a GID mismatch is the most common VAAPI failure mode. Verify with `stat /dev/dri/renderD128` on the host and match inside the LXC. Add the Plex user to the `render` group inside the LXC.
- Enable hardware transcoding in Plex settings (VAAPI)
- Add VAAPI device passthrough and render group configuration to `roles/plex` Ansible role

**Node constraint:** Plex must stay on sturm — it's the only node with GPU passthrough configured and the NFS mount. This is intentional.

**Phase 2 deliverables:**
- [ ] Plex media library populated and accessible
- [ ] Hardware transcoding confirmed working (check Plex dashboard during a transcode)

---

## Phase 3: LXC Distribution + HA

### Prerequisites

- Phase 1 complete: iSCSI validated, local-data pools configured

### Storage migration strategy

Only services that benefit from HA need to move to iSCSI. Proxmox HA requires block storage (iSCSI) — NFS does not support the fencing/locking mechanism needed for safe failover.

| LXC | Root disk storage | Reason |
|-----|------------------|--------|
| plex | local-data (sturm) | Stays on sturm for GPU; HA not needed |
| pi-hole | pve-iscsi (shared) | DNS is critical; HA restart on another node |
| glance | local-data (sturm or bupu) | Stateless; easily recreated |
| tailscale | local-data (tika) | Intentionally on tika; HA not needed |
| netdata | local-data (sturm) | Stateless parent; agents survive node restarts |

### Proxmox HA prerequisites

**Fencing (watchdog):** Proxmox HA requires a fencing mechanism to safely restart a container on another node without risk of split-brain. Mini PCs without IPMI/iDRAC must use the software watchdog. Configure `watchdog-mdev` on each node (`/etc/default/pve-ha-manager`) and verify with `pvesh get /nodes/<node>/status`. This is a hard requirement — HA will refuse to act or may cause data corruption without it.

Explicitly load the `softdog` kernel module via `roles/proxmox` by dropping `/etc/modules-load.d/softdog.conf` on each node. Proxmox can configure this via the UI, but IaC management ensures deterministic behavior across reimages.

### pi-hole HA migration

- **Disk migration (manual step):** The `bpg/proxmox` Terraform provider does not support live disk migration. Migrating pi-hole's root disk from local to `pve-iscsi` requires a manual `pct move_volume <vmid> rootfs pve-iscsi` on the Proxmox host. This is a one-time manual operation; subsequent state is managed via Terraform. **Immediately after the move**, update the Terraform resource's storage reference to `pve-iscsi` and run `terraform apply` to re-sync state — otherwise `terraform plan` will detect drift and attempt to recreate the disk. As a safety net during migration, temporarily add `lifecycle { ignore_changes = [disk] }` to the pi-hole resource.
- Create HA resource for pi-hole LXC via `proxmox_virtual_environment_haresource` in Terraform
- HA group: prefer sturm, failover to bupu/tika
- Test: shut down sturm, verify pi-hole restarts on another node within the HA timeout

### Node distribution (optional, low priority)

tika and bupu are currently near-idle. Lighter stateless LXCs (glance, netdata) can be distributed across nodes to reduce sturm's load. This is not required for HA but improves resource utilization.

**Phase 3 deliverables:**
- [ ] pi-hole root disk migrated to `pve-iscsi`
- [ ] HA resource configured and tested (manual failover test)
- [ ] LXC distribution documented in `project_lxc_locations.md` memory

---

## What's Out of Scope

- **NAS data backup:** Deferred until drive prices make a second NAS or off-site backup practical
- **UniFi as code:** Independent track, can be picked up any time via Terraform `paultyng/unifi` provider
- **Kubernetes:** Not currently planned
- **kaz Docker host:** Commented out; not part of this plan

---

## Key Constraints

- All media workloads stay on sturm (GPU for transcoding)
- LXC/VM root disks must use `local-data` (512GB disk), not `local`/`local-lvm` (OS disk)
- iSCSI benchmarks must pass before Phase 3 begins
- All configuration managed via Terraform + Ansible; no manual Proxmox UI changes that aren't reflected in code
- Secrets via Doppler only
