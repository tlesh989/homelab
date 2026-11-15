# IP Address Map

Reference for static and reserved IPs across all homelab networks. Proxmox node placement
noted below can change via migration — confirm live with `pvesh get /cluster/resources --type vm`.

## Main Network — 192.168.233.0/24 (Default, VLAN 1)

DHCP pool: `.51–.220` (dynamic)
Static range: `.1–.50` (reserved for infrastructure)
Personal device pool: `.240–.250` (reservation-only, outside DHCP pool)

### Infrastructure — Static (.1–.50)

| IP | Hostname | Role | Notes |
|----|----------|------|-------|
| .1 | gateway | UniFi Express 7 | Router/controller |
| .3 | pi-hole | Pi-hole LXC | Primary DNS (Proxmox: tika) |
| .6 | ansalon | TrueNAS SCALE (UGREEN DXP4800 Plus) | DHCP reservation (MAC: 6c:1f:f7:76:99:8f) |
| .7 | tika | Proxmox node | Mini PC, 1GbE (AX88179B) |
| .8 | bupu | Proxmox node | Mini PC, 1GbE (AX88179) |
| .9 | sturm | Proxmox node | Mini PC, 2.5GbE native |
| .10 | kaz | Docker host VM | DHCP reservation (MAC: bc:24:11:10:00:01) — glance, n8n, watchtower, Beszel hub, etc. (on sturm, vm_id 110; migrates) |
| .11 | jetkvm | JetKVM | DHCP reservation (MAC: 44:b7:d0:e7:82:89) — KVM-over-IP |
| .12 | plex | Plex LXC | Media server (on sturm) |
| .14 | flashforge-ad5x | Flashforge AD5X 3D printer | DHCP reservation (MAC: 24:a1:0d:b1:ce:d0) — UniFi fingerprints it as a Panasonic heat pump |
| .15 | printer | Brother printer | DHCP reservation (MAC: 54:35:30:68:19:38) |
| .16 | uptime-kuma | Uptime Kuma LXC | Terraform-managed (on bupu, vm_id 116) |
| .17 | caddy | Caddy reverse proxy LXC | Terraform-managed (on bupu, vm_id 117) |
| .18 | tdarr-node | Tdarr transcode node LXC | Terraform-managed (on sturm, vm_id 118) — GPU/VAAPI transcode |
| .19 | minecraft | Minecraft server LXC | Terraform-managed (on sturm, vm_id 119); MAC bc:24:11:13:00:01 |
| .20 | minecraft2 | Minecraft server LXC | Terraform-managed (on sturm, vm_id 126); MAC bc:24:11:13:00:02 |
| .21 | tailscale | Tailscale LXC | DHCP reservation (MAC: ea:31:e7:19:05:63) — Subnet router (on tika) |
| .22 | claude-code | Claude Code LXC | Terraform-managed (on tika, vm_id 125); reclaimed from decommissioned glance LXC |
| .24 | arr | arr stack LXC | Terraform-managed (on bupu, vm_id 106); also .220.24 on Storage |
| .32 | USW Pro Max 16 PoE | UniFi core switch | Static IP set on device |
| .33 | sw-24 | UniFi switch (US 24) | Static IP set on device |
| .34 | Xbox Switch | UniFi switch (Flex Mini) | Static IP set on device |
| .35 | homeassistant | Home Assistant | DHCP reservation (Raspberry Pi — MAC: b8:27:eb:75:3a:e3) |
| .36 | USW Flex Mini | UniFi switch | Static IP set on device |
| .37 | U7 Pro XG | UniFi AP | Static IP set on device |
| .38 | chimney-ap | UniFi AC Mesh AP | Static IP set on device |
| .200 | solinari | Synology DS218play NAS | DHCP reservation (MAC: 00:11:32:8e:27:e1) — legacy: stays in dynamic range; moving would break macOS Time Machine config and Proxmox iSCSI storage references |

### Personal/Media Devices — Dynamic but Notable

