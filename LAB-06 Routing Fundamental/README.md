# LAB-06 — Routing Fundamental

**Status:** Completed · **Platform:** GNS3, MikroTik CHR (RouterOS 7.21.5), VPCS, WinBox
**Skills:** static routing, connected routes, forward policy, NAT exemption, two-way testing

## Overview

LAB-06 adds a second site. **CHR-BRANCH-1** joins the transit network `192.168.100.0/24` next to HQ, and both LANs reach each other through **static routes**. The HQ firewall and NAT from earlier labs stay in place, with two narrow changes so that branch traffic is allowed and not masqueraded.

![LAB-06 GNS3 topology: ISP, HQ and BRANCH on one transit switch](<Topology.png>)

> [!NOTE]
> The topology drawing labels BRANCH `ether3` as `192.168.100.2`. The configured and tested address is `192.168.100.253`, as in the export.

## Addressing

| Device | Interface | Address | Role |
|---|---|---|---|
| CHR-ISP-1 | `ether2` | `192.168.100.1/24` | Transit, DHCP server |
| CHR-HQ-1 | `ether1` | `192.168.56.108/24` | Management |
| CHR-HQ-1 | `ether2` | `192.168.10.1/24` | HQ LAN gateway |
| CHR-HQ-1 | `ether3` | `192.168.100.254/24` (DHCP lease) | Transit |
| CHR-BRANCH-1 | `ether1` | `192.168.56.110/24` | Management |
| CHR-BRANCH-1 | `ether2` | `192.168.20.1/24` | BRANCH LAN gateway |
| CHR-BRANCH-1 | `ether3` | `192.168.100.253/24` (static) | Transit |
| PC1 | Ethernet | DHCP lease `192.168.10.100/24` | HQ client |
| PC2 | Ethernet | DHCP lease `192.168.20.100/24` | BRANCH client |

HQ and BRANCH share one Layer-2 segment through Switch1, so traffic between them does not pass through the ISP router.

## Configuration

### 1. BRANCH addressing and DHCP

From [LAB-06-BRANCH.rsc](LAB-06-BRANCH.rsc):

```routeros
/ip address add address=192.168.20.1/24 interface=ether2
/ip address add address=192.168.100.253/24 interface=ether3
/ip pool add name=BRANCH-POOL ranges=192.168.20.10-192.168.20.100
/ip dhcp-server add address-pool=BRANCH-POOL interface=ether2 name=dhcp1
/ip dhcp-server network add address=192.168.20.0/24 gateway=192.168.20.1
/system identity set name=BRANCH
```

### 2. Static routes

| Router | Destination | Next hop |
|---|---|---|
| HQ | `192.168.20.0/24` | `192.168.100.253` (BRANCH) |
| BRANCH | `192.168.10.0/24` | `192.168.100.254` (HQ) |

```routeros
# HQ
/ip route add dst-address=192.168.20.0/24 gateway=192.168.100.253
# BRANCH
/ip route add dst-address=192.168.10.0/24 gateway=192.168.100.254
```

The static route names the remote LAN; the connected route `192.168.100.0/24` tells each router how to reach the next hop.

### 3. HQ firewall: allow BRANCH → HQ

The LAB-04 policy dropped every new forwarded connection except LAN → WAN, so PC1 could ping PC2 but PC2 could not ping PC1. One rule, placed **above** the final `drop new forward`, fixed that:

```routeros
/ip firewall filter add chain=forward action=accept connection-state=new \
    src-address=192.168.20.0/24 dst-address=192.168.10.0/24 \
    comment=LAB06-Allow-Branch-to-HQ
```

### 4. HQ NAT exemption

The LAB-03 masquerade rule matches everything leaving `ether3`, including traffic to BRANCH. An exemption **above** it keeps the original HQ source address:

```routeros
/ip firewall nat add chain=srcnat action=accept \
    src-address=192.168.10.0/24 dst-address=192.168.20.0/24 \
    comment=LAB06-No-NAT-HQ-to-Branch
```

The exemption counted 15 packets (1,260 bytes) during testing.

| HQ forward rules | HQ NAT rules |
|---|---|
| ![HQ firewall filter with Branch-to-HQ rule above the drop](<HQ - Firewall Filter.png>) | ![HQ NAT exemption above masquerade with counters](<HQ - Firewall NAT.png>) |

## Verification

| Test | Result |
|---|---|
| PC1 / PC2 DHCP | `192.168.10.100/24` and `192.168.20.100/24` |
| Static routes on HQ and BRANCH | Active (`As`) |
| HQ → BRANCH LAN interface `192.168.20.1` | 4/4 replies |
| PC1 → PC2 (`ping 192.168.20.100 -c 10`) | 10/10 replies |
| PC2 → PC1 (`ping 192.168.10.100 -c 10`) | 10/10 replies |

