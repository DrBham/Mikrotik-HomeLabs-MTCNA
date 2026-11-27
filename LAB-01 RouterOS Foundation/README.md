# LAB-01 — RouterOS Foundation

**Status:** Completed · **Platform:** GNS3, MikroTik CHR (RouterOS 7.21.5), VPCS, WinBox
**Skills:** interface roles, IPv4 addressing, subnetting, connected routes, ICMP testing, backup vs export

## Overview

The first lab builds the smallest useful network: one MikroTik CHR router and one client (PC1) on a `/24` LAN. The goal is to prove that the router and the client can reach each other and to understand why no route is needed for that. There is no WAN, DHCP, NAT, or firewall yet.

![LAB-01 GNS3 topology: CHR-HQ-1 linked to PC1](<Topology.png>)

> [!NOTE]
> GNS3 labels the router port "Ether 1", but RouterOS names the same link `ether2`. GNS3 adapter numbers do not always match RouterOS interface names, so RouterOS is the source of truth.

## Addressing

| Device | Interface | Address | Role |
|---|---|---|---|
| CHR (`MTCNA-SOHO-R1`) | `ether1` | `192.168.56.108/24` (DHCP from VirtualBox) | Management |
| CHR (`MTCNA-SOHO-R1`) | `ether2` | `192.168.10.1/24` | LAN gateway |
| PC1 (VPCS) | Ethernet | `192.168.10.10/24`, gateway `192.168.10.1` | LAN client |

`192.168.10.0/24` gives 254 usable hosts (`.1`–`.254`); `.255` is the broadcast address. The gateway uses `.1` by convention, not by rule.

## Configuration

### 1. Router identity

The router is named `MTCNA-SOHO-R1`, so it is easy to recognise once more routers join the topology.

```routeros
/system identity set name=MTCNA-SOHO-R1
/system identity print
```

![System identity set to MTCNA-SOHO-R1](<System Identity.png>)

### 2. LAN address

`192.168.10.1/24` is set on `ether2` with the comment `LAN`. The management address on `ether1` comes from the VirtualBox host-only DHCP server (flag `D`).

```routeros
/ip address add address=192.168.10.1/24 interface=ether2 comment=LAN
/ip address print
```

![IP address list with 192.168.10.1/24 on ether2](<IP Address.png>)

### 3. Connected routes

As soon as an address is active on an interface, RouterOS adds a connected route (`DAc`) for its subnet. No static route is needed to reach PC1.

```routeros
/ip route print
```

![Routing table with connected routes for the LAN and management subnets](<IP Route.png>)

## Verification

| Test | Result |
|---|---|
| PC1 → router `192.168.10.1` | Replies received |
| Router → PC1 `192.168.10.10` | 3/3 replies, 0% loss |
| Connected route | `192.168.10.0/24` via `ether2`, flag `DAc` |

PC1 (VPCS) and the router:

```text
PC1> ip 192.168.10.10/24 192.168.10.1
PC1> ping 192.168.10.1
```

```routeros
/ping 192.168.10.10 count=3
```

![VPCS ping from PC1 to 192.168.10.1](<Ping From PC1.png>)

## Why PC1 reaches the router without a route

1. PC1 compares `192.168.10.1` with its own subnet `192.168.10.0/24`. The address is local.
2. PC1 sends an ARP request to learn the router's MAC address.
3. PC1 sends an ICMP Echo Request straight to that MAC. The gateway is not used.
4. The router has a connected route for `192.168.10.0/24`, so it can reply on `ether2`.

The default gateway matters only when the destination is outside the local subnet.

## Backup vs export

```routeros
/export file=LAB-01
/system backup save name=LAB-01
```

![Terminal output of export and system backup](<Backup & Export.png>)

| Format | Use |
|---|---|
| `.rsc` export | Readable text; safe to publish after review |
| `.backup` | Binary restore on the same device; can hold credentials, kept private |

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
