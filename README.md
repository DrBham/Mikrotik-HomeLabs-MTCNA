<div align="center">

# MikroTik MTCNA Home Labs

**Six hands-on RouterOS labs covering MTCNA fundamentals, built and tested in GNS3**

![RouterOS](https://img.shields.io/badge/MikroTik-RouterOS%20CHR-2563eb?style=flat-square)
![GNS3](https://img.shields.io/badge/GNS3-Virtual%20Lab-0f766e?style=flat-square)
![Labs](https://img.shields.io/badge/Labs-LAB--01%20to%20LAB--06-16a34a?style=flat-square)

</div>

## Overview

This repository documents six MikroTik home labs that I built to revisit and strengthen the core topics of the **MikroTik Certified Network Associate (MTCNA)** course, and to build a portfolio toward a Junior Network Engineer role. The labs grow one network step by step, from a single router with one LAN to two sites linked by static routing.

Each lab follows the same workflow: **learn → configure → verify → troubleshoot → document**. Lab write-ups record the goal, topology, configuration, test results, and lessons learned.

## Lab Environment

| Tool | Role |
|---|---|
| **GNS3** | Topology design and node connections |
| **MikroTik CHR (RouterOS)** | Routers for addressing, DHCP, NAT, firewall, and routing |
| **Oracle VirtualBox** | Virtualization and host-only management network |
| **WinBox** | RouterOS administration |
| **VPCS** | Simulated clients for connectivity tests |

## Labs

| Lab | Topic | Skills | Status |
|---|---|---|---|
| [LAB-01 — RouterOS Foundation](LAB-01%20RouterOS%20Foundation/) | Interfaces and IPv4 addressing | LAN setup, subnetting, connected routes, ICMP | Completed |
| [LAB-02 — WAN & DHCP Client](LAB-02%20WAN%20%26%20DHCP%20Client/) | Simulated ISP and dynamic WAN | DHCP client, WAN lease, default route, DNS simulation | Completed |
| [LAB-03 — NAT & Internet Access](LAB-03%20NAT%20%26%20Internet%20Access/) | Source NAT | Masquerade, NAT counters, connection tracking | Completed¹ |
| [LAB-04 — Firewall Fundamental](LAB-04%20Firewall%20Fundamental/) | Stateful filtering | Input/forward/output chains, connection states, rule order | Completed |
| [LAB-05 — DHCP Server & LAN Client Management](LAB-05%20DHCP%20Server%20%26%20LAN%20Client%20Management/) | Dynamic LAN addressing | DHCP pool, network, leases, DORA, troubleshooting | Completed |
| [LAB-06 — Routing Fundamental](LAB-06%20Routing%20Fundamental/) | HQ–Branch integration | Static routes, forward policy, NAT exemption, two-way testing | Technical PASS² |

¹ LAB-03 verifies NAT and connectivity to the **simulated ISP**, not access to the public Internet.
² Two-way connectivity was validated; LAB-06 was done in guided mode, so no formal final assessment was held.

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

Each lab folder holds the evidence for that lab: a write-up (`README.md`, or a handoff note for LAB-03), screenshots, and RouterOS `.rsc` exports. For example:

```text
LAB-04 Firewall Fundamental/
├── README.md        # Goal, configuration, tests, lessons learned
├── Topology.png     # GNS3 topology
├── *.png            # Screenshots of addressing, routing, firewall, and tests
├── Handoff.txt      # Notes carried into the next lab
└── LAB-04.rsc       # RouterOS configuration export
```

Start with LAB-01 to follow the labs in order, or open LAB-06 for the complete two-site setup.

## Scope

- **Simulated ISP:** the ISP router has no real upstream, so NAT and default-route tests prove connectivity to the simulated ISP only, not to the public Internet.
- **Dynamic WAN address:** HQ receives `.254` by DHCP. The Branch static route points to that address and must be updated if the lease changes.
- **Published files:** configurations are shared as `.rsc` exports. Binary `.backup` files and credentials are not included.

This is a simulation-based home lab. It is not a production deployment and does not claim coverage of the full MTCNA syllabus.

## Final Project

The topics from these labs are combined in the final project, published in its own repository: **[Small Office Multi-Site Network Deployment](https://github.com/DrBham/Small-Office-Multi-Site-Network-Deployment)**.
