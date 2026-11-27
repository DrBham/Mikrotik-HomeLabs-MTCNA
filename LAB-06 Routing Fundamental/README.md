# LAB-06 — Routing Fundamental

**Status:** Completed · **Platform:** GNS3, MikroTik CHR (RouterOS 7.21.5), VPCS, WinBox
**Skills:** static routing, NAT exemption, two-site firewall policy, DNS forwarding, DHCP reservation, management hardening

## Overview

LAB-06 adds a second site. **CHR-BRANCH-1** joins the transit network `192.168.100.0/24` next to HQ, and both LANs reach each other through **static routes**. HQ keeps its firewall and NAT from earlier labs with two narrow additions. BRANCH gets the same security policy as HQ, both sites resolve names through DNS, and all three routers accept management only from the management network.

![LAB-06 GNS3 topology: ISP, HQ and BRANCH on one transit switch](<Topology.png>)

## Addressing

| Device | Interface | Address | Role |
|---|---|---|---|
| CHR-ISP-1 | `ether1` | `192.168.56.109/24` | Management |
| CHR-ISP-1 | `ether2` | `192.168.100.1/24` | Transit, DHCP server, DNS |
| CHR-HQ-1 | `ether1` | `192.168.56.108/24` | Management |
| CHR-HQ-1 | `ether2` | `192.168.10.1/24` | HQ LAN gateway |
| CHR-HQ-1 | `ether3` | `192.168.100.254/24` (reserved DHCP lease) | Transit |
| CHR-BRANCH-1 | `ether1` | `192.168.56.110/24` | Management |
| CHR-BRANCH-1 | `ether2` | `192.168.20.1/24` | BRANCH LAN gateway |
| CHR-BRANCH-1 | `ether3` | `192.168.100.253/24` (static) | Transit |
| PC1 | Ethernet | DHCP `192.168.10.100/24` | HQ client |
| PC2 | Ethernet | DHCP `192.168.20.100/24` | BRANCH client |

HQ and BRANCH share one Layer-2 segment through Switch1, so traffic between them does not pass through the ISP router.

## Configuration

Full configurations: [LAB-06-ISP.rsc](LAB-06-ISP.rsc), [LAB-06-HQ.rsc](LAB-06-HQ.rsc), [LAB-06-BRANCH.rsc](LAB-06-BRANCH.rsc).

### 1. Static routes between the sites

| Router | Destination | Next hop |
|---|---|---|
| HQ | `192.168.20.0/24` | `192.168.100.253` (BRANCH) |
| BRANCH | `192.168.10.0/24` | `192.168.100.254` (HQ) |
| BRANCH | `0.0.0.0/0` | `192.168.100.1` (ISP) |

A static route (`As`) names the remote LAN; the connected route `192.168.100.0/24` tells each router how to reach the next hop. The more specific `/24` route wins over the default route for traffic to the other site.

```routeros
# HQ
/ip route add dst-address=192.168.20.0/24 gateway=192.168.100.253
# BRANCH
/ip route add dst-address=192.168.10.0/24 gateway=192.168.100.254
/ip route add dst-address=0.0.0.0/0 gateway=192.168.100.1 comment="Default to ISP"

# Check on each router
/ip address print
/ip route print
```

| HQ addresses and routes | BRANCH routes |
|---|---|
| ![HQ IP addresses and routing table with static route to BRANCH](<HQ - IP Address & Routing Table.png>) | ![BRANCH routing table with default route and route to HQ](<BRANCH - Routing Table.png>) |

### 2. Stable transit addresses on the ISP

The BRANCH route points to HQ's DHCP address `.254`, and BRANCH uses the static `.253`. The original pool `.10`–`.254` covered both. The ISP now reserves `.254` for HQ as a static lease (`HQ WAN reserved`) and hands out only `.10`–`.200`. It also holds the DNS test record `isp.lab`.

On CHR-ISP-1:

