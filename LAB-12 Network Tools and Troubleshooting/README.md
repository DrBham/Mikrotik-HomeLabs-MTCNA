# LAB-12 — Network Tools and Troubleshooting

**Status:** Planned — guide ready, not yet performed
**Platform:** GNS3, MikroTik CHR (RouterOS 7), VPCS, WinBox, Wireshark
**Skills:** Netwatch, Torch, traceroute, packet sniffer, logging, SNMP, graphing, structured break-fix diagnosis

## Goal

Learn the RouterOS tools that show what the network is doing, then use them to find faults injected on purpose. Builds on the LAB-06 topology (HQ, BRANCH, ISP, PC1, PC2).

## Topology change

None. Use the LAB-06 topology as it is. Take a backup on HQ and BRANCH first:

```routeros
/system backup save name=before-lab12
```

## Steps

### 1. Netwatch: alert when BRANCH goes down

On HQ:

```routeros
/tool netwatch add host=192.168.20.1 interval=10s type=simple comment="BRANCH LAN" \
    up-script=":log info \"NETWATCH: BRANCH 192.168.20.1 up\"" \
    down-script=":log warning \"NETWATCH: BRANCH 192.168.20.1 down\""
```

Test: on BRANCH run `/interface disable ether3`, wait 20 s, then `/interface enable ether3`.
Expected on HQ: `/tool netwatch print` shows `down` then `up`, and `/log print where message~"NETWATCH"` shows both entries.

### 2. Torch: see live traffic

On HQ, while PC1 runs `ping 192.168.20.100 -t`:

```routeros
/tool torch interface=ether3 src-address=0.0.0.0/0 dst-address=0.0.0.0/0 ip-protocol=any
```

Expected: a flow `192.168.10.100 → 192.168.20.100`, protocol `icmp`. Press `q` to stop.

### 3. Traceroute

```routeros
/tool traceroute 192.168.20.100
```

From PC1: `trace 192.168.20.100`.
Expected: two hops, `192.168.10.1` (PC1 only) then `192.168.100.253`, then the destination.

### 4. Packet sniffer: prove the LAB-06 NAT exemption

LAB-06 showed the NAT exemption counter rising but had no capture of the real source address. Capture it here.

```routeros
/tool sniffer set file-name=lab12.pcap filter-interface=ether3 filter-ip-protocol=icmp
/tool sniffer start
```

From PC1: `ping 192.168.20.100 -c 5`. Then:

```routeros
/tool sniffer stop
/file print where name~"lab12"
```

Download `lab12.pcap` from WinBox **Files** and open it in Wireshark.
Expected: ICMP Echo Request with source `192.168.10.100` (not `192.168.100.254`) toward `192.168.20.100`.

### 5. Logging to disk

```routeros
/system logging action add name=disklog target=disk disk-file-name=lab12-log disk-lines-per-file=1000
/system logging add topics=firewall action=disklog
/ip firewall filter set [find comment="Drop other new input"] log=yes log-prefix="DROP-IN"
```

Test: from ISP run `/ping 192.168.100.254 count=3` (ICMP from the WAN is not allowed on HQ input).
Expected: `/log print where message~"DROP-IN"` shows the dropped packets, and `lab12-log.0.txt` appears in `/file print`.

### 6. SNMP, read-only from management

```routeros
/snmp community set [find default=yes] addresses=192.168.56.0/24 read-access=yes write-access=no
/snmp set enabled=yes contact="<YOUR_NAME>" location="GNS3 HQ"
```

Optional test from the host (Net-SNMP installed): `snmpwalk -v2c -c public 192.168.56.108 1.3.6.1.2.1.1`.
Expected: system name `HQ`. Change `public` to your own community in a real network.

### 7. Interface graphing

```routeros
/tool graphing interface add interface=ether3 allow-address=192.168.56.0/24
```

The web view of graphs needs the `www` service, which LAB-06 hardening turns off. Open **Tools → Graphing** in WinBox instead.

## Break-fix

Inject the faults below **one at a time, in random order** (ask someone else to pick, or roll a die). Before each fault, restore with `/system backup load name=before-lab12` or undo the command.

| # | Fault | Inject (router) | Expected symptom |
|---|---|---|---|
| 1 | Wrong DHCP gateway option | HQ: `/ip dhcp-server network set [find address="192.168.10.0/24"] gateway=192.168.10.254` | PC1 renews (`ip dhcp`), pings `192.168.10.1` fine, cannot reach PC2 or ISP |
| 2 | Static route disabled | HQ: `/ip route disable [find dst-address="192.168.20.0/24"]` | PC1 → PC2 fails; HQ sends BRANCH traffic to the ISP |
| 3 | Allow rule below the drop | HQ: `/ip firewall filter move [find comment="Drop other new forward"] destination=[find comment="LAB06-Allow-Branch-to-HQ"]` (puts the drop above the allow rule) | PC1 → PC2 works, PC2 → PC1 times out |
| 4 | NAT exemption disabled | HQ: `/ip firewall nat disable [find comment="LAB06-No-NAT-HQ-to-Branch"]` | Ping still works, but the sniffer shows source `192.168.100.254` |
| 5 | DHCP pool too small | HQ: `/ip pool set [find name=LAN-POOL] ranges=192.168.10.10-192.168.10.10` then release PC1's lease | PC1 stays on `0.0.0.0` or keeps an old lease |
| 6 | DHCP client on the wrong port | HQ: `/ip dhcp-client set [find interface=ether3] interface=ether4` | HQ loses its WAN address and default route; BRANCH loses its next hop `.254` |

Record each fault in this format:

```text
Fault #:
Symptom   : what the user sees
Evidence  : commands run and what they showed
Cause     : the one setting that is wrong
Fix       : the command that restored it
Verify    : the test that now passes
```

## Evidence to capture

| File name | Shows |
|---|---|
| `Netwatch Log.png` | Netwatch down/up entries in `/log` |
| `Torch.png` | Torch flow on `ether3` |
| `Traceroute.png` | `/tool traceroute 192.168.20.100` |
| `Wireshark NAT Exemption.png` | Capture with source `192.168.10.100` |
| `Firewall Log.png` | `DROP-IN` log entries |
| `SNMP Walk.png` | Optional `snmpwalk` output |
| `Graphing.png` | WinBox interface graph for `ether3` |
| `Break-Fix Fault N.png` | One screenshot per fault (symptom or key evidence) |
| `LAB-12.rsc` | `/export file=LAB-12` on HQ |

## Done when

- [ ] Netwatch logs BRANCH down and up.
- [ ] Wireshark shows the original source `192.168.10.100` toward BRANCH.
- [ ] Firewall drops are logged to disk.
- [ ] All six faults diagnosed and written up with the template.
- [ ] README updated with results and status changed to Completed.
