# LAB-06 — Routing Fundamentals (MikroTik RouterOS)

> **Project:** MikroTik Junior Journey To Master MikroTik  
> **Status:** ✅ Technical PASS — two-way inter-LAN ping validated  
> **Lab mode:** Guided Mode (assessment exception for LAB-06)  
> **Platform:** GNS3, MikroTik CHR / RouterOS v7, Winbox, VPCS

## 1. Objective

This lab extends the existing LAB-01–LAB-05 environment by adding a **BRANCH router** and a second LAN. The primary objective is to establish bidirectional connectivity between **HQ LAN (`192.168.10.0/24`)** and **BRANCH LAN (`192.168.20.0/24`)** using **static routing**, while preserving the DHCP, firewall, and NAT configurations from earlier labs.

By the end of this lab, the topology demonstrates:

- Connected routes learned automatically from interface addresses.
- Static routes to remote LAN subnets using transit-network next hops.
- The difference between traffic destined *to* a router (`input`) and traffic *forwarded through* a router (`forward`).
- Why a restrictive firewall can permit one direction of a new connection but deny the reverse direction.
- Why LAN-to-LAN traffic should be exempted from WAN masquerade when the goal is routed connectivity with original source addresses.
- Evidence-based troubleshooting using route tables, ping results, filter rules, NAT rules and counters.

## 2. Topology

```text
                      CHR-ISP-1
                ether2: 192.168.100.1/24
                           |
                        Switch1
                      /         \
                     /           \
          CHR-BRANCH-1         CHR-HQ-1
          ether3: .253         ether3: .254*  (192.168.100.0/24 transit)
          ether2: .20.1        ether2: .10.1
                 |                   |
                PC2                 PC1
         192.168.20.100       192.168.10.100
         GW: 192.168.20.1     GW: 192.168.10.1
```

`*` HQ `ether3` uses **DHCP Client**, and `.254` is the address observed during validation. Confirm the current lease before relying on the static route pointing to it. BRANCH `ether3` is static.

**Important:** HQ and BRANCH share the Layer-2 transit segment through Switch1, so traffic between them **does not have to traverse the ISP router**. The ISP router is another node on `192.168.100.0/24` and, in this lab environment, does not provide real Internet upstream access.

### Addressing plan

| Device | Interface | Address / network | Role |
|---|---|---|---|
| CHR-ISP-1 | ether2 | `192.168.100.1/24` | Transit gateway / DHCP server for upstream segment |
| CHR-HQ-1 | ether1 | `192.168.56.108/24` | Management |
| CHR-HQ-1 | ether2 | `192.168.10.1/24` | HQ LAN gateway |
| CHR-HQ-1 | ether3 | DHCP client; observed `192.168.100.254/24` | Transit |
| CHR-BRANCH-1 | ether1 | `192.168.56.110/24` | Management |
| CHR-BRANCH-1 | ether2 | `192.168.20.1/24` | BRANCH LAN gateway |
| CHR-BRANCH-1 | ether3 | `192.168.100.253/24` | Transit, static |
| PC1 | VPCS | DHCP; observed `192.168.10.100/24` | HQ client |
| PC2 | VPCS | DHCP; observed `192.168.20.100/24` | BRANCH client |

Management IP addresses are local lab details; adjust if rebuilding in another environment.

## 3. Implementation

### 3.1. Branch interface addressing

On BRANCH, configure these addresses in **Winbox → IP → Addresses**:

```routeros
/ip address add address=192.168.20.1/24 interface=ether2 comment="BRANCH LAN"
/ip address add address=192.168.100.253/24 interface=ether3 comment="Transit to HQ/ISP"
```

These are reference commands for reproducing the setup; **do not rerun on an existing router without checking for duplicates**.

RouterOS automatically adds connected routes (`DAc`) for `192.168.20.0/24` via `ether2`, `192.168.100.0/24` via `ether3`, and the management subnet via `ether1`.

### 3.2. BRANCH DHCP Server

The BRANCH DHCP server is bound to `ether2`:

| Parameter | Value |
|---|---|
| LAN network | `192.168.20.0/24` |
| Gateway | `192.168.20.1` |
| Pool name | `BRANCH-POOL` |
| Pool range | `192.168.20.10–192.168.20.100` |
| Lease time | `30m` |

**Troubleshooting note:** DHCP Setup initially created an automatically named pool (`dhcp_pool1`). The DHCP server was updated to use the intended `BRANCH-POOL`. PC2 subsequently obtained a bound lease for `192.168.20.100/24` and successfully pinged `192.168.20.1`.

### 3.3. Static routing

