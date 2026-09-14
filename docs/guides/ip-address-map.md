# IP Address Map

Reference for static and reserved IPs across all homelab networks.

## Main Network — 192.168.233.0/24 (Default, VLAN 1)

DHCP pool: `.51–.220` (dynamic)
Static range: `.1–.50` (reserved for infrastructure)
Personal device pool: `.240–.250` (reservation-only, outside DHCP pool)

### Infrastructure — Static (.1–.50)

| IP | Hostname | Role | Notes |
|----|----------|------|-------|
| .1 | gateway | UniFi Express 7 | Router/controller |
| .3 | pi-hole | Pi-hole LXC | Primary DNS (Proxmox: tika) |
| .6 | ansalon | — | DHCP reservation (MAC: 6c:1f:f7:76:99:8f) |
| .7 | tika | Proxmox node | Mini PC, 1GbE (AX88179B) |
| .8 | bupu | Proxmox node | Mini PC, 1GbE (AX88179) |
| .9 | sturm | Proxmox node | Mini PC, 2.5GbE native |
| .10 | kaz | Docker host VM | DHCP reservation (MAC: bc:24:11:10:00:01) — glance, n8n, watchtower (on tika) |
| .11 | jetkvm | JetKVM | DHCP reservation (MAC: 44:b7:d0:e7:82:89) — KVM-over-IP |
| .12 | plex | Plex LXC | Media server (on sturm) |
| .15 | printer | Brother printer | DHCP reservation (MAC: 54:35:30:68:19:38) |
| .18 | tdarr-node | Tdarr transcode node LXC | Terraform-managed (on sturm, vm_id 118) — GPU/VAAPI transcode |
| .19 | minecraft | Minecraft server VM | DHCP reservation (MAC: bc:24:11:13:00:01) |
| .21 | tailscale | Tailscale LXC | DHCP reservation (MAC: ea:31:e7:19:05:63) — Subnet router (on tika) |
| .22 | claude-code | Claude Code LXC | Terraform-managed (on tika, vm_id 125); reclaimed from decommissioned glance LXC |
| .27 | drizzt | Machine | DHCP reservation (MAC: 6c:6e:07:1e:39:74) |
| .29 | magius | Machine | DHCP reservation (MAC: d0:37:45:cf:ce:4c) |
| .30 | kaladin | Machine | DHCP reservation (MAC: c4:35:d9:89:4c:b4) |
| .31 | kvothe | Machine | DHCP reservation (MAC: 54:bf:64:2e:b2:51) |
| .35 | homeassistant | Home Assistant | DHCP reservation (Raspberry Pi — MAC: b8:27:eb:75:3a:e3) |
| .200 | solinari | UGREEN NAS | DHCP reservation (MAC: 00:11:32:8e:27:e1) — legacy: stays in dynamic range; moving would break macOS Time Machine config and Proxmox iSCSI storage references |

### Personal/Media Devices — Dynamic but Notable

| IP | Hostname | Role | Notes |
|----|----------|------|-------|
| .139 | chimney-ap | UniFi AC Mesh | Access point |
| .156 | Denon-AVR-S750H | AV receiver | Stays on main (Plex/DLNA) |
| .185 | USW Flex Mini | UniFi switch | Managed switch |
| .188 | USW Pro Max 16 PoE | UniFi switch | Core switch |

### Personal Device Pool — Reservation-Only (.240–.250)

These IPs are outside the DHCP pool (.51–.220) and only reachable via explicit DHCP reservation. Used for personal/family devices to enable range-based firewall filtering.

| IP | Hostname | Role | Notes |
|----|----------|------|-------|
| .240 | coltons-tablet | Tablet | DHCP reservation (MAC: da:4d:62:21:d6:88) |

### Media Devices (staying on main — Plex/DLNA access)

GymRoku `.79`

---

## IoT Network — 192.168.40.0/24 (IoT, VLAN 40)

DHCP pool: `.10–.200` (dynamic, cattle model — no reservations)
DNS: `192.168.233.3` (pi-hole), `192.168.40.1` (fallback)

| IP | Hostname | Notes |
|----|----------|-------|
| .1 | gateway | IoT VLAN gateway |
| .10–.200 | *(dynamic)* | All IoT devices — assigned by DHCP |

### IoT Devices (connect to `ginkgo` SSID)