| IP | Hostname | Role | Notes |
|----|----------|------|-------|
| .156 | Denon-AVR-S750H | AV receiver | Stays on main (Plex/DLNA) |

### Personal Device Pool — Reservation-Only (.240–.250)

These IPs are outside the DHCP pool (.51–.220) and only reachable via explicit DHCP reservation. Used for personal/family devices to enable range-based firewall filtering.

| IP | Hostname | Role | Notes |
|----|----------|------|-------|
| .240 | coltons-tablet | Tablet | DHCP reservation (MAC: da:4d:62:21:d6:88) |
| .241 | drizzt | Machine | DHCP reservation (MAC: 6c:6e:07:1e:39:74) |
| .242 | magius | Machine | DHCP reservation (MAC: d0:37:45:cf:ce:4c) |
| .243 | kaladin | Machine | DHCP reservation (MAC: c4:35:d9:89:4c:b4) |
| .244 | kvothe | Machine | DHCP reservation (MAC: 54:bf:64:2e:b2:51) |

### Media Devices

No streaming device is kept on main for Plex any more. The Roku Ultra and the Hisense TV are wired to
the IoT VLAN (see below) and reach Plex through the "IoT to Plex" firewall policy. GymRoku, RokuTCL
and the Denon AVR join `ginseng` and sit on Guest, which has no Plex policy.

---

## IoT Network — 192.168.40.0/24 (IoT, VLAN 40)

DHCP pool: `.10–.200` (dynamic, cattle model — no reservations)
DNS: gateway only (`192.168.40.1`, DHCP "Auto") — NextDNS CLI on the gateway applies per-device profiles; local names forwarded to Pi-hole

| IP | Hostname | Notes |
|----|----------|-------|
| .1 | gateway | IoT VLAN gateway |
| .10–.200 | *(dynamic)* | All IoT devices — assigned by DHCP |

### IoT Devices (`ginkgo` SSID, or a switch port set to VLAN 40)

`ginseng` now serves the Guest network (VLAN 60), so any IoT device still on `ginseng` lands there and must move to `ginkgo`.

Live-checked against the UniFi controller (`unifly clients list --all`) on 2026-11-15. Names are
UniFi's labels or DHCP hostnames and can be wrong or stale; the MAC is the identity.
Migration from `ginseng` → `ginkgo` happens **only in each device's own app** — WiFi credentials
are paired into the device at setup time, and UniFi can't reassign a client to a different SSID
from the network side. Re-pairing steps: open the vendor app → device settings → change WiFi
network → select `ginkgo` → re-enter password. Some Wyze/Tapo devices require "forget device" +
full re-add instead of an in-place network change.

