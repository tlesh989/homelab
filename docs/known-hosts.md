# Known LAN Devices

Baseline for `/homelab-health` rogue-device detection. Any UniFi client not listed here is
reported as unknown. Match on MAC where given, otherwise hostname/IP.

## Infrastructure (from `hosts` inventory, 192.168.233.0/24)

| Name | IP | MAC | Notes |
|------|----|-----|-------|
| tika | .7 | | Proxmox node |
| bupu | .8 | | Proxmox node |
| sturm | .9 | | Proxmox node |
| ansalon (TrueNAS) | .6 | | NAS |
| pi-hole | .3 | | DNS |
| kaz | .10 | | Docker host |
| plex | .12 | | |
| uptime-kuma | .16 | | |
| caddy | .17 | | |
| tdarr-node | .18 | | |
| minecraft | .19 | | |
| minecraft2 | .20 | | |
| tailscale | .21 | | |
| claude-code | .22 | | |
| arr | .24 | | |

## Other devices (phones, TVs, IoT, APs, switches)

<!-- Populate from the first /homelab-health run: it lists every unmatched client. -->

| Name | IP/MAC | Owner | Notes |
|------|--------|-------|-------|