```routeros
/ip dhcp-server lease make-static [find address=192.168.100.254]
/ip dhcp-server lease set [find address=192.168.100.254] comment="HQ WAN reserved"
/ip pool set [find name=ISP-POOL] ranges=192.168.100.10-192.168.100.200
/ip dns static add name=isp.lab address=192.168.100.1 comment="DNS test record"

# Check
/ip dhcp-server lease print
/ip pool print
/ip dns static print
```

![ISP lease reservation, shrunk pool and DNS record](<ISP - DHCP Lease Pool & DNS.png>)

### 3. HQ: allow BRANCH in, do not NAT traffic to BRANCH

The LAB-04 policy dropped every new forwarded connection except LAN → WAN, so PC1 could ping PC2 but PC2 could not ping PC1. Rule 5 (`LAB06-Allow-Branch-to-HQ`) sits above `Drop other new forward` and lets BRANCH in. Rules 9–10 accept DNS from the LAN (section 4). All key rules carry comments.

The LAB-03 masquerade rule matches everything leaving `ether3`, including traffic to BRANCH. The `srcnat accept` exemption `LAB06-No-NAT-HQ-to-Branch` above it keeps the original HQ source address; it counted 15 packets during testing.

On CHR-HQ-1. Rule numbers refer to the last `print`:

```routeros
/ip firewall filter
add chain=forward action=accept connection-state=new src-address=192.168.20.0/24 \
    dst-address=192.168.10.0/24 comment=LAB06-Allow-Branch-to-HQ place-before=5
print
set 3 comment="Accept established forward"
set 4 comment="LAN to WAN"
set 6 comment="Drop other new forward"
set 9 comment="Drop other new input"

/ip firewall nat add chain=srcnat action=accept src-address=192.168.10.0/24 \
    dst-address=192.168.20.0/24 comment=LAB06-No-NAT-HQ-to-Branch place-before=0

# Check
/ip firewall filter print
/ip firewall nat print stats
```

| HQ firewall filter | HQ NAT |
|---|---|
| ![HQ firewall filter with labelled rules](<HQ - Firewall Filter.png>) | ![HQ NAT exemption above masquerade with counters](<HQ - Firewall NAT.png>) |

### 4. DNS for LAN clients

DHCP tells clients to use their gateway as DNS server. Each router now accepts those queries (`allow-remote-requests=yes`) and forwards them to the ISP, which answers `isp.lab`. The firewall accepts DNS only on the LAN port `ether2`, so the resolver stays closed to the transit network. BRANCH also hands out `192.168.20.1` as DNS server through DHCP.

```routeros
# HQ
/ip dns set allow-remote-requests=yes
/ip firewall filter
add chain=input action=accept protocol=udp dst-port=53 in-interface=ether2 \
    comment="Allow LAN DNS (udp)" place-before=[find comment="Drop other new input"]
add chain=input action=accept protocol=tcp dst-port=53 in-interface=ether2 \
    comment="Allow LAN DNS (tcp)" place-before=[find comment="Drop other new input"]

# BRANCH
/ip dns set allow-remote-requests=yes servers=192.168.100.1
/ip dhcp-server network set [find address="192.168.20.0/24"] dns-server=192.168.20.1
```

```text
PC1 --query isp.lab--> HQ 192.168.10.1 --forward--> ISP 192.168.100.1 (record)
PC1 <--192.168.100.1-- HQ <------------answer------ ISP
```

### 5. BRANCH firewall and NAT

BRANCH started with no firewall, no NAT and no way out to the ISP. It now has the same stateful policy as HQ: replies pass, management only from `192.168.56.0/24`, LAN clients may use DHCP and DNS on the router, the BRANCH LAN may go out, HQ may reach the BRANCH LAN, and everything else is dropped. NAT exempts BRANCH → HQ traffic and masquerades the rest. The leftover DHCP client on `ether4` was removed and the DHCP server renamed from `dhcp1` to `DHCP-BRANCH`.

On CHR-BRANCH-1:

