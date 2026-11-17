# Network Segmentation

How the home network is split, what each part may reach, and how to check it. Addresses, pools and
the per-device list live in [ip-address-map.md](ip-address-map.md); this guide covers intent and procedure.

State described here was read from the controller on 2026-11-15. The firewall policies exist only on
the UniFi controller; the repo does not manage them.

## Networks and SSIDs

| Network | VLAN | Subnet | Zone | SSID | Who belongs here |
|---------|------|--------|------|------|------------------|
| Default | 1 | 192.168.233.0/24 | Internal | `saffron` | Servers, NAS, adults' laptops and phones |
| IoT | 40 | 192.168.40.0/24 | IoT | `ginkgo` (2.4 GHz, WPA2) | Smart plugs, lights, cameras, TVs, streaming boxes |
| Guest | 60 | 192.168.60.0/24 | Guest | `ginseng` | Kids' tablets and visitors |
| Storage | 220 | 192.168.220.0/24 | Internal | none | iSCSI between TrueNAS and Proxmox; no internet, no DHCP |
| Dmz | 50 | 192.168.50.0/24 | Dmz | none | minecraft2 only (internet-facing); no DHCP |

IoT has network isolation on, so IoT devices cannot talk to each other. Guest has no client isolation,
on purpose: Bedrock LAN games need the tablets to see each other and the Minecraft servers.

## What each zone may reach

| From | To Internal | To IoT | To Guest | To the gateway | To the internet |
|------|-------------|--------|----------|----------------|-----------------|
| Internal | everything | everything | replies only | everything | yes |
| IoT | Plex only (`.12` TCP 32400) | nothing | nothing | DNS, DHCP, mDNS | yes |
| Guest | Minecraft `.19` (19131, 19132), printer `.15` (631, 9100), 3D printer `.14` (8080, 8898, 8899), Plex `.12` (32400) | nothing | same VLAN only | DNS, DHCP, mDNS | yes |
| Dmz | kaz `.10` TCP 8090 (Beszel) only | nothing | replies only | routing only | yes |
| Internet | nothing (forwards go to Dmz) | nothing | nothing | nothing | n/a |

Details that are easy to miss:

- **Gateway admin ports** (22, 80, 443, 8080, 8443, 6789) are blocked from IoT and Guest by the policies
  "IoT to Gateway Block Admin" and "Guest to Gateway Block Admin".
- **Inbound from the internet** is limited to US source addresses (Region Blocking, inbound only).
  Direct Remote Connection is off, so the console is not reachable on the WAN address; remote access goes
  through unifi.ui.com or Tailscale.
- **mDNS** is forwarded between Default, IoT and Guest, so casting and printer discovery work across VLANs
  where a policy allows the traffic.
- **UPnP** is off.
- **minecraft2** is the only internet-facing host, so it sits alone on Dmz (VLAN 50, `192.168.50.20`) with
  no NIC on Default or Guest. Internal may open connections to it (SSH, Ansible, acme cert push) and Guest
  may reach 19131/19132; Dmz may not open connections to Internal, IoT or Guest except Beszel on kaz. The
  nftables outbound filter inside the container (`minecraft_egress_filter`) stays as a second layer. Guest
  devices join it by address; LAN discovery only finds minecraft (`.19`).
- **DNS** on IoT and Guest goes to the gateway, which runs the NextDNS CLI. Guest is mapped to the `guest`
  NextDNS profile (`NEXTDNS_PROFILE_MAP`); see the per-network DNS lines in the address map.

## Where does a new device go?

1. Does it need to reach the NAS, Proxmox or another server on its own initiative? Default.
2. Is it a person's phone, tablet or laptop that belongs to a guest or a child? Guest (`ginseng`).
3. Everything else, which means anything with a vendor cloud: IoT.

A device on IoT can still be controlled from Default, because Internal may open connections to IoT. If
it needs one service on Default (as the Roku needs Plex), add a narrow allow policy for that address and
port rather than moving the device.

## Putting a device on a network

**Wi-Fi:** join the SSID for that network. A device moves only by changing Wi-Fi in its own app; the
controller cannot reassign it.

**Wired:** set the switch port to access mode with the target network as native VLAN.

```bash
unifly -s default devices ports "<switch>" --with-clients     # find the port
unifly -s default devices port-set "<switch>" <port> --mode access --native-vlan IoT --name "<what it is>"
```

The device keeps its old address until it asks for a new lease. If it does not reappear within a
minute, bounce the link: power-cycle the device, or on a non-PoE switch set the port speed to 10 and
back to auto.

Confirm the move by the device's own behaviour (its API, its open ports), not by the controller's
client list. That list can show the old address for several minutes.

## What segmentation does not do

It stops a device reaching the rest of the house. It does not stop a device reporting to its vendor:
voice assistants, cameras and TVs still send what they send. That is handled per device (privacy
settings in the vendor app) and by NextDNS tracker blocklists.

Names in UniFi are fingerprint guesses or stale DHCP hostnames. Identify a device by MAC address and
switch port before acting on its name.

## Re-audit

```bash
unifly -s default networks list --all
unifly -s default wifi list --all
unifly -s default firewall zones list --all
unifly -s default firewall policies list --all -o json
unifly -s default clients list --all
unifly -s default api api/s/default/rest/portforward
unifly -s default settings get usg_geo
unifly -s default settings get mgmt        # direct_connect_enabled should be false
```

Check for:

- a client on Default that is not a server or an adult's device;
- a user-defined allow policy whose destination has no port list;
- a port forward that is enabled and not in `unifi_port_forwards`;
- `direct_connect_enabled: true`, or UPnP turned on.

From outside the house (phone on cellular), the WAN address should answer on nothing but the Minecraft ports.
