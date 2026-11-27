<div align="center">

# MikroTik MTCNA Home Labs

**Six hands-on RouterOS labs covering MTCNA fundamentals, built and tested in GNS3**

![RouterOS](https://img.shields.io/badge/MikroTik-RouterOS%20CHR-2563eb?style=flat-square)
![GNS3](https://img.shields.io/badge/GNS3-Virtual%20Lab-0f766e?style=flat-square)
![Labs](https://img.shields.io/badge/Labs-LAB--01%20to%20LAB--06-16a34a?style=flat-square)

</div>

## Overview

Six hands-on MikroTik RouterOS labs for practising MTCNA topics. The labs grow one network step by step, from a single router with one LAN to two sites linked by static routing.

Each lab follows the same workflow: **learn → configure → verify → troubleshoot → document**. Lab write-ups record the goal, topology, configuration, test results, and lessons learned.

## Lab Environment

| Tool | Role |
|---|---|
| **GNS3** | Topology design and node connections |
| **MikroTik CHR (RouterOS)** | Routers for addressing, DHCP, NAT, firewall, and routing |
| **Oracle VirtualBox** | Virtualization and host-only management network |
| **WinBox** | RouterOS administration |
| **VPCS** | Simulated clients for connectivity tests |
| **MikroTik hAP lite (RB941-2nD)** | Real hardware for the planned wireless lab |

## Labs

| Lab | Topic | Skills | Status |
|---|---|---|---|
| [LAB-01 — RouterOS Foundation](LAB-01%20RouterOS%20Foundation/) | Interfaces and IPv4 addressing | LAN setup, subnetting, connected routes, ICMP | Completed |
| [LAB-02 — WAN & DHCP Client](LAB-02%20WAN%20%26%20DHCP%20Client/) | Simulated ISP and dynamic WAN | DHCP client, WAN lease, default route, DNS simulation | Completed |
| [LAB-03 — NAT & Internet Access](LAB-03%20NAT%20%26%20Internet%20Access/) | Source NAT | Masquerade, NAT counters, connection tracking | Completed¹ |
| [LAB-04 — Firewall Fundamental](LAB-04%20Firewall%20Fundamental/) | Stateful filtering | Input/forward/output chains, connection states, rule order | Completed |
| [LAB-05 — DHCP Server & LAN Client Management](LAB-05%20DHCP%20Server%20%26%20LAN%20Client%20Management/) | Dynamic LAN addressing | DHCP pool, network, leases, DORA, troubleshooting | Completed |
| [LAB-06 — Routing Fundamental](LAB-06%20Routing%20Fundamental/) | HQ–Branch integration | Static routes, forward policy, NAT exemption, two-way testing | Completed² |

¹ LAB-03 verifies NAT and connectivity to the **simulated ISP**, not access to the public Internet.
² Two-way connectivity was validated, then extended with DNS for both LANs, a reserved transit address, a BRANCH firewall, and management hardening on all routers.

### Planned labs

These step-by-step guides fill the remaining MTCNA topics. Each one is written but **not yet performed**; its status changes to Completed once screenshots and an export are added.

| Lab | Topic | Skills | Status |
|---|---|---|---|
| [LAB-07 — Bridging and ARP](LAB-07%20Bridging%20and%20ARP/) | Switched LAN | Bridge ports, MAC learning, ARP `reply-only`, static ARP | Planned |
| [LAB-08 — RouterOS Management and Backup](LAB-08%20RouterOS%20Management%20and%20Backup/) | Device management | Users and groups, services, NTP, upgrade, scheduled backup, restore | Planned |
| [LAB-09 — QoS and Bandwidth Management](LAB-09%20QoS%20and%20Bandwidth%20Management/) | Traffic shaping | Simple queues, burst, PCQ | Planned |
| [LAB-10 — Advanced Firewall and Port Forwarding](LAB-10%20Advanced%20Firewall%20and%20Port%20Forwarding/) | Firewall | Address lists, dst-nat, logging, FastTrack | Planned |
| [LAB-11 — PPPoE and Tunnels](LAB-11%20PPPoE%20and%20Tunnels/) | Access and VPN | PPPoE server/client, L2TP/IPsec site-to-site, route failover | Planned |
| [LAB-12 — Network Tools and Troubleshooting](LAB-12%20Network%20Tools%20and%20Troubleshooting/) | Operations | Netwatch, Torch, sniffer, logging, SNMP, break-fix scenarios | Planned |
| [LAB-13 — Wireless with hAP lite](LAB-13%20Wireless%20with%20hAP%20lite/) | Wireless (real hardware) | AP and station modes, WPA2, access list, registration table | Planned |

## Topology

**LAB-01 to LAB-05:** one HQ router with a LAN and a WAN uplink to a simulated ISP.

```text
Laptop / WinBox (host-only management)
            |
         CHR-HQ-1
         /      \
   LAN ether2   WAN ether3 (DHCP client)
       |               |
      PC1         CHR-ISP-1
 192.168.10.0/24  192.168.100.0/24
```

Across these labs, HQ gains a static LAN, a DHCP client on the WAN, source NAT (masquerade), a basic stateful firewall, and finally a DHCP server for the LAN.

**LAB-06:** a Branch router joins the same transit network, and both LANs are connected with static routes.

```text
                  CHR-ISP-1
                 192.168.100.1
                       |
                     Switch
                    /      \
             CHR-HQ-1      CHR-BRANCH-1
             WAN .254      WAN .253
               |              |
            HQ LAN         BRANCH LAN
        192.168.10.0/24  192.168.20.0/24
               |              |
              PC1            PC2
```

## Results

| Test | Result |
|---|---|
| PC1 → PC2 (HQ to Branch, LAB-06) | 10/10 ICMP replies in the final test |
| PC2 → PC1 (Branch to HQ, LAB-06) | 10/10 ICMP replies in the final test |
| PC1 DHCP lease from HQ (LAB-05) | `192.168.10.100/24`, gateway and DNS `192.168.10.1` |
| Source NAT on HQ WAN (LAB-03) | PC1 reaches the simulated ISP through masquerade |

## Repository Structure

Each lab folder holds the evidence for that lab: a write-up, screenshots, and RouterOS `.rsc` exports. For example:

```text
LAB-04 Firewall Fundamental/
├── README.md        # Goal, configuration, tests, lessons learned
├── Topology.png     # GNS3 topology
├── *.png            # Screenshots of addressing, routing, firewall, and tests
└── LAB-04.rsc       # RouterOS configuration export
```

Start with LAB-01 to follow the labs in order, or open LAB-06 for the complete two-site setup.

## Scope

- **Simulated ISP:** the ISP router has no real upstream, so NAT and default-route tests prove connectivity to the simulated ISP only, not to the public Internet.
- **Dynamic WAN address:** HQ receives `.254` by DHCP. The Branch static route points to that address, so the ISP reserves it for HQ.
- **Not covered yet:** bridging, wireless, queues (QoS), tunnels/PPPoE, and RouterOS tools such as Netwatch and Torch. Guides for these are in the planned labs above.
- **Published files:** configurations are shared as `.rsc` exports. Binary `.backup` files and credentials are not included.
- **Credentials:** exports do not contain users or passwords. After importing a configuration into your own CHR, log in as `admin` and set your own password.

This is a simulation-based home lab. It is not a production deployment and does not claim coverage of the full MTCNA syllabus.

## Disclaimer

This is an independent study project. It is not affiliated with or endorsed by MikroTik, and it contains no official MikroTik training material. All topologies, configurations, and screenshots were made by me. MikroTik, RouterOS, and MTCNA are trademarks of MikroTik.

## Final Project

The topics from these labs are combined in the final project, published in its own repository: **[Small Office Multi-Site Network Deployment](https://github.com/DrBham/Small-Office-Multi-Site-Network-Deployment)**.