```routeros
/ip dhcp-client remove [find interface=ether4]
/ip dhcp-server set [find name=dhcp1] name=DHCP-BRANCH

/ip firewall nat
add chain=srcnat action=accept src-address=192.168.20.0/24 dst-address=192.168.10.0/24 comment="No NAT BRANCH to HQ"
add chain=srcnat action=masquerade out-interface=ether3 comment="Masquerade to ISP"

/ip firewall filter
add chain=input action=drop connection-state=invalid
add chain=input action=accept connection-state=established,related
add chain=input action=accept in-interface=ether1 src-address=192.168.56.0/24 comment="Management"
add chain=input action=accept protocol=icmp
add chain=input action=accept in-interface=ether2 protocol=udp dst-port=67 comment="LAN DHCP"
add chain=input action=accept in-interface=ether2 protocol=udp dst-port=53 comment="LAN DNS (udp)"
add chain=input action=accept in-interface=ether2 protocol=tcp dst-port=53 comment="LAN DNS (tcp)"
add chain=input action=drop comment="Drop other input"
add chain=forward action=drop connection-state=invalid
add chain=forward action=accept connection-state=established,related
add chain=forward action=accept connection-state=new src-address=192.168.20.0/24 out-interface=ether3 comment="BRANCH LAN out"
add chain=forward action=accept connection-state=new src-address=192.168.10.0/24 dst-address=192.168.20.0/24 comment="Allow HQ to BRANCH"
add chain=forward action=drop comment="Drop other forward"

# Check
/ip firewall filter print
/ip firewall nat print
```

| BRANCH firewall filter | BRANCH NAT |
|---|---|
| ![BRANCH firewall filter rules](<BRANCH - Firewall Filter.png>) | ![BRANCH NAT exemption and masquerade](<BRANCH - Firewall NAT.png>) |

### 6. Management hardening (all three routers)

| Change | Why |
|---|---|
| Disable Telnet, FTP, web, API | Unused services; Telnet and FTP send passwords in clear text |
| WinBox and SSH only from `192.168.56.0/24` | Only the management network can log in |
| Discovery and MAC access only on `ether1` (interface list `MGMT`) | Routers no longer announce themselves on LAN or transit links |
| Bandwidth test server off | Not needed outside traffic tests |

On each router:

```routeros
/interface list add name=MGMT
/interface list member add list=MGMT interface=ether1
/ip service disable [find name~"^(telnet|ftp|www|api|api-ssl)\$"]
/ip service set [find name~"^(winbox|ssh)\$"] address=192.168.56.0/24
/ip neighbor discovery-settings set discover-interface-list=MGMT
/tool mac-server set allowed-interface-list=MGMT
/tool mac-server mac-winbox set allowed-interface-list=MGMT
/tool bandwidth-server set enabled=no

# Check
/ip service print
```

| ISP | HQ | BRANCH |
|---|---|---|
| ![ISP service list](<ISP - IP Service.png>) | ![HQ service list](<HQ - IP Service.png>) | ![BRANCH service list](<BRANCH - IP Service.png>) |

> [!TIP]
> Make firewall and service changes in **Safe Mode** (`Ctrl+X` in the terminal). If the session drops, RouterOS rolls the changes back.

## Verification

| Test | Result |
|---|---|
| PC1 → PC2 (`ping 192.168.20.100`) | 10/10, then 5/5 after all changes |
| PC2 → PC1 (`ping 192.168.10.100`) | 10/10; after all changes 3/5 (first two lost while ARP resolved the path) |
| PC1 `ping isp.lab` | Resolved to `192.168.100.1`, 5/5 replies |
| PC2 DHCP and DNS | `192.168.20.100/24`, gateway and DNS `192.168.20.1` |
| PC2 `ping isp.lab` | Resolved, 5/5 replies through BRANCH NAT |
| `/ip service print` on all routers | Telnet, FTP, www, API disabled; WinBox and SSH limited to `192.168.56.0/24` |

```text
PC1> ip dhcp
PC1> ping isp.lab
PC1> ping 192.168.20.100 -c 5

PC2> ip dhcp
PC2> show ip
PC2> ping isp.lab
PC2> ping 192.168.10.100 -c 5
```