Live-checked against the UniFi controller (`/proxy/network/integration/v1/sites/.../clients`) on 2026-08-15.
Migration from `ginseng` → `ginkgo` happens **only in each device's own app** — WiFi credentials
are paired into the device at setup time, and UniFi can't reassign a client to a different SSID
from the network side. Re-pairing steps: open the vendor app → device settings → change WiFi
network → select `ginkgo` → re-enter password. Some Wyze/Tapo devices require "forget device" +
full re-add instead of an in-place network change.

| Device | Type | MAC | Status |
|--------|------|-----|--------|
| ESP_433ABC | ESP32 sensor | 5c:cf:7f:43:3a:bc | ❌ On main (.155) — needs migration |
| KP303 fb:60 | Kasa power strip | e4:fa:c4:3f:fb:60 | ✅ On IoT (.161) |
| KP303 a5:67 | Kasa power strip | 3c:84:6a:66:a5:67 | ❌ On main (.128) — needs migration |
| TP15 5e:e6 | Tapo smart plug | 3c:52:a1:3a:5e:e6 | ✅ On IoT (.76) |
| TP15 67:a3 | Tapo smart plug | 3c:52:a1:3a:67:a3 | ✅ On IoT (.18) |
| TP15 65:65 | Tapo smart plug | 3c:52:a1:3a:65:65 | ✅ On IoT (.166) |
| TP15 65:b2 | Tapo smart plug | 3c:52:a1:3a:65:b2 | ⚠️ Offline — last known on IoT (.52), unverified |
| Etekcity-Outlet | Smart outlet | 2c:3a:e8:22:e7:a9 | ✅ On IoT (.97) |
| Wyze Video Doorbell | Camera | 2c:aa:8e:a7:bd:bf | ⚠️ Offline — network unverified |
| Wyze Outdoor Plug | Smart plug | 7c:78:b2:61:97:0a | ⚠️ Offline — network unverified |
| WYZE_CAKP2JFUS | Wyze camera | 7c:78:b2:23:b6:72 | ✅ On IoT (.109) |
| TwinCam | Wyze camera | 2c:aa:8e:24:1f:9a | ✅ On IoT (.110) |
| GE_Light_1B77 | Smart light | 80:8a:f7:01:fd:fc | ❌ On main (.67) — needs migration |
| Govee Lyra | Smart light | d0:c9:07:82:94:5a | ✅ On IoT (.88) |
| Amazon Echo Dot (4th Gen) 77:de | Smart speaker | b0:73:9c:5b:77:de | ❌ On main (.58) — needs migration |
| Amazon Echo Dot (2nd Gen) f7:9c | Smart speaker | fc:a6:67:3d:f7:9c | ❌ On main (.193) — needs migration |
| Echo Show | Smart display | 08:91:a3:88:88:73 | ❌ On main (.68) — needs migration |
| Wyze Plug 85:43 | Smart plug | 2c:aa:8e:e9:85:43 | ❌ On main (.183) — needs migration *(newly found)* |
| WYZE_CAKP2JFUS 42:69 | Wyze camera | 2c:aa:8e:fb:42:69 | ❌ On main (.187) — needs migration *(newly found)* |
| Amazon Echo Dot (3rd Gen) ca:5b | Smart speaker | 08:a6:bc:75:ca:5b | ❌ On main (.177) — needs migration *(newly found)* |
| Amazon Echo Dot (4th Gen) e9:b2 | Smart speaker | 34:25:be:75:e9:b2 | ❌ On main (.84) — needs migration *(newly found)* |

Intentionally staying on main (streaming devices need Plex/DLNA reachability, not IoT-isolated):
RokuUltra (.189), RokuTCL (.53) — same rationale as GymRoku above.

---

## Storage Network — 192.168.220.0/24 (Storage, VLAN 220)

No DHCP. Static assignments only (managed outside UniFi).
Used for iSCSI between TrueNAS and Proxmox nodes.
Internet access: disabled. mDNS: enabled.

---

## Firewall Zone Summary

| Zone | Networks | Policy |
|------|----------|--------|
| Internal | Default (.233), Storage (.220) | Full access between zones |
| IoT | IoT (.40) | Internet allowed; blocked from Internal; Internal can initiate to IoT |
| External | WAN | Default deny inbound |
| Gateway | — | Management access to Internal |
| VPN | VPN tunnel | Access to Internal |
