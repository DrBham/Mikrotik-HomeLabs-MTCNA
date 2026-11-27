# LAB-04 — Firewall Fundamental

**Status:** Completed · **Platform:** GNS3, MikroTik CHR (RouterOS 7.21.5), VPCS, WinBox
**Skills:** stateful filtering, `input`/`forward`/`output` chains, connection states, rule order

## Overview

Until LAB-03 the HQ router accepted everything. LAB-04 adds a basic **stateful firewall**: replies to existing connections pass, the LAN may start connections toward the WAN, the management network may reach the router, and every other new connection is dropped. LAN, WAN, management, and NAT from the earlier labs keep working.

![LAB-04 GNS3 topology: CHR-ISP-1, CHR-HQ-1 and PC1](<Topology.png>)

## Addressing

| Device | Interface | Address | Role |
|---|---|---|---|
| CHR-ISP-1 | `ether2` | `192.168.100.1/24` | ISP side of the WAN |
| CHR-HQ-1 | `ether1` | `192.168.56.108/24` | Management |
| CHR-HQ-1 | `ether2` | `192.168.10.1/24` | LAN gateway |
| CHR-HQ-1 | `ether3` | `192.168.100.254/24` (DHCP lease) | WAN |
| PC1 | Ethernet | `192.168.10.10/24`, gateway `192.168.10.1` | LAN client |

```routeros
/ip address print
/ip route print
```

| HQ addresses | HQ routes |
|---|---|
| ![HQ IP addresses](<IP Address.png>) | ![HQ routing table](<Routing Table.png>) |

## Which chain sees which packet

| Chain | Traffic | Example in this lab |
|---|---|---|
| `input` | To the router itself | PC1 pings `192.168.10.1` |
| `forward` | Through the router | PC1 pings the ISP `192.168.100.1` |
| `output` | From the router itself | HQ pings the ISP |

Rules are read top to bottom inside each chain. An `input` rule never filters `forward` traffic.

## Policy

```routeros
/ip firewall filter
add chain=input action=drop connection-state=invalid
add chain=forward action=drop connection-state=invalid
add chain=input action=accept connection-state=established,related
add chain=forward action=accept connection-state=established,related
add chain=forward action=accept connection-state=new src-address=192.168.10.0/24 out-interface=ether3
add chain=forward action=drop connection-state=new
add chain=input action=accept connection-state=new src-address=192.168.56.0/24
add chain=input action=accept protocol=icmp src-address=192.168.10.0/24
add chain=input action=drop connection-state=new
print
```

![Firewall filter rules on CHR-HQ-1](<Firewall Filter.png>)

| # | Rule | Why |
|---|---|---|
| 0–1 | Drop `invalid` (input and forward) | Packets connection tracking cannot place |
| 2–3 | Accept `established,related` early | Replies pass without opening new holes, and most packets match here first |
| 4 | Accept new forward from `192.168.10.0/24` out `ether3` | The only forwarded traffic allowed to start a connection |
| 5 | Drop other new forward | Default deny for traffic through the router |
| 6 | Accept new input from `192.168.56.0/24` | Keeps WinBox management working |
| 7 | Accept ICMP from the LAN | PC1 can ping its gateway |
| 8 | Drop other new input | Default deny for traffic to the router |

> [!WARNING]
> Change firewall rules in **Safe Mode** (`Ctrl+X` in the terminal, or the Safe Mode button in WinBox). If a rule locks you out, RouterOS rolls the change back.

## Verification

| Test | Result |
|---|---|
| PC1 → LAN gateway `192.168.10.1` | Replies received |
| PC1 → ISP `192.168.100.1` | 5/5 replies |
| Management host `192.168.56.106` → HQ `192.168.56.108` | WinBox session works |
| HQ → ISP `192.168.100.1` | Replies received |
| Filter counters | Accept and drop rules both counted packets (forward drop 7, input drop 35) |
| NAT counter | Rose from 40 to 45 packets during the tests |

```routeros
/ip firewall filter print stats
/ip firewall nat print stats
```

| Filter counters | NAT counters |
|---|---|
| ![Firewall filter rules with packet counters](<Firewall Filter Stats.png>) | ![Masquerade rule counter after tests](<Firewall NAT Stats.png>) |

```text
PC1> ping 192.168.100.1
PC1> ping 192.168.10.1
```

![PC1 connectivity tests after the firewall was applied](<PC1 Connectivity Validation.png>)

## Backup and export

```routeros
/system backup save name=LAB-04
/export file=LAB-04
```

![HQ backup and export](<HQ Backup & Export.png>)

## Troubleshooting

**HQ WAN DHCP client stuck on `searching...`.** `ether3` showed `RUNNING`, the ISP DHCP server was enabled, and the ISP lease list was empty. After GNS3 was restarted the client returned to `bound` with `192.168.100.254/24`. The exact root cause was not isolated. Lesson: `RUNNING` means the link is up, not that DHCP succeeded.

Check order used: link → interface → DHCP lease → IP → ARP → routing → firewall → NAT.

## Known issue

The final `drop new input` rule also blocks DNS queries from the LAN. It was found later and resolved in [LAB-06, DNS for LAN clients](../LAB-06%20Routing%20Fundamental/#4-dns-for-lan-clients).

## Lessons learned

- `input` protects the router; `forward` protects the networks behind it.
- Rule order decides the result. Moving "drop new forward" above "accept LAN → WAN" would cut the LAN off.
- Counters show that a rule matched, not that the policy is right. Pair them with a test that should be blocked.

## Files

| File | Content |
|---|---|
| [LAB-04.rsc](LAB-04.rsc) | CHR-HQ-1 export |
| `*.png` | Topology, addressing, routing, firewall, NAT, test, and backup screenshots |

Previous: [LAB-03](../LAB-03%20NAT%20%26%20Internet%20Access/) · Next: [LAB-05 — DHCP Server](../LAB-05%20DHCP%20Server%20%26%20LAN%20Client%20Management/)
