Viewed 2026-03-18-proxmox-truenas-optimization-design.md:1-189

This is an exceptionally well-thought-out SRE design document. You’ve correctly prioritized foundational stability (validation, storage segregation, observability) before moving workloads, which aligns perfectly with our core principles of Uptime, Stability, and Latency.

Here are my thoughts on the plan, along with a few proactive tweaks to ensure we don't hit edge cases in production.

### What works exceptionally well (The Good)

1. **Validation Before Execution**: Running `fio` benchmarks and validating `multipathd` before moving any stateful workloads to iSCSI is textbook SRE.
2. **Storage Segregation**: Separating the OS disks (`local-lvm`) from VM/LXC disks (`local-data`) guarantees that rogue I/O or a full disk in an LXC won't crash the Proxmox host.
3. **Observability Choices**: Choosing Netdata over Prometheus/Grafana is a great application of the KISS principle. It provides immediate value with minimal overhead for a 3-node cluster.
4. **HA Primitives**: Recognizing that `pi-hole` is the only truly critical service requiring HA, and calling out the `watchdog-mdev` soft-fencing requirement. Without fencing, Proxmox HA is a split-brain disaster waiting to happen.

### SRE Recommendations & Considerations

**1. NFS Resiliency (Phase 1c)**

* **The Risk**: Static mounts in `/etc/fstab` or direct `systemd.mount` units can hang the Proxmox boot sequence if the TrueNAS box is offline or rebooting at the same time.
* **The Fix**: Use `x-systemd.automount` in the `options` of `/etc/fstab` (or `Automount=` in systemd). This mounts the NFS share on-demand when the Plex LXC tries to access the bind mount, preventing host-level boot hangs.

**2. Corosync Latency vs. Storage I/O (Phase 1b/3)**

* **The Risk**: If your mini PCs only have a single 1GbE NIC, iSCSI traffic (especially during high I/O) or Plex NFS streaming can saturate the link. Proxmox Corosync is highly sensitive to latency; if it gets starved, a node might "ghost" and trigger an unnecessary HA failover of pi-hole.
* **The Fix**: Keep an eye on the Netdata latencies. If you experience false HA fencing, we may need to implement simple QoS (using `tc`) to prioritize Corosync traffic (UDP 5404-5405) over storage traffic.

**3. Software Watchdog Reliability (Phase 3)**

* **The Risk**: Relying on the `softdog` module for fencing.
* **The Fix**: Ensure your Ansible `roles/proxmox` explicitly loads the softdog module by dropping a file in `/etc/modules-load.d/softdog.conf`. Proxmox usually handles this if configured in the UI, but since we are doing infrastructure-as-code, explicitly loading the module ensures deterministic behavior.

**4. The `pct move_volume` Terraform State Drift (Phase 3)**

* **The Risk**: You noted that shifting pi-hole to `pve-iscsi` requires a manual `pct move_volume`. When you run `terraform plan` afterwards, Terraform might see a drift in the storage pool and attempt to recreate the disk.
* **The Fix**: Be prepared to either update the Terraform resource to point to the new storage pool *immediately* after the manual move so the next `apply` is a no-op, or temporarily use `lifecycle { ignore_changes = [disk] }` while migrating.

**5. iSCSI Multipath Configuration**

* **The Risk**: Without an explicit `/etc/multipath.conf`, Proxmox might use default settings that result in path thrashing if TrueNAS restarts an iSCSI portal.
* **The Fix**: Define a basic `multipath.conf` via Ansible that sets `path_grouping_policy` to `failover` or `multibus` depending on your network topology, and blacklist Proxmox local NVMe/SATA drives so multipath only attempts to manage the TrueNAS LUNs.

Overall, this is a green light. The phased approach guarantees that if something breaks (like the iSCSI benchmarks failing), we can abort without impacting Plex or pi-hole.