| Device | Type | MAC | Status |
|--------|------|-----|--------|
| ESP_433ABC | ESP32 sensor | 5c:cf:7f:43:3a:bc | ❌ On Guest via `ginseng` (.137) — move to `ginkgo` |
| KP303 fb:60 | Kasa power strip | e4:fa:c4:3f:fb:60 | ✅ On IoT (.161) |
| KP303 a5:67 | Kasa power strip | 3c:84:6a:66:a5:67 | ❌ On Guest via `ginseng` (.96) — move to `ginkgo` |
| TP15 5e:e6 | Tapo smart plug | 3c:52:a1:3a:5e:e6 | ✅ On IoT (.76) |
| TP15 67:a3 | Tapo smart plug | 3c:52:a1:3a:67:a3 | ✅ On IoT (.18) |
| TP15 65:65 | Tapo smart plug | 3c:52:a1:3a:65:65 | ✅ On IoT (.166) |
| TP15 65:b2 | Tapo smart plug | 3c:52:a1:3a:65:b2 | ⚠️ Offline on 2026-11-15 — network unverified |
| Etekcity-Outlet | Smart outlet | 2c:3a:e8:22:e7:a9 | ✅ On IoT (.97) |
| Wyze wired device | Unidentified (UniFi labels it "Wyze Video Doorbell"; there is no doorbell) | 2c:aa:8e:a7:bd:bf | ✅ On IoT (.184) — wired, sw-24 port 22 |
| Wyze Outdoor Plug | Smart plug | 7c:78:b2:61:97:0a | ⚠️ Offline on 2026-11-15 — network unverified |
| WYZE_CAKP2JFUS | Wyze camera | 7c:78:b2:23:b6:72 | ✅ On IoT (.109) |
| TwinCam | Wyze camera | 2c:aa:8e:24:1f:9a | ✅ On IoT (.110) |
| GE_Light_1B77 | Smart light | 80:8a:f7:01:fd:fc | ❌ On Guest via `ginseng` (.95) — move to `ginkgo` |
| Govee Lyra | Smart light | d0:c9:07:82:94:5a | ✅ On IoT (.88) |
| Amazon Echo Dot (4th Gen) 77:de | Smart speaker | b0:73:9c:5b:77:de | ❌ On Guest via `ginseng` (.79) — move to `ginkgo` |
| Amazon Echo Dot (2nd Gen) f7:9c | Smart speaker | fc:a6:67:3d:f7:9c | ❌ On Guest via `ginseng` (.248) — move to `ginkgo` |
| Echo Show | Smart display | 08:91:a3:88:88:73 | ❌ On Guest via `ginseng` (.201) — move to `ginkgo` |
| Wyze Plug 85:43 | Smart plug | 2c:aa:8e:e9:85:43 | ❌ On Guest via `ginseng` (.121) — move to `ginkgo` |
| WYZE_CAKP2JFUS 42:69 | Wyze camera | 2c:aa:8e:fb:42:69 | ❌ On Guest via `ginseng` (.233) — move to `ginkgo` |
| Amazon Echo Dot (3rd Gen) ca:5b | Smart speaker | 08:a6:bc:75:ca:5b | ❌ On Guest via `ginseng` (.149) — move to `ginkgo` |
| Amazon Echo Dot (4th Gen) e9:b2 | Smart speaker | 34:25:be:75:e9:b2 | ❌ On Guest via `ginseng` (.131) — move to `ginkgo` |
| RokuUltra | Roku (wired, Xbox Switch port 4) | a8:b5:7c:4a:f2:17 | ✅ On IoT (.179) |
| hisense | Hisense TV (wired, Xbox Switch port 5) | a0:62:fb:61:ae:67 | ✅ On IoT (.163) |
| ESP-D7D4B9 | ESP device | 08:3a:8d:d7:d4:b9 | ✅ On IoT (.68) |
| FrontLight0 | Kasa light | 50:c7:bf:2e:75:f5 | ✅ On IoT (.180) |
| GE_Light_1B77 1b:77 | Smart light | 34:13:43:31:1b:77 | ✅ On IoT (.106) |
| GE_Light_7323 | Smart light | 34:13:43:33:73:23 | ✅ On IoT (.122) |
| HL_CAM4 | Wyze camera | 80:48:2c:3a:17:ee | ✅ On IoT (.108) |
| HS300 17:23 | Kasa power strip | e4:fa:c4:56:17:23 | ✅ On IoT (.149) |
| HS300 2e:74 | Kasa power strip | f0:a7:31:95:2e:74 | ✅ On IoT (.171) |
| KG20EQ000579 | Unidentified | 8c:4b:14:db:b1:b4 | ✅ On IoT (.147) |
| KP303 73:d4 | Kasa power strip | 60:83:e7:05:73:d4 | ✅ On IoT (.187) |
| KP303 f3:8e | Kasa power strip | e4:fa:c4:3f:f3:8e | ✅ On IoT (.92) |
| LWIP 09:bb | Wyze device | 2c:aa:8e:28:09:bb | ✅ On IoT (.124) |
| Levoit-Humidifier | Humidifier | 90:38:0c:74:73:98 | ✅ On IoT (.24) |
| TP15 65:f8 | Tapo smart plug | 3c:52:a1:3a:65:f8 | ✅ On IoT (.123) |
| TP15 6c:8d | Tapo smart plug | 3c:52:a1:3a:6c:8d | ✅ On IoT (.44) |
| WYZE_CAM_OG | Wyze camera | 80:48:2c:10:8a:fb | ✅ On IoT (.75) |

