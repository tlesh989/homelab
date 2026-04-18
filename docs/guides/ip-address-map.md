# IP Address Map

Reference for static and reserved IPs across all homelab networks.

## Main Network — 192.168.233.0/24 (Default, VLAN 1)

DHCP pool: `.50–.254` (dynamic)
Static range: `.1–.49` (reserved for infrastructure)

### Infrastructure — Static (.1–.49)

| IP | Hostname | Role | Notes |
|----|----------|------|-------|
| .1 | gateway | UniFi Express 7 | Router/controller |
| .3 | pi-hole | Pi-hole LXC | Primary DNS (Proxmox: tika) |
| .6 | *(secondary DNS)* | DNS server | Reserved via DHCP |
| .7 | tika | Proxmox node | Mini PC, 1GbE (AX88179B) |
| .8 | bupu | Proxmox node | Mini PC, 1GbE (AX88179) |
| .9 | sturm | Proxmox node | Mini PC, 2.5GbE native |
| .10 | kaz | Docker host VM | glance, n8n, watchtower (on tika) |
| .11 | jetkvm | JetKVM | KVM-over-IP |
| .12 | plex | Plex LXC | Media server |
| .21 | tailscale | Tailscale LXC | Subnet router (on tika) |
| .22 | glance | Glance LXC | Dashboard (on tika) |
| .23 | netdata | Netdata LXC | Monitoring (on sturm) |
| .25 | *(unknown)* | — | DHCP reservation (MAC: 4e:64:17:37:7d:87) |
| .28 | magius | Machine | Reserved (MAC: f0:d5:bf:35:0d:e0) |
| .29 | magius | Machine | Reserved 2nd NIC (MAC: d0:37:45:cf:ce:4c) |
| .30 | *(unknown)* | — | DHCP reservation (MAC: c4:35:d9:89:4c:b4) |
| .31 | *(unknown)* | — | DHCP reservation (MAC: 54:bf:64:2e:b2:51) |

### Personal/Media Devices — Dynamic but Notable

| IP | Hostname | Role | Notes |
|----|----------|------|-------|
| .15 | BRW543530681938 | Brother printer | Fixed reservation |
| .125 | homeassistant | Home Assistant | Fixed reservation (Raspberry Pi — installed, not yet configured) |
| .139 | chimney-ap | UniFi AC Mesh | Access point |
| .156 | Denon-AVR-S750H | AV receiver | Stays on main (Plex/DLNA) |
| .169 | Coltons-Tablet | Tablet | Fixed reservation |
| .185 | USW Flex Mini | UniFi switch | Managed switch |
| .188 | USW Pro Max 16 PoE | UniFi switch | Core switch |
| .200 | solinari | UGREEN NAS | Fixed reservation (TrueNAS) |
| .205 | *(unknown)* | — | Fixed reservation (MAC: 00:11:32:78:26:f4) |

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

Migrate these from main network → ginkgo SSID in their respective apps:

| Device | Type | MAC | Status |
|--------|------|-----|--------|
| ESP_433ABC | ESP32 sensor | 5c:cf:7f:43:3a:bc | Needs migration |
| KP303 fb:60 | Kasa power strip | e4:fa:c4:3f:fb:60 | Needs migration |
| KP303 a5:67 | Kasa power strip | 3c:84:6a:66:a5:67 | Needs migration |
| TP15 5e:e6 | Tapo smart plug | 3c:52:a1:3a:5e:e6 | Needs migration |
| TP15 67:a3 | Tapo smart plug | 3c:52:a1:3a:67:a3 | Needs migration |
| TP15 65:65 | Tapo smart plug | 3c:52:a1:3a:65:65 | ✅ On IoT (.166) |
| TP15 65:b2 | Tapo smart plug | 3c:52:a1:3a:65:b2 | ✅ On IoT (.52) |
| Etekcity-Outlet | Smart outlet | 2c:3a:e8:22:e7:a9 | ✅ On IoT (.97) |
| Wyze Video Doorbell | Camera | 2c:aa:8e:a7:bd:bf | Needs migration |
| Wyze Outdoor Plug | Smart plug | 7c:78:b2:61:97:0a | Needs migration |
| WYZE_CAKP2JFUS | Wyze camera | 7c:78:b2:23:b6:72 | Needs migration |
| TwinCam | Wyze camera | 2c:aa:8e:24:1f:9a | Needs migration |
| GE_Light_1B77 | Smart light | 80:8a:f7:01:fd:fc | Needs migration |
| Govee Lyra | Smart light | d0:c9:07:82:94:5a | Needs migration |
| Amazon Echo Dot (4th Gen) | Smart speaker | b0:73:9c:5b:77:de | Needs migration |
| Amazon Echo Dot (2nd Gen) | Smart speaker | fc:a6:67:3d:f7:9c | Needs migration |
| Echo Show | Smart display | 08:91:a3:88:88:73 | Needs migration |

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
