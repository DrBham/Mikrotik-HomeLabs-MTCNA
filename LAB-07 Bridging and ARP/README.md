# LAB-07 — Bridging and ARP

**Status:** Planned — guide ready, not yet performed
**Platform:** GNS3, MikroTik CHR (RouterOS 7), VPCS, WinBox
**Skills:** bridge and bridge ports, MAC learning, Layer 2 vs Layer 3, ARP modes, static ARP

## Goal

Turn two HQ ports into one switched LAN with a **bridge**, then control which hosts may talk to the router with **ARP `reply-only`**. Builds on the LAB-06 topology (and the LAB-06 fixes, if applied).

## Topology change

Add **PC3** (VPCS) to HQ `ether4`. PC1 stays on `ether2`. Both ports join `bridge-lan`, which takes over the LAN address.

```text
              CHR-HQ-1
        bridge-lan 192.168.10.1/24
           /               \
       ether2             ether4
         |                   |
        PC1                 PC3
```

> [!WARNING]
> Separate VPCS nodes can report the same MAC address (`00:50:79:66:68:00` was seen on both PC1 and PC2 in LAB-06). Run `show ip` on PC1 and PC3. If the MACs match, replace PC3 with a CHR or a Linux node, or the bridge will flap.

## Steps

### 1. Create the bridge and move the LAN onto it

```routeros
/interface bridge add name=bridge-lan comment="HQ LAN"
/interface bridge port add bridge=bridge-lan interface=ether2
/interface bridge port add bridge=bridge-lan interface=ether4
/ip address set [find address="192.168.10.1/24"] interface=bridge-lan
/ip dhcp-server set [find name=DHCP-LAN] interface=bridge-lan
```

If the LAB-06 HQ fix is applied, its DNS rules name `ether2`. Move them to the bridge:

```routeros
/ip firewall filter set [find in-interface=ether2] in-interface=bridge-lan
```

### 2. Check MAC learning

```routeros
/interface bridge port print
/interface bridge host print
```

Expected: PC1's MAC on `ether2`, PC3's MAC on `ether4`.

### 3. Layer 2 vs Layer 3

From PC3: `ip dhcp`, then `ping` PC1 and `ping 192.168.10.1`.
PC3 → PC1 is switched inside the bridge. It does not pass the IP firewall `forward` chain, so the LAB-04 "drop new forward" rule does not block it. Write down why.

### 4. ARP `reply-only`

```routeros
/ip dhcp-server set [find name=DHCP-LAN] add-arp=yes
/interface bridge set bridge-lan arp=reply-only
/ip arp print
```

Expected: only hosts with a DHCP lease appear in the ARP table, as dynamic entries added by the DHCP server.

### 5. Prove the effect

1. On PC3 set a static address outside the pool: `ip 192.168.10.150/24 192.168.10.1`.
2. `ping 192.168.10.1` from PC3. Expected: timeout. The router does not learn PC3 through ARP any more.
3. Add a static entry, then ping again. Expected: replies.

```routeros
/ip arp add address=192.168.10.150 mac-address=<PC3_MAC> interface=bridge-lan comment="PC3 static"
```

4. Set PC3 back to DHCP (`ip dhcp`) and remove the static entry.

## Evidence to capture

| File name | Shows |
|---|---|
| `Topology.png` | GNS3 drawing with PC3 on `ether4` |
| `Bridge Ports.png` | `/interface bridge port print` |
| `Bridge Hosts.png` | `/interface bridge host print` |
| `ARP Table.png` | `/ip arp print` after `reply-only` |
| `PC3 Static Blocked.png` | PC3 ping timing out with a static IP |
| `PC3 Static ARP.png` | Replies after the static ARP entry |
| `LAB-07.rsc` | `/export file=LAB-07` |

## Done when

- [ ] PC1 and PC3 get leases from `DHCP-LAN` on `bridge-lan`.
- [ ] Bridge host table shows each PC on its own port.
- [ ] A static-IP host cannot reach the router until a static ARP entry exists.
- [ ] README updated with results and status changed to Completed.
