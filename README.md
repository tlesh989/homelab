# homelab

Personal homelab infrastructure managed as code — three Proxmox nodes running LXC containers and VMs, with shared iSCSI storage from TrueNAS.

## Hardware

| Device | Role | Specs |
|--------|------|-------|
| 3x Mini PCs (Intel N100) | Proxmox nodes: `tika`, `bupu`, `sturm` | 16GB RAM, 512GB NVMe OS + 512GB data |
| UGREEN NAS | TrueNAS SCALE (`wayreth`) | 4-bay, iSCSI + NFS storage |
| UniFi Express 7 | Router + switch | Built-in controller |

## Services

| Service | Host | Description |
|---------|------|-------------|
| Plex | `sturm` (LXC) | Media server with VAAPI hardware transcoding |
| Pi-hole | `sturm` (LXC) | Network-wide DNS ad blocking, Proxmox HA managed |
| Tailscale | `tika` (LXC) | Subnet router for remote access |
| Glance | `sturm` (LXC) | Homelab dashboard |
| Netdata | `sturm` (LXC) | Metrics: parent node + child agents on all Proxmox hosts |

## Tech Stack

- **Provisioning**: [Terraform](https://www.terraform.io/) with [`bpg/proxmox`](https://github.com/bpg/terraform-provider-proxmox) provider; state in Terraform Cloud
- **Configuration**: [Ansible](https://docs.ansible.com/) with custom roles
- **Secrets**: [Doppler](https://www.doppler.com/) — all secrets injected at runtime, nothing stored locally
- **Automation**: [Task](https://taskfile.dev/) for orchestrating all operations
- **Networking**: Tailscale for remote access; VLAN 233 (`192.168.233.0/24`) for homelab traffic
- **Storage**: TrueNAS iSCSI backend → Proxmox LVM-thin (`truenas-lvm`); NFS for media

## Quick Start

```bash
# Install dependencies
task reqs

# Validate everything
task syntax    # Check Ansible playbook syntax
task lint      # Run ansible-lint
task ping      # Test connectivity to all hosts

# Deploy (dry-run gate built in via /deploy skill)
task proxmox   # Proxmox hypervisor configuration
task truenas   # TrueNAS storage configuration
task plex      # Plex media server
task glance    # Glance dashboard
task netdata   # Netdata monitoring (parent + agents)

# Terraform (from terraform/)
cd terraform && task      # fmt + validate + plan
cd terraform && task apply
```

## Repository Layout

```
.
├── main.yml              # Master Ansible playbook
├── hosts                 # Inventory
├── Taskfile.yml          # All automation commands
├── group_vars/           # Per-group Ansible variables
├── roles/                # Custom Ansible roles
│   ├── proxmox/          # Hypervisor config, storage, networking
│   ├── truenas/          # iSCSI targets, NFS shares
│   ├── plex/             # Plex install + VAAPI passthrough
│   ├── netdata/          # Monitoring agent/parent setup
│   └── ...
├── terraform/            # LXC/VM definitions (one file per service)
├── tailscale/            # Tailscale ACL policy
└── docs/                 # Architecture plans and design docs
```

## Secrets

All secrets are managed by [Doppler](https://www.doppler.com/) and injected via `doppler run`. The `task` commands handle this automatically — no `.env` files, no local vaults.