| HQ addresses and routes | BRANCH addresses and routes |
|---|---|
| ![HQ IP addresses and routing table with static route to BRANCH](<HQ - IP Address & Routing Table.png>) | ![BRANCH IP addresses and routing table with static route to HQ](<BRANCH - IP Address & Routing Table.png>) |
| **HQ DHCP lease** | **BRANCH DHCP lease** |
| ![HQ lease for PC1](<HQ - DHCP Lease.png>) | ![BRANCH lease for PC2](<BRANCH - DHCP Lease.png>) |
| **PC1 → PC2** | **PC2 → PC1** |
| ![PC1 ping to PC2, 10 of 10 replies](<Ping PC1 to PC2.png>) | ![PC2 ping to PC1, 10 of 10 replies](<Ping PC2 to PC1.png>) |

Earlier test runs had some timeouts. Their cause was not isolated; the final runs above had no loss.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| HQ → BRANCH LAN: `net unreachable` from the ISP | HQ only had connected and default routes, so it sent the packet to the ISP | Static route on HQ to `192.168.20.0/24` |
| BRANCH → HQ LAN: `no route to host` | BRANCH had no route to `192.168.10.0/24` | Static route on BRANCH |
| PC1 → PC2 works, PC2 → PC1 times out | HQ `forward` dropped new connections from BRANCH | Accept rule above the drop |
| HQ → BRANCH traffic masqueraded | Masquerade matched all traffic out of `ether3` | `srcnat accept` exemption above it |
| BRANCH → HQ router interface times out | HQ `input` chain, not `forward` | Not needed for this lab; left as is |
| Both PCs show `0.0.0.0` after reopening the lab | VPCS had no active lease | `ip dhcp` on each PC |

## Post-lab fixes

A review after the lab found five gaps. The scripts in [fixes/](fixes/) address them.

> [!IMPORTANT]
> These scripts have **not been run in the lab yet**. The exports above show the state that was tested.

| Gap | Fix | Script |
|---|---|---|
| ISP pool `.10`–`.254` contains BRANCH's static `.253` and the HQ lease `.254` that BRANCH routes to | Reserve HQ's lease, shrink the pool to `.10`–`.200` | [01-ISP-fix.rsc](fixes/01-ISP-fix.rsc) |
| HQ hands out DNS `192.168.10.1` but blocks and ignores DNS queries | Enable remote requests; accept UDP/TCP 53 from the LAN | [02-HQ-fix.rsc](fixes/02-HQ-fix.rsc) |
| BRANCH has no firewall, NAT, default route, or client DNS | Same policy as HQ, NAT exemption to HQ, default route, DNS | [03-BRANCH-fix.rsc](fixes/03-BRANCH-fix.rsc) |
| Leftover DHCP client on BRANCH `ether4`; server named `dhcp1` | Remove and rename | [03-BRANCH-fix.rsc](fixes/03-BRANCH-fix.rsc) |
| Unused services, discovery and MAC access open on all ports | Limit to the management port; replace `admin` | [04-hardening.rsc](fixes/04-hardening.rsc) |

**Apply order**

1. Back up each router: `/system backup save name=before-fix`.
2. In WinBox on `ether1`, turn on **Safe Mode**.
3. Paste `01-ISP-fix.rsc` on ISP, `02-HQ-fix.rsc` on HQ, `03-BRANCH-fix.rsc` on BRANCH.
4. Paste `04-hardening.rsc` on all three routers. Create a new admin user by hand as the script describes.
5. Run the checks below, then turn off Safe Mode to keep the changes.

**Checks after the fixes**

```text
PC1> ping 192.168.20.100 -c 5     # still 5/5
PC2> ping 192.168.10.100 -c 5     # still 5/5
PC1> ping isp.lab                 # resolves to 192.168.100.1
PC2> ping isp.lab                 # resolves to 192.168.100.1
PC2> ping 192.168.100.1           # BRANCH LAN reaches the ISP through NAT
```

**Rollback:** close the WinBox session while Safe Mode is still on (RouterOS discards the changes), or run `/system backup load name=before-fix` on the affected router.

## Lessons learned

- Each router needs a route to every remote network; return traffic needs its own route.
- `input` and `forward` answer different questions: "may I talk to the router?" versus "may I pass through it?"
- A broad NAT rule can catch traffic that should be routed. Exempt it explicitly.
- Static routes to a DHCP-assigned next hop break when the lease changes.

## Files

| File | Content |
|---|---|
| [LAB-06-HQ.rsc](LAB-06-HQ.rsc) | CHR-HQ-1 export (tested state) |
| [LAB-06-BRANCH.rsc](LAB-06-BRANCH.rsc) | CHR-BRANCH-1 export (tested state) |
| [fixes/](fixes/) | Post-lab fix scripts (not yet tested) |
| `*.png` | Topology, addressing, routing, DHCP, firewall, NAT, and ping screenshots |

Previous: [LAB-05](../LAB-05%20DHCP%20Server%20%26%20LAN%20Client%20Management/) · Next (planned): [LAB-07 — Bridging and ARP](../LAB-07%20Bridging%20and%20ARP/) · Final project: [Small Office Multi-Site Network Deployment](https://github.com/DrBham/Small-Office-Multi-Site-Network-Deployment)