Wired devices join IoT by switch port, not SSID: Xbox Switch port 4 (Roku Ultra) and port 5
(Hisense TV), and sw-24 port 22 (Wyze wired device), are access ports with native VLAN 40.

---

## Guest Network — 192.168.60.0/24 (Guest, VLAN 60)

DHCP pool: `.21–.254` (dynamic, no reservations)
DNS: gateway only (`192.168.60.1`) — NextDNS CLI maps this subnet to the `guest` profile (`NEXTDNS_PROFILE_MAP`)
SSID: `ginseng` (kids' iPads and visitors). No client isolation, so devices on it can see each other
(LAN Minecraft). The private SSID for adults/family is `saffron` on Default.

| IP | Hostname | Notes |
|----|----------|-------|
| .1 | gateway | Guest VLAN gateway |
| .19 | minecraft | Second NIC (`eth1`, VLAN 60) — Terraform-managed; Bedrock LAN discovery for guest devices |
| .20 | minecraft2 | Second NIC (`eth1`, VLAN 60) — Terraform-managed; Bedrock LAN discovery for guest devices |

The Minecraft LXCs keep matching last octets on both networks. `vmbr0` is not VLAN-aware on any
node; Proxmox carries `tag=60` NICs on an auto-created `vmbr0v60` bridge (`eno1.60`).

The nodes' main NICs (sw-24 ports 15 tika, 16 bupu, 17 sturm) use a custom port VLAN setting:
native Default, tagged Guest (60) only; IoT (40) and Storage (220) are excluded. A non-VLAN-aware
bridge floods any tagged frame the switch sends to every guest's `eth0`, so the port must not
trunk VLANs the node doesn't use. Storage runs on each node's second NIC (`vmbr1`), on a Pro Max
port with VLAN 220 untagged and tagged VLANs blocked.

Firewall zone `Guest`: internet and gateway (DNS/DHCP/mDNS) allowed, gateway admin ports blocked
("Guest to Gateway Block Admin": 22, 80, 443, 8080, 8443, 6789); Internal and IoT blocked, except
policies "Guest to Minecraft" (allow to `.19`/`.20` on 19131/19132) and "Guest to Printer"
(allow to `.15` on 631/9100), and "Guest to 3D Printer" (allow to `.14` on TCP 8080/8898/8899 —
Flashforge LAN API + camera). Flashforge discovery is UDP broadcast and does not cross VLANs, so
add the AD5X by IP in Orca-Flashforge/FlashPrint. Guest is in the gateway mDNS proxy VLAN scope (Default, IoT, Guest;
Service Scope: All), so the printer is discoverable from `ginseng`. Minecraft LAN discovery is
broadcast-based and does not cross VLANs: `ginseng` clients find both servers through their
`eth1` NICs above; clients on other VLANs add the servers by IP.

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
| IoT | IoT (.40) | Internet allowed; blocked from Internal except Plex (`.12` TCP 32400, "IoT to Plex"); Internal can initiate to IoT; gateway admin ports blocked (22, 80, 443, 8080, 8443, 6789) |
| Guest | Guest (.60) | Internet + gateway DNS/DHCP allowed; gateway admin ports blocked; blocked from Internal and IoT except Minecraft `.19`/`.20`, printer `.15` and 3D printer `.14` |
| External | WAN | Default deny inbound, except the two port forwards to minecraft2 (`.20`: TCP 19132, UDP 30000-30009). Inbound is limited to US source addresses (Region Blocking). Direct Remote Connection to the console is off |
| Gateway | — | Management access to Internal |
| VPN | VPN tunnel | Access to Internal |
