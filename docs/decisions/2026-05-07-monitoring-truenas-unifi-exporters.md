# Monitoring: TrueNAS and UniFi Exporters

**Date**: 2026-05-07
**Issues**: homelab-7wq (TrueNAS), homelab-5v8 (UniFi)

## Context

The Prometheus/Grafana monitoring stack already collects Proxmox node metrics
(pve-exporter), container metrics (cAdvisor), and host metrics (node_exporter).
Two gaps remain: TrueNAS SCALE pool/dataset health and UniFi network device metrics.

## Decision

Add two new exporter containers to the `monitoring` role, both running on `kaz`.

### TrueNAS exporter (`ghcr.io/unknowlars/truenas-scale-api-prometheus-exporter`)

- Source: https://github.com/Unknowlars/truenas-scale-api-prometheus-exporter
- Connects to TrueNAS SCALE JSON-RPC WebSocket API (`wss://`) using a read-only API key
- Doppler secret: `TRUENAS_PROM_KEY` (maps to container env `TRUENAS_API_KEY`; named distinctly to avoid collision with any admin key)
- Exposes pool health, dataset usage, hardware, and system metrics on port 9108
- Grafana dashboard bundled in repo — downloaded from GitHub raw at provision time
- **Note**: upstream publishes no version tags; `latest` is the only available tag. Pin to a commit SHA via `truenas_exporter_version` if reproducibility is required.

### UniFi Poller (`ghcr.io/unpoller/unpoller`)

- Polls the UniFi controller (UE7 at `https://192.168.233.1`) using a dedicated read-only local user
- Credentials stored in Doppler as `UNIFI_RO_USERNAME` / `UNIFI_RO_PASSWORD`
- Exposes client, site, and switch metrics on port 9130
- InfluxDB output disabled; Prometheus output enabled
- Grafana dashboards downloaded at provision time from grafana.com (IDs 11310, 11315)

## Prerequisites

1. Create a read-only local UniFi user in the controller UI (not a Ubiquiti cloud account)
2. Add `UNIFI_RO_USERNAME` and `UNIFI_RO_PASSWORD` to Doppler
3. Generate a read-only TrueNAS API key under `Settings > API Keys` and add as `TRUENAS_PROM_KEY` to Doppler
4. Ensure kaz can reach `192.168.233.1` (UniFi controller) and `192.168.233.6` (TrueNAS)

## Alternatives Considered

- **SNMP exporter** for UniFi: rejected — requires per-device SNMP config; unpoller is purpose-built for UniFi
- **truenas node_exporter** on TrueNAS host: already in place but lacks pool/dataset metrics
