# LAB-02 — WAN & DHCP Client

**Status:** Completed · **Platform:** GNS3, MikroTik CHR (RouterOS 7.21.5), VPCS, WinBox
**Skills:** simulated ISP, DHCP server, DHCP client on WAN, dynamic default route, DNS basics

## Overview

LAB-02 adds a second router, **CHR-ISP-1**, that plays the role of an Internet provider. The ISP runs a DHCP server; the HQ router gets its WAN address, default gateway, and DNS server from it with a DHCP client. The LAN from LAB-01 keeps working.

![LAB-02 GNS3 topology: CHR-ISP-1, CHR-HQ-1 and PC1](<Topology.png>)

> [!NOTE]
> The ISP has no real upstream. Tests here prove reachability inside the lab, not public Internet access.

## Addressing

| Device | Interface | Address | Role |
|---|---|---|---|
| CHR-ISP-1 | `ether1` | `192.168.56.109/24` | Management |
| CHR-ISP-1 | `ether2` | `192.168.100.1/24` | ISP side of the WAN, DHCP server |
| CHR-HQ-1 | `ether1` | `192.168.56.108/24` | Management |
| CHR-HQ-1 | `ether2` | `192.168.10.1/24` | LAN gateway |
| CHR-HQ-1 | `ether3` | `192.168.100.254/24` (DHCP lease) | WAN |
| PC1 | Ethernet | `192.168.10.10/24`, gateway `192.168.10.1` | LAN client |

`192.168.100.254` is the lease HQ received in this lab. A DHCP address can change; LAB-06 shows why that matters.

## Configuration

**CHR-ISP-1** — DHCP server for the WAN segment ([LAB-02-ISP.rsc](LAB-02-ISP.rsc)):

```routeros
/ip address add address=192.168.100.1/24 interface=ether2
/ip pool add name=ISP-POOL ranges=192.168.100.10-192.168.100.254
/ip dhcp-server add address-pool=ISP-POOL interface=ether2 name=ISP-DHCP
/ip dhcp-server network add address=192.168.100.0/24 dns-server=192.168.100.1 gateway=192.168.100.1
/ip dns set allow-remote-requests=yes
/system identity set name=ISP
```

**CHR-HQ-1** — DHCP client on the WAN port ([LAB-02.rsc](LAB-02.rsc)):

```routeros
/ip dhcp-client add interface=ether3
```

With the RouterOS defaults (`add-default-route=yes`, `use-peer-dns=yes`) the client installs a default route to `192.168.100.1` and uses the ISP as its DNS server.

| ISP DHCP server | ISP DHCP network |
|---|---|
| ![ISP DHCP server ISP-DHCP on ether2](<DHCP-Server ISP.png>) | ![ISP DHCP network with gateway and DNS 192.168.100.1](<DHCP-Server Network ISP.png>) |
| **HQ DHCP client** | **HQ routing table** |
| ![HQ DHCP client bound with 192.168.100.254/24](<DHCP-Client Detail HQ.png>) | ![HQ routing table with dynamic default route](<Routing Table HQ.png>) |

## Verification

| Test | Result |
|---|---|
| HQ DHCP client on `ether3` | `bound`, `192.168.100.254/24`, gateway and DNS `192.168.100.1` |
| HQ → ISP gateway `192.168.100.1` | 0% packet loss |
| HQ → simulated external host `8.8.8.1` | Replies received |
| HQ resolves test record `lab02.test` → `8.8.8.1` | Resolved |
| HQ resolves `google.com` | `resolve failed` (expected: no real upstream) |
| PC1 → LAN gateway `192.168.10.1` | Replies received |

`8.8.8.1` and `lab02.test` existed only on the simulated ISP during testing; they are not in the final exports.

| HQ → ISP gateway | HQ → simulated external host |
|---|---|
| ![HQ ping to 192.168.100.1](<HQ Ping To Gateway WAN.png>) | ![HQ ping to simulated external 8.8.8.1](<HQ Ping Simulated External.png>) |
| **DNS test** | **PC1 → LAN gateway** |
| ![DNS resolution of lab02.test](<DNS Verification.png>) | ![PC1 ping to 192.168.10.1](<PC1 Ping Gateway.png>) |

## Routes on HQ

| Route | Source | Purpose |
|---|---|---|
| `192.168.10.0/24` via `ether2` | Connected | LAN |
| `192.168.100.0/24` via `ether3` | Connected (from the DHCP address) | WAN segment |
| `0.0.0.0/0` via `192.168.100.1` | DHCP client | Everything else |

## Troubleshooting

**Wrong interface.** GNS3 adapter numbers did not match RouterOS interface names, so the first DHCP client attempt sat on the wrong port. The fix was to map each cable with `/interface print` and `/ip address print` first, then put the DHCP client on `ether3`.

Check order used: interface → IP → DHCP lease → route → ping by IP → DNS.

## Lessons learned

- A DHCP lease gives the router an address, gateway, and DNS in one step.
- A default route only names the next hop; it does not prove the far end is reachable.
- DNS failure and IP failure are different problems. Ping by IP first.

## Files

| File | Content |
|---|---|
| [LAB-02.rsc](LAB-02.rsc) | CHR-HQ-1 export |
| [LAB-02-ISP.rsc](LAB-02-ISP.rsc) | CHR-ISP-1 export |
| `*.png` | Topology, interfaces, addressing, DHCP, routing, and test screenshots |

Previous: [LAB-01](../LAB-01%20RouterOS%20Foundation/) · Next: [LAB-03 — NAT & Internet Access](../LAB-03%20NAT%20%26%20Internet%20Access/)
