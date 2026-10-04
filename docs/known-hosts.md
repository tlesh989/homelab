# Known LAN Devices

Baseline for `/homelab-health` rogue-device detection. Rogue detection compares UniFi clients against
the Doppler secret `KNOWN_DEVICES`; this file is only the infrastructure inventory.

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

## Other devices and MACs

Not stored in git (names and MACs identify the household). The baseline lives in the Doppler secret
`KNOWN_DEVICES` (`mac|name|ip` per line, snapshot from UniFi). Update it with:
`doppler secrets set KNOWN_DEVICES="$(cat file)"`.
