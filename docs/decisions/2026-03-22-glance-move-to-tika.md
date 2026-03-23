# Glance LXC Move to Tika

**Date:** 2026-03-22

## Decision

Move the Glance LXC (VMID 104) from `sturm` to `tika` and change it from unprivileged to privileged to support Tailscale.

## Why

Tailscale requires `/dev/net/tun`, which is unavailable in unprivileged LXC containers without explicit Proxmox host configuration. Sturm was already heavily loaded with other services. Tika hosts the existing Tailscale LXC (101), which already has the necessary TUN device configuration pattern established.

## What Changed

- `terraform/glance.tf`: `node_name` changed from `sturm` to `tika`, `unprivileged` changed from `true` to `false`, `node_name` removed from `lifecycle.ignore_changes`
- `/etc/pve/lxc/104.conf` on tika: added `lxc.cgroup2.devices.allow: c 10:200 rwm` and `lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file`
- Doppler `SSH_PUBLIC_KEY` updated to `ansible_ed25519` public key (was personal `tlesh@tlesh.com` key — mismatch with `ansible_ssh_private_key_file` in `group_vars/all.yml`)

## Notes

The TUN device entries in `/etc/pve/lxc/104.conf` are managed manually (not via Terraform) — same pattern as the tailscale LXC (101).

**Operational caveat:** if Terraform ever forces a recreation of CT 104 (e.g., from config changes requiring replacement), Proxmox will regenerate `/etc/pve/lxc/104.conf` and drop these manual TUN entries. Tailscale inside CT 104 will stop working until they are re-applied:

1. SSH to `tika`
2. Add to `/etc/pve/lxc/104.conf`:

   ```text
   lxc.cgroup2.devices.allow: c 10:200 rwm
   lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
   ```

3. `pct shutdown 104 && pct start 104`