| PC1 DNS | PC2 DHCP, DNS and ping to PC1 |
|---|---|
| ![PC1 resolving isp.lab and pinging it](<PC1 - DNS isp.lab.png>) | ![PC2 lease with DNS, isp.lab and ping to PC1](<PC2 - DHCP DNS & Ping.png>) |
| **PC1 → PC2** | **First validation (10 packets)** |
| ![PC1 ping to PC2, 5 of 5 replies](<PC1 - Ping PC2.png>) | ![PC1 ping to PC2, 10 of 10 replies](<Ping PC1 to PC2.png>) |

<details>
<summary>More evidence: addresses, leases, backups, first validation</summary>

| BRANCH addresses and routes | ISP export and backup |
|---|---|
| ![BRANCH IP addresses and routing table](<BRANCH - IP Address & Routing Table.png>) | ![ISP export and backup](<ISP - Backup & Export.png>) |
| **BRANCH export and backup** | |
| ![BRANCH export and backup](<BRANCH - Backup & Export.png>) | |
| **HQ DHCP lease** | **BRANCH DHCP lease** |
| ![HQ lease for PC1](<HQ - DHCP Lease.png>) | ![BRANCH lease for PC2](<BRANCH - DHCP Lease.png>) |
| **PC2 → PC1 (10 packets)** | **Backups and exports** |
| ![PC2 ping to PC1, 10 of 10 replies](<Ping PC2 to PC1.png>) | ![HQ export and backup](<HQ - Backup & Export.png>) |

</details>

## Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| HQ → BRANCH LAN: `net unreachable` from the ISP | HQ only had connected and default routes, so it sent the packet to the ISP | Static route on HQ to `192.168.20.0/24` |
| BRANCH → HQ LAN: `no route to host` | BRANCH had no route to `192.168.10.0/24` | Static route on BRANCH |
| PC1 → PC2 works, PC2 → PC1 times out | HQ `forward` dropped new connections from BRANCH | Accept rule above the drop |
| HQ → BRANCH traffic masqueraded | Masquerade matched all traffic out of `ether3` | `srcnat accept` exemption above it |
| PC1 gets DNS `192.168.10.1` but cannot resolve names | HQ had `allow-remote-requests=no`, and the input chain dropped new DNS queries | Enable remote requests; accept UDP/TCP 53 from `ether2` |
| Adding a rule above the drop rule by searching for `connection-state=new` returns `no such item` | RouterOS `find` does not match `connection-state` values | Label rules with comments and search by comment |
| Both PCs show `0.0.0.0` after reopening the lab | VPCS had no active lease | `ip dhcp` on each PC |

## Lessons learned

- Each router needs a route to every remote network; return traffic needs its own route.
- `input` and `forward` answer different questions: "may I talk to the router?" versus "may I pass through it?"
- A broad NAT rule can catch traffic that should be routed. Exempt it explicitly.
- A static route to a DHCP-assigned next hop needs a reserved lease.
- Handing out a DNS server through DHCP is not enough; the router must accept and forward the queries.
- Comments make firewall rules readable and scriptable.

## Files

| File | Content |
|---|---|
| [LAB-06-ISP.rsc](LAB-06-ISP.rsc) | CHR-ISP-1 export |
| [LAB-06-HQ.rsc](LAB-06-HQ.rsc) | CHR-HQ-1 export |
| [LAB-06-BRANCH.rsc](LAB-06-BRANCH.rsc) | CHR-BRANCH-1 export |
| `*.png` | Topology, configuration, service, backup and test screenshots |

Previous: [LAB-05](../LAB-05%20DHCP%20Server%20%26%20LAN%20Client%20Management/) · Next: [LAB-07 — Bridging and ARP](../LAB-07%20Bridging%20and%20ARP/) · Final project: [Small Office Multi-Site Network Deployment](https://github.com/DrBham/Small-Office-Multi-Site-Network-Deployment)
