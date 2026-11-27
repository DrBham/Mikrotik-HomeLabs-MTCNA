# LAB-03 — NAT & Internet Access

**Status:** Completed · **Platform:** GNS3, MikroTik CHR (RouterOS 7.21.5), VPCS, WinBox
**Skills:** source NAT, masquerade, NAT counters, connection tracking, routing vs NAT

## Overview

In LAB-02 only the HQ router could reach the ISP. LAB-03 lets the LAN client PC1 reach the ISP too by adding one **source NAT (masquerade)** rule on the HQ WAN port. Connection tracking and rule counters prove that PC1's traffic is translated.

![LAB-03 GNS3 topology: CHR-ISP-1, CHR-HQ-1 and PC1](<Topology.png>)

> [!NOTE]
> The ISP has no real upstream, so "Internet access" here means reaching the simulated ISP at `192.168.100.1`.

## Addressing

| Device | Interface | Address | Role |
|---|---|---|---|
| CHR-ISP-1 | `ether2` | `192.168.100.1/24` | ISP side of the WAN |
| CHR-HQ-1 | `ether1` | `192.168.56.108/24` | Management |
| CHR-HQ-1 | `ether2` | `192.168.10.1/24` | LAN gateway |
| CHR-HQ-1 | `ether3` | `192.168.100.254/24` (DHCP lease) | WAN |
| PC1 | Ethernet | `192.168.10.10/24`, gateway `192.168.10.1` | LAN client |

## Configuration

One rule on CHR-HQ-1 ([LAB-03.rsc](LAB-03.rsc)):

```routeros
/ip firewall nat add chain=srcnat action=masquerade out-interface=ether3
```

Packets that leave `ether3` get the current WAN address as their source. `masquerade` follows the address automatically, which suits a DHCP-assigned WAN.

```text
Before NAT:  src 192.168.10.10    dst 192.168.100.1
After NAT:   src 192.168.100.254  dst 192.168.100.1
```

Only the source changes, because this is `srcnat`. Both addresses are private: NAT means address translation, not "private to public".

![NAT rule list with the masquerade rule on ether3](<Firewall NAT.png>)

## Verification

| Test | Result |
|---|---|
| PC1 → LAN gateway `192.168.10.1` | Replies received |
| PC1 → ISP `192.168.100.1` | Replies received |
| NAT counter while PC1 pings | Rose from 5 to 10 packets |
| `/ip firewall connection print` | ICMP flows `192.168.10.10 → 192.168.100.1` with the `s` (SRCNAT) flag |
| PC1 → `8.8.8.1` | `Destination network unreachable` (expected: the LAB-02 test route was removed) |

![Connection tracking table showing SRCNAT ICMP flows from PC1](<Firewall Connection.png>)

![PC1 pings to the LAN gateway and the ISP](<PC1 LAN & WAN Connectivity.png>)

## Routing vs NAT

| Function | Job in this lab |
|---|---|
| Routing | Picks the exit: default route `0.0.0.0/0` via `192.168.100.1` |
| NAT | Rewrites PC1's source address on the way out of `ether3` |
| Connection tracking | Remembers each flow so replies are translated back to PC1 |

A NAT counter of 0 does not always mean NAT is broken. Traffic that never leaves `ether3`, such as PC1 → `192.168.10.1`, should not match the rule.

![HQ routing table with connected and default routes](<Routing Table.png>)

## Troubleshooting

**PC1 could not reach its own gateway (`Host unreachable`).**
Evidence: PC1 showed `0.0.0.0/0`, both ARP tables were empty, `ether2` was `link-ok`, and the GNS3 cabling was correct.
Cause: VPCS lost its IP setting after a restart. Restarting GNS3 and setting the IP again restored the LAN.

Check order used: link → interface → IP → ARP → route → NAT.

## Lessons learned

- `srcnat` changes the source, never the destination.
- Routing decides where a packet goes; NAT only changes its addresses.
- Read NAT counters together with the traffic that should match the rule.

## Files

| File | Content |
|---|---|
| [LAB-03.rsc](LAB-03.rsc) | CHR-HQ-1 export |
| `*.png` | Topology, addressing, routing, NAT, connection tracking, test, and backup screenshots |

Previous: [LAB-02](../LAB-02%20WAN%20%26%20DHCP%20Client/) · Next: [LAB-04 — Firewall Fundamental](../LAB-04%20Firewall%20Fundamental/)
