# Homelab Improvements Design

**Date**: 2026-04-30
**Status**: Approved
**Scope**: Infrastructure cleanup (PR 1) + Authentik SSO (PR 2)

---

## Background

Audit of the homelab Ansible/Terraform project identified several gaps:

- Seerr (family media request portal) is not proxied through Caddy — no HTTPS, no subdomain
- Grafana has stale scraparr dashboard files from a removed exporter
- No container-level (cAdvisor) or Proxmox-level (pve-exporter) dashboards in Grafana
- No metric-based alerting (disk pressure, host silence) with Pushover notifications
- No SSO — Grafana, n8n, and FreshRSS each have separate login credentials

**Out of scope**: Kubernetes cluster (tracked in homelab-sz7), Immich photo backup, Authelia forward-auth for non-OIDC services.

---

## PR 1 — Infrastructure Cleanup

### Seerr → Caddy + Pi-hole

Add Seerr to the standard three-point service integration pattern.

- `roles/caddy/vars/main.yml` — add entry to `caddy_services`:
  - subdomain: `seerr.tlesh.xyz`
  - upstream: `192.168.233.24:5055`
- `roles/pihole` — add local DNS A record: `seerr.tlesh.xyz` → `192.168.233.17` (Caddy)
- `roles/glance` — add Seerr widget to the Infrastructure page with `si:jellyseerr` icon

### Grafana Cleanup

Remove the stale scraparr dashboard JSON from the Grafana provisioning directory. The scraparr exporter was removed; the dashboard file was not. On next playbook run the file should be absent from `/opt/grafana/provisioning/dashboards/`.

Implementation: add `ansible.builtin.file` task with `state: absent` for the old dashboard path.

### Grafana — cAdvisor (Docker container metrics)

Deploy **cAdvisor** as a Docker container on kaz alongside the existing monitoring stack.

- Image: `gcr.io/cadvisor/cadvisor:v0.51` (pinned major version, Watchtower handles minor/patch)
- Port: `8083` (internal only, not proxied through Caddy)
- Prometheus scrape job: `cadvisor` targeting `kaz:8083`
- Provision `cadvisor-dashboard.json` (community dashboard ID 14282) to Grafana provisioning dir

Metrics exposed: per-container CPU, memory, network I/O, filesystem usage for all Docker containers on kaz.

### Grafana — Proxmox PVE Exporter (hypervisor metrics)

Deploy **pve-exporter** as a Docker container on kaz.

- Image: `prompve/prometheus-pve-exporter:3` (pinned major)
- Port: `9221` (internal only)
- Config: `/opt/pve-exporter/pve.yml` — Proxmox API token sourced from Doppler (`PVE_TOKEN_ID`, `PVE_TOKEN_SECRET`); create a dedicated `pve-exporter@pve` user with read-only `PVEAuditor` role in Proxmox
- Prometheus scrape job: `pve` targeting `kaz:9221` with `module=default`
- Provision `proxmox-dashboard.json` (community dashboard ID 10347) to Grafana

Metrics exposed: per-node CPU, memory, VM/LXC status, storage pool usage across tika, bupu, sturm.

### Grafana — Alerting with Pushover

Provision alerting configuration via Ansible (Grafana provisioning YAML — survives redeployment).

**Contact point** (`provisioning/alerting/contact-points.yaml`):
- Name: `Pushover`
- Type: `pushover`
- Credentials from Doppler: `PUSHOVER_APP_TOKEN`, `PUSHOVER_USER_KEY`

**Alert rules** (`provisioning/alerting/rules.yaml`):

| Alert | Condition | For | Severity |
|-------|-----------|-----|----------|
| HostDiskFull | `node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.15` | 5m | warning |
| HostDown | `up == 0` (node job) | 5m | critical |
| HighMemoryPressure | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10` | 10m | warning |

All rules use the Pushover contact point. No Alertmanager required — Grafana Alerting handles routing directly.

---

## PR 2 — Authentik SSO

### Architecture

Authentik runs on **kaz** (existing Docker host) as a multi-container stack: server, worker, PostgreSQL, Redis. This follows the established kaz pattern and avoids provisioning a new LXC.

```
Client → Caddy (authentik.tlesh.xyz) → kaz:9000 (Authentik server)
                                             ↓
                                    kaz:5432 (PostgreSQL)
                                    kaz:6379 (Redis)
