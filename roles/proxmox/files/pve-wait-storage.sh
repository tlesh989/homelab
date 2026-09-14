#!/usr/bin/env bash
set -euo pipefail
# Block pve-ha-lrm (and therefore pve-guests, which orders after it) until the
# TrueNAS-backed storages are active. TrueNAS boots slower than the Proxmox
# nodes after a power outage; without this, iSCSI/NFS-backed guests fail to
# start and HA parks them in 'error'. pvesm status also triggers the iSCSI
# login. Best effort: gives up after ~10 minutes so boot never hangs (well
# under the unit's TimeoutStartSec=15min, even accounting for probe time).
SECONDS=0
while [ "$SECONDS" -lt 600 ]; do
  if timeout 15 pvesm status 2>/dev/null | awk '($1=="truenas-lvm"||$1=="proxmox-nfs") && $3=="active"{n++} END{exit n!=2}'; then
    exit 0
  fi
  sleep 10
done
echo "pve-wait-storage: TrueNAS storage still inactive after 10 min, failing gate" >&2
exit 1
