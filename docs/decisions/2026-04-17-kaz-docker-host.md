# kaz: Consolidated Docker Host

**Date**: 2026-04-17
**Status**: Implemented

## Context

The homelab was accumulating one LXC per service, creating management overhead: separate OS patches, Watchtower instances, and Terraform resources per container. Meanwhile, the planned `kaz` Docker host VM was never deployed, and `drizzt` (Dell XPS 15 9520 running Ollama) is being decommissioned in favor of running Ollama locally on a MacBook Air M4.

## Decisions

### kaz as a VM (not LXC)
A full VM on the `proxmox-nfs` NFS datastore enables live migration across all three Proxmox nodes (tika, bupu, sturm) without shared-block-storage complexity. LXC would work but VMs give better Docker compatibility and kernel isolation.

### Consolidate non-critical services onto kaz
- **glance** (dashboard) — migrated from binary+systemd+Tailscale to Docker; Caddy now proxies it instead of Tailscale serve
- **n8n** (workflow automation) — new service, deployed directly on kaz
- **uptime-kuma**, **arr**, **pi-hole**, **netdata**, **caddy** — remain on dedicated LXCs (mission-critical or tightly coupled to other infrastructure)

### One Watchtower per Docker host
kaz deploys a single Watchtower instance via the `watchtower` role, covering all containers on the host. The `ollama` role's per-service Watchtower pattern is not replicated here.

### Decommission drizzt/ollama
The Ollama role, drizzt inventory entry, Caddy upstream, and Taskfile target are removed. Ollama runs locally on the MacBook Air M4 with better GPU performance.

## Glance LXC Decommission (follow-up)
`terraform/disabled/glance.tf.disabled` preserves the glance LXC config. After verifying glance on kaz is healthy, destroy the LXC with:
```
task terraform -- plan  # verify only glance LXC destroy is planned
task terraform -- apply
```
Then delete the disabled file.