| Router | Destination | Gateway / next hop |
|---|---|---|
| HQ | `192.168.20.0/24` | `192.168.100.253` (BRANCH transit IP) |
| BRANCH | `192.168.10.0/24` | `192.168.100.254` (HQ transit IP observed in the lab) |

Reference CLI commands (**only add if absent**):

**HQ**
```routeros
/ip route add dst-address=192.168.20.0/24 gateway=192.168.100.253 comment="LAB06 to BRANCH LAN"
```

**BRANCH**
```routeros
/ip route add dst-address=192.168.10.0/24 gateway=192.168.100.254 comment="LAB06 to HQ LAN"
```

Both routes were verified in `/ip route print` with `As` flags (**Active Static**).

**Packet-flow concept:** PC2 → BRANCH → Switch1 → HQ → PC1. The route to `192.168.10.0/24` identifies the remote destination network; the connected route `192.168.100.0/24` provides the path to the next-hop IP `192.168.100.254`. Switch1 forwards frames at Layer 2; it does not choose IP routes.

### 3.4. Firewall FORWARD adjustment on HQ

LAB-04 had a restrictive HQ FORWARD policy: accept established/related, permit new traffic originating from HQ LAN out `ether3`, and drop other new traffic. Consequently, PC1 → PC2 worked while PC2-initiated ping → PC1 initially timed out.

A specific accept rule was added on HQ **above the general `forward` drop for new connections**:

```routeros
/ip firewall filter add chain=forward action=accept connection-state=new \
    src-address=192.168.20.0/24 dst-address=192.168.10.0/24 \
    comment="LAB06-Allow-Branch-to-HQ"
```

**Placement matters:** In a rebuilt configuration, ensure the rule is placed before the restrictive final `forward drop`. The command above alone appends the rule; use Winbox to move it to the correct position if necessary. Do not disable the baseline firewall wholesale.

A separate timeout when pinging an **HQ router interface** from BRANCH relates to the HQ `input` chain, not necessarily the PC-to-PC `forward` chain. That router-input behavior was not a required success criterion for this lab.

### 3.5. NAT exemption on HQ

From LAB-03, HQ has a broad rule:

```routeros
chain=srcnat action=masquerade out-interface=ether3
```

Because `ether3` is also used to reach BRANCH, this would potentially masquerade traffic headed for the BRANCH LAN. A specific `srcnat accept` exemption was added **above** the masquerade rule:

```routeros
/ip firewall nat add chain=srcnat action=accept \
    src-address=192.168.10.0/24 dst-address=192.168.20.0/24 \
    comment="LAB06-No-NAT-HQ-to-Branch"
```

This allows matching HQ-to-BRANCH traffic to bypass the subsequent source-NAT rule. The exemption counter showed **15 packets / 1,260 bytes** during the captured validation, while the older masquerade rule remained enabled. This is evidence that the exemption was being matched; the screenshot of connection tracking did **not** capture a relevant ICMP flow to independently demonstrate the original source address on each packet.

## 4. Validation and evidence

| Test | Recorded result |
|---|---|
| PC1 DHCP | `192.168.10.100/24`, GW `192.168.10.1` |
| PC2 DHCP | `192.168.20.100/24`, GW `192.168.20.1` |
| PC1 → HQ gateway | Successful ping |
| PC2 → BRANCH gateway | Successful ping |
| HQ → BRANCH transit `192.168.100.253` | Successful ping |
| HQ → BRANCH LAN interface `192.168.20.1` | 4/4 replies |
| Static routes HQ and BRANCH | `As` / active |
| PC1 → PC2 (`ping 192.168.20.100 -c 10`) | **10/10 replies** |
| PC2 → PC1 (`ping 192.168.10.100 -c 10`) | **10/10 replies** |
| NAT exemption | 15 matched packets observed |

Some **earlier** tests had intermittent timeouts. The final 10-packet tests captured in the lab succeeded in both directions; this demonstrates the state at validation time, not a guarantee of zero loss under every condition.

### Screenshots

Place your captured screenshots in the `screenshots/` folder with the names below. The links work after you add the files using these names:

| Evidence | File |
|---|---|
| GNS3 topology | `screenshots/01-topology.png` |
| HQ IP addresses | `screenshots/02-hq-ip-address.png` |
| HQ routing table | `screenshots/03-hq-routing-table.png` |
| BRANCH IP addresses | `screenshots/04-branch-ip-address.png` |
| BRANCH routing table | `screenshots/05-branch-routing-table.png` |
| HQ DHCP leases | `screenshots/06-hq-dhcp-lease.png` |
| BRANCH DHCP leases | `screenshots/07-branch-dhcp-lease.png` |
| HQ FORWARD rules | `screenshots/08-hq-firewall-forward.png` |
| HQ NAT exemption | `screenshots/09-hq-nat-exemption.png` |
| PC1 → PC2, 10 replies | `screenshots/10-pc1-to-pc2-ping.png` |
| PC2 → PC1, 10 replies | `screenshots/11-pc2-to-pc1-ping.png` |

