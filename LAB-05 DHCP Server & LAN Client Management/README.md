# LAB-05 — DHCP Server & LAN Client Management

**Status:** Completed · **Platform:** GNS3, MikroTik CHR (RouterOS 7.21.5), VPCS, WinBox
**Skills:** DHCP pool, server, and network; DORA; lease inspection; DHCP troubleshooting

## Overview

PC1 used a static address in LAB-01 to LAB-04. LAB-05 turns the HQ router into a **DHCP server** for the LAN, so PC1 gets its address, gateway, and DNS server automatically. The firewall and NAT from LAB-04 stay in place.

![LAB-05 GNS3 topology: CHR-ISP-1, CHR-HQ-1 and PC1](<Topology.png>)

## Addressing

| Device | Interface | Address | Role |
|---|---|---|---|
| CHR-ISP-1 | `ether2` | `192.168.100.1/24` | ISP side of the WAN |
| CHR-HQ-1 | `ether1` | `192.168.56.108/24` | Management |
| CHR-HQ-1 | `ether2` | `192.168.10.1/24` | LAN gateway, DHCP server |
| CHR-HQ-1 | `ether3` | `192.168.100.254/24` (DHCP lease) | WAN |
| PC1 | Ethernet | DHCP lease `192.168.10.100/24` | LAN client |

## Configuration

A RouterOS DHCP server has three parts ([LAB-05.rsc](LAB-05.rsc)):

```routeros
/ip pool add name=LAN-POOL ranges=192.168.10.10-192.168.10.100
/ip dhcp-server add address-pool=LAN-POOL interface=ether2 name=DHCP-LAN
/ip dhcp-server network add address=192.168.10.0/24 dns-server=192.168.10.1 gateway=192.168.10.1
```

| Part | Value | Job |
|---|---|---|
| Pool | `LAN-POOL`, `.10`–`.100` (91 addresses) | Addresses the server may hand out |
| Server | `DHCP-LAN` on `ether2`, lease `30m` | Answers requests on the LAN |
| Network | `192.168.10.0/24`, gateway and DNS `192.168.10.1` | Options sent with each lease |

| IP pool | DHCP server | DHCP network |
|---|---|---|
| ![LAN-POOL range 192.168.10.10-100](<IP Pool.png>) | ![DHCP-LAN server on ether2](<DHCP Server.png>) | ![DHCP network with gateway and DNS](<DHCP Server Network.png>) |

## How PC1 gets its lease (DORA)

```text
PC1                          DHCP-LAN (HQ)
 | --- DISCOVER (broadcast) -->  |
 | <-- OFFER 192.168.10.100 ---  |
 | --- REQUEST 192.168.10.100 -> |
 | <-- ACK (lease 30m) --------  |
```

The DORA sequence is protocol theory here; no packet capture was taken. The result is visible in the lease table.

## Verification

| Test | Result |
|---|---|
| PC1 `show ip` | `192.168.10.100/24`, gateway and DNS `192.168.10.1`, DHCP server `192.168.10.1` |
| HQ lease table | `192.168.10.100`, MAC `00:50:79:66:68:00`, host name `PC11` (as sent by VPCS), server `DHCP-LAN`, `bound` |
| PC1 → LAN gateway `192.168.10.1` | Replies received |
| PC1 → ISP `192.168.100.1` | Replies received; NAT counter rose |
| PC1 → `8.8.8.8` | No reply (expected: the ISP has no upstream) |

| PC1 lease | HQ lease table |
|---|---|
| ![VPCS showing DHCP address 192.168.10.100](<PC1 DHCP IP.png>) | ![HQ DHCP lease for PC1 in bound state](<DHCP Server Lease.png>) |

![PC1 pings to the gateway and the ISP](<PC1 Ping.png>)

## Troubleshooting

| Problem | Evidence | Fix |
|---|---|---|
| Wrong pool range | Pool typed as `102.168.10.10-102.168.10.100` | Corrected to `192.168.10.10-192.168.10.100`. A command that runs is not a command that is right. |
| Wrong gateway option | DHCP network gateway `192.168.0.101` | Corrected to `192.168.10.1`, inside PC1's subnet |
| PC1 got no lease | A temporary firewall rule was tried | Removed again: it was not the final fix. Rule counters alone do not prove a root cause. |
| HQ WAN `searching...` | ISP `ether2` briefly not `RUNNING`; dynamic default route gone | Lease returned once the link was up. No default route means no WAN path. |

Check order used: link → interface → IP → ARP → route → firewall → NAT → connection tracking → upstream.

## Known issue

DHCP gives PC1 the DNS server `192.168.10.1`, but HQ does not accept DNS queries from the LAN. PC1 can ping by IP but cannot resolve names. The fix is in [LAB-06 fixes](../LAB-06%20Routing%20Fundamental/fixes/02-HQ-fix.rsc).

## Lessons learned

- Pool, server, and network are separate objects; a typo in any one breaks the lease.
- A lease is a time-limited loan of an address, not the time a client is online.
- Handing out a DNS address does not make the router a working resolver.

## Files

| File | Content |
|---|---|
| [LAB-05.rsc](LAB-05.rsc) | CHR-HQ-1 export |
| `*.png` | Topology, DHCP, routing, test, and backup screenshots |

Previous: [LAB-04](../LAB-04%20Firewall%20Fundamental/) · Next: [LAB-06 — Routing Fundamental](../LAB-06%20Routing%20Fundamental/)
