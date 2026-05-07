# homelab

Personal homelab infrastructure managed as code — three Proxmox nodes running LXC containers and VMs, with shared iSCSI storage from TrueNAS.

## Hardware

| Device | Role | Specs |
|--------|------|-------|
| 3x Mini PCs (Intel N100) | Proxmox nodes: `tika`, `bupu`, `sturm` | 16GB RAM, 512GB NVMe OS + 512GB data |
| UGREEN NAS | TrueNAS SCALE (`wayreth`) | 4-bay, iSCSI + NFS storage |
| UniFi Express 7 | Router + gateway | Built-in controller |
| USW Pro Max 16 PoE | Managed switch | PoE for APs and devices |

## Services

| Service | Host | Description |
|---------|------|-------------|
| Plex | `sturm` (LXC) | Media server with VAAPI hardware transcoding |
| Pi-hole | `sturm` (LXC) | Network-wide DNS ad blocking, Proxmox HA managed |
| Uptime Kuma | `sturm` (LXC) | Service uptime monitoring and alerting |
| Tailscale | `tika` (LXC) | Subnet router for remote access |
| Caddy | `tika` (LXC) | Reverse proxy with Cloudflare DNS-01 wildcard TLS |
| Glance | `kaz` (Docker) | Homelab dashboard |
| n8n | `kaz` (Docker) | Workflow automation |
| Prometheus | `kaz` (Docker) | Metrics collection and storage (30-day retention) |
| Grafana | `kaz` (Docker) | Metrics dashboards and Pushover alerting |
| cAdvisor | `kaz` (Docker) | Docker container metrics |
| pve-exporter | `kaz` (Docker) | Proxmox node metrics |
| Dozzle | `kaz` (Docker) | Centralized Docker log aggregation (v10 agent mode) |
| Watchtower | `kaz` (Docker) | Automated Docker image updates |
| Arr stack | `bupu` (LXC) | Sonarr, Radarr, Lidarr, Beets, FileBot, Scraparr |
| Minecraft | `bupu` (LXC) | Bedrock Dedicated Server with auto-update |
| FreshRSS | `bupu` (LXC) | Self-hosted RSS aggregator |

## Tech Stack

- **Provisioning**: [Terraform](https://www.terraform.io/) with [`bpg/proxmox`](https://github.com/bpg/terraform-provider-proxmox) provider; state in Terraform Cloud
- **Configuration**: [Ansible](https://docs.ansible.com/) with custom roles
- **Secrets**: [Doppler](https://www.doppler.com/) — all secrets injected at runtime, nothing stored locally
- **Automation**: [Task](https://taskfile.dev/) for orchestrating all operations
- **Networking**: Tailscale for remote access; VLAN 233 (`192.168.233.0/24`) for homelab traffic
- **Storage**: TrueNAS iSCSI backend → Proxmox LVM-thin (`truenas-lvm`); NFS for media
- **Monitoring**: Prometheus + Grafana + cAdvisor + pve-exporter; Pushover alerts; Dozzle for logs
- **CI/CD**: GitHub Actions (Ansible syntax + Terraform validate); CodeRabbit automated PR review; Renovate for dependency updates

## Quick Start

```bash
# Install dependencies
task reqs

# Validate everything
task syntax    # Check Ansible playbook syntax
task lint      # Run ansible-lint
task ping      # Test connectivity to all hosts

# Deploy (dry-run gate built in via /deploy skill)
task proxmox    # Proxmox hypervisor configuration
task truenas    # TrueNAS storage configuration
task plex       # Plex media server
task glance     # Glance dashboard
task monitoring # Prometheus, Grafana, cAdvisor, pve-exporter, Dozzle
task arr        # Arr media stack
task caddy      # Caddy reverse proxy
task minecraft  # Minecraft Bedrock server

# Terraform (from terraform/)
cd terraform && task      # fmt + validate + plan
cd terraform && task apply
```

## Repository Layout

```text
.
├── main.yml              # Master Ansible playbook
├── hosts                 # Inventory
├── Taskfile.yml          # All automation commands
├── group_vars/           # Per-group Ansible variables
├── roles/                # Custom Ansible roles
│   ├── proxmox/          # Hypervisor config, storage, networking
│   ├── truenas/          # iSCSI targets, NFS shares (websocket API)
│   ├── plex/             # Plex install + VAAPI passthrough
│   ├── monitoring/       # Prometheus, Grafana, cAdvisor, pve-exporter, Dozzle
│   ├── dozzle_agent/     # Dozzle log agent (deployed to remote Docker hosts)
│   ├── n8n/              # n8n workflow automation
│   ├── glance/           # Glance homelab dashboard
│   ├── caddy/            # Caddy reverse proxy + Cloudflare TLS
│   ├── arr/              # Arr media stack + FileBot + Beets
│   ├── minecraft/        # Minecraft Bedrock server + auto-update
│   ├── freshrss/         # FreshRSS RSS aggregator
│   ├── uptime_kuma/      # Uptime Kuma service monitoring
│   ├── node_exporter/    # Prometheus node exporter agent
│   ├── unifi/            # UniFi DHCP reservation management
│   └── ...
├── terraform/            # LXC/VM definitions (one file per service)
├── tailscale/            # Tailscale ACL policy
└── docs/                 # Architecture plans and design docs
```

## Secrets

All secrets are managed by [Doppler](https://www.doppler.com/) and injected via `doppler run`. The `task` commands handle this automatically — no `.env` files, no local vaults.
