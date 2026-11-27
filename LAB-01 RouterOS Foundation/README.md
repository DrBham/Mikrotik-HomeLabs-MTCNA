# LAB-01 — RouterOS Foundation

**Status:** Completed · **Platform:** GNS3, MikroTik CHR (RouterOS 7.21.5), VPCS, WinBox
**Skills:** interface roles, IPv4 addressing, subnetting, connected routes, ICMP testing, backup vs export

## Overview

The first lab builds the smallest useful network: one MikroTik CHR router and one client (PC1) on a `/24` LAN. The goal is to prove that the router and the client can reach each other and to understand why no route is needed for that. There is no WAN, DHCP, NAT, or firewall yet.

![LAB-01 GNS3 topology: CHR-HQ-1 linked to PC1](<Topology.png>)

> [!NOTE]
> GNS3 labels the router port "Ether 1", but RouterOS names the same link `ether2`. GNS3 adapter numbers do not always match RouterOS interface names, so check `/interface print` before you configure.

## Addressing

| Device | Interface | Address | Role |
|---|---|---|---|
| CHR (`MTCNA-SOHO-R1`) | `ether1` | `192.168.56.108/24` | Management (VirtualBox host-only) |
| CHR (`MTCNA-SOHO-R1`) | `ether2` | `192.168.10.1/24` | LAN gateway |
| PC1 (VPCS) | Ethernet | `192.168.10.10/24`, gateway `192.168.10.1` | LAN client |

`192.168.10.0/24` gives 254 usable hosts (`.1`–`.254`); `.255` is the broadcast address. The gateway uses `.1` by convention, not by rule.

## Configuration

Router configuration from the export [LAB-01.rsc](LAB-01.rsc):

```routeros
/ip address add address=192.168.10.1/24 comment=LAN interface=ether2
/ip dhcp-client add interface=ether1
/system identity set name=MTCNA-SOHO-R1
```

PC1 (VPCS console):

```text
ip 192.168.10.10/24 192.168.10.1
```

## Verification

| Test | Command | Result |
|---|---|---|
| PC1 → router | `ping 192.168.10.1` (VPCS) | Replies received |
| Router → PC1 | `/ping 192.168.10.10` | `sent=3 received=3 packet-loss=0%` |
| Connected route | `/ip route print` | `192.168.10.0/24` via `ether2`, flag `DAc` |

| Router identity | IP addresses |
|---|---|
| ![System identity set to MTCNA-SOHO-R1](<System Identity.png>) | ![IP address list with 192.168.10.1/24 on ether2](<IP Address.png>) |
| **Routing table** | **Ping from PC1** |
| ![Routing table with connected route 192.168.10.0/24](<IP Route.png>) | ![VPCS ping from PC1 to 192.168.10.1](<Ping From PC1.png>) |

## Why PC1 reaches the router without a route

1. PC1 compares `192.168.10.1` with its own subnet `192.168.10.0/24`. The address is local.
2. PC1 sends an ARP request to learn the router's MAC address.
3. PC1 sends an ICMP Echo Request straight to that MAC. The gateway is not used.
4. The router has a connected route for `192.168.10.0/24`, so it can reply on `ether2`.

The default gateway matters only when the destination is outside the local subnet.

## Backup vs export

![Terminal output of export and system backup](<Backup & Export.png>)

| Format | Command | Use |
|---|---|---|
| `.rsc` export | `/export file=LAB-01` | Readable text; safe to publish after review |
| `.backup` | `/system backup save name=LAB-01` | Binary restore on the same device; can hold credentials, kept private |

## Lessons learned

- Management (`ether1`) and LAN (`ether2`) are separate subnets with separate jobs.
- RouterOS adds a connected route as soon as an address is active on an interface.
- A successful ping proves ICMP reachability for that path only, not DHCP, DNS, or Internet access.
- Use RouterOS, not the GNS3 drawing, as the source of truth for interface names.

## Files

| File | Content |
|---|---|
| [LAB-01.rsc](LAB-01.rsc) | Router export (RouterOS 7.21.5) |
| `*.png` | Topology and verification screenshots |

Next: [LAB-02 — WAN & DHCP Client](../LAB-02%20WAN%20%26%20DHCP%20Client/)