```

OIDC flows:
```
User → Grafana/n8n/FreshRSS → redirect to Authentik → authenticate → return token → app session
```

### New Role: `roles/authentik`

**defaults/main.yml**:
- `authentik_version: 2` (major pin, Watchtower updates minor/patch)
- `authentik_port: 9000`
- `authentik_data_path: /opt/authentik`
- `authentik_postgres_path: /opt/authentik/postgres`
- `authentik_hostname: authentik.tlesh.xyz`

**tasks/main.yml**:
1. Create data directories (owner 1000:1000)
2. Install Docker Python SDK
3. Deploy PostgreSQL container (`postgres:16-alpine`)
4. Deploy Redis container (`redis:7-alpine`)
5. Deploy Authentik server container
6. Deploy Authentik worker container

**Secrets (Doppler)**:
- `AUTHENTIK_SECRET_KEY` — generated once, stored in Doppler
- `AUTHENTIK_POSTGRES_PASSWORD`
- `PUSHOVER_APP_TOKEN`, `PUSHOVER_USER_KEY` (reused from alerting)

### Caddy + Pi-hole Integration

- `roles/caddy`: add `authentik.tlesh.xyz` → `192.168.233.10:9000`
- `roles/pihole`: add `authentik.tlesh.xyz` → `192.168.233.17`

### OIDC App Integrations

Initial OIDC app configuration (creating the application + provider in Authentik) is a **one-time manual step** via the Authentik web UI after first deploy. Client IDs and secrets are then stored in Doppler and consumed by each service role.

**Grafana** (`roles/monitoring/templates/grafana.env.j2`):
```
GF_AUTH_GENERIC_OAUTH_ENABLED=true
GF_AUTH_GENERIC_OAUTH_NAME=Authentik
GF_AUTH_GENERIC_OAUTH_CLIENT_ID={{ GRAFANA_OIDC_CLIENT_ID }}
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET={{ GRAFANA_OIDC_CLIENT_SECRET }}
GF_AUTH_GENERIC_OAUTH_SCOPES=openid email profile
GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://authentik.tlesh.xyz/application/o/authorize/
GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://authentik.tlesh.xyz/application/o/token/
GF_AUTH_GENERIC_OAUTH_API_URL=https://authentik.tlesh.xyz/application/o/userinfo/
GF_AUTH_SIGNOUT_REDIRECT_URL=https://authentik.tlesh.xyz/application/o/grafana/end-session/
GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=contains(groups, 'admin') && 'Admin' || 'Viewer'
```

**n8n** (`roles/n8n/templates/env.j2`): n8n supports OIDC via `N8N_AUTH_OIDC_*` env vars. Config pattern same as Grafana — client ID/secret from Doppler.

**FreshRSS**: FreshRSS supports OIDC via the `OidcPlugin`. Enable plugin + configure provider URL and client credentials via environment variables or config file — provisioned by the freshrss role.

### Playbook Assignment

`roles/authentik` added to kaz host in `playbook.yml`, positioned after `monitoring` and before `caddy` (caddy role reads authentik hostname for upstream config).

---

## Deployment Order

1. Run PR 1 — validate Seerr accessible at `seerr.tlesh.xyz`, Grafana shows new dashboards and alerts
2. Verify Doppler has `AUTHENTIK_SECRET_KEY` and `AUTHENTIK_POSTGRES_PASSWORD` set
3. Run PR 2 playbook — Authentik boots at `authentik.tlesh.xyz`
4. One-time: create OIDC apps in Authentik UI for Grafana, n8n, FreshRSS
5. Store client IDs/secrets in Doppler, re-run playbook to inject into service roles

---

## Definition of Done

- `task syntax && task lint` pass on both PRs
- `coderabbit review --plain --base main` clean before each PR
- Seerr accessible at `https://seerr.tlesh.xyz`
- cAdvisor metrics visible in Grafana
- Proxmox node metrics visible in Grafana
- Pushover test alert fires successfully
- Grafana login redirects to Authentik
- n8n login redirects to Authentik
- FreshRSS login redirects to Authentik