Example embed (after adding the image):

```markdown
![LAB-06 GNS3 topology](screenshots/01-topology.png)
```

## 5. Troubleshooting summary

| Symptom | Evidence | Resolution / interpretation |
|---|---|---|
| HQ → BRANCH LAN returned `net unreachable` from ISP | HQ had only connected and default routes | Add explicit static route toward BRANCH instead of sending it to ISP |
| BRANCH → HQ LAN returned `no route to host` | BRANCH lacked route to `192.168.10.0/24` | Add BRANCH static route via HQ transit IP |
| BRANCH → HQ router interface timed out | HQ `input` policy restrictive | Not equivalent to forwarding failure; investigate `input` separately if needed |
| Both PCs showed `0.0.0.0` after returning to the lab | VPCS had no active DHCP lease | Run `ip dhcp`; both received valid addresses again |
| PC1 could ping PC2, but PC2-initiated ping failed | HQ FORWARD allowed new HQ→transit traffic and dropped other new connections | Add specific BRANCH→HQ LAN FORWARD exception before the drop |
| HQ traffic toward BRANCH matched broad masquerade design | NAT on all traffic leaving HQ `ether3` | Add specific HQ→BRANCH LAN `srcnat accept` exemption above masquerade |
| Intermittent timeouts appeared during earlier tests | Partial ICMP replies in screenshots | Re-test after changes; final test succeeded 10/10 in each direction. Root cause for earlier intermittent loss not conclusively isolated |

## 6. Important commands

**RouterOS (on the appropriate router):**
```routeros
/ip address print
/ip route print
/ip dhcp-server lease print
/ip firewall filter print detail
/ip firewall nat print detail stats
```

**VPCS:**
```text
ip dhcp
show ip
ping 192.168.20.100 -c 10   # from PC1
ping 192.168.10.100 -c 10   # from PC2
```

## 7. Outcome and project continuation

**LAB-06 Technical Objective: PASS.** Two different LANs were connected by static routing across HQ and BRANCH, while keeping the baseline firewall and NAT architecture intact with narrowly scoped adjustments.

**Administrative closeout:** screenshots were captured. RouterOS binary backups and sanitized exports should be created and verified before considering documentation/backup fully complete. Avoid publishing raw `.backup` files, credentials or private details to public GitHub.

**Project continuation (updated 25 October 2026):** LAB07 Network Troubleshooting was discontinued before completion, and LAB08 Backup/Restore was cancelled. The next activity is the **Final Project — Small Office Network Integration**, using a separately saved copy of the validated HQ–BRANCH topology. This does not make LAB07 or LAB08 completed labs.

---

## Catatan Audit dan Kesinambungan (Oktober 2026)

> **Catatan kesinambungan project (25 Oktober 2026):** Roadmap yang benar-benar dijalankan adalah LAB01 RouterOS Foundation, LAB02 WAN/DHCP Client, LAB03 NAT, LAB04 Firewall, LAB05 DHCP Server LAN, dan LAB06 Static Routing HQ–BRANCH. LAB07 Network Troubleshooting **dihentikan sebelum selesai** dan LAB08 Backup/Restore **dibatalkan** atas keputusan pemilik project. Tahap berikutnya adalah **Final Project — Small Office Network Integration**. Perubahan ini tidak mengubah hasil historis lab ini.

### Batas hasil dan kesinambungan

- **Technical PASS** adalah status konektivitas yang tervalidasi pada LAB06; **assessment akhir formal tidak dilaksanakan** karena pengecualian Guided Mode. Jangan membuat nilai assessment LAB06.
- **Backup dan export HQ/BRANCH belum terkonfirmasi** oleh hasil `/file print` yang tersedia pada handoff. Status administratif tetap perlu diverifikasi jika file hendak dipakai untuk restore.
- Ping PC1 ↔ PC2 berhasil **10/10 untuk sampel pengujian akhir**, bukan bukti konektivitas selalu bebas packet loss.
- Counter NAT exemption **15 paket / 1.260 byte** membuktikan rule cocok dengan traffic; capture yang menunjukkan source asli untuk aliran ICMP spesifik belum tersedia.
- IP transit HQ dari DHCP `192.168.100.254` harus diperiksa ulang sesudah restart/restore sebelum mengandalkan gateway static route BRANCH.
