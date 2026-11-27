# LAB-10 — Advanced Firewall and Port Forwarding

**Status:** Planned — guide ready, not yet performed
**Platform:** GNS3, MikroTik CHR (RouterOS 7), VPCS, WinBox
**Skills:** address lists, dynamic blocking, dst-nat port forwarding, firewall logging, FastTrack

## Goal

Extend the LAB-04 HQ firewall with **address lists**, publish one internal service with **dst-nat**, **log** dropped traffic, and measure what **FastTrack** does to throughput and to the LAB-09 queues. Builds on the LAB-06 topology plus `CLIENT-CHR` on the HQ LAN from LAB-09.

## Topology change

None. `CLIENT-CHR` (from LAB-09) sits on the HQ LAN and becomes the port-forward target.

```text
CHR-ISP-1 192.168.100.1
      |  tcp 2222
CHR-HQ-1 ether3 192.168.100.254  --dst-nat-->  CLIENT-CHR <CLIENT_IP>:22
      |
   HQ LAN 192.168.10.0/24 (PC1, CLIENT-CHR)
```

> [!WARNING]
> Turn on WinBox **Safe Mode** before editing input rules. Step 1 changes the rule that keeps your management session alive.

## Steps

### 1. Management address list

```routeros
/ip firewall address-list add list=MGMT-HOSTS address=192.168.56.0/24 comment="Management network"
/ip firewall filter set [find chain=input src-address=192.168.56.0/24] \
    !src-address src-address-list=MGMT-HOSTS comment="Management"
/ip firewall filter print where chain=input
```

Expected: the management rule now shows `src-address-list=MGMT-HOSTS`, and WinBox stays connected. To add another admin host later, edit the list, not the rule.

### 2. Block one LAN host for 10 minutes

```routeros
/ip firewall filter add chain=forward action=drop src-address-list=BLOCKED \
    comment="Drop blocked hosts" \
    place-before=[find chain=forward action=accept connection-state=new out-interface=ether3]
/ip firewall address-list add list=BLOCKED address=192.168.10.100 timeout=10m comment="PC1 test"
```

Tests from PC1:

| Test | Expected |
|---|---|
| `ping 192.168.100.1` | Timeout: forwarded traffic hits the BLOCKED drop |
| `ping 192.168.10.1` | Replies: `input` chain, not affected by the forward rule |

```routeros
/ip firewall address-list print where list=BLOCKED
```

Expected: the entry shows a counting-down `timeout`. After it expires (or after `remove`), PC1 reaches the ISP again.

### 3. Port forward SSH to CLIENT-CHR

Pin the client address first, so the forward target never moves:

```routeros
/ip dhcp-server lease make-static [find address=<CLIENT_IP>]
/ip dhcp-server lease set [find address=<CLIENT_IP>] comment="CLIENT-CHR reserved"
```

Then the NAT rule and the matching forward accept:

```routeros
/ip firewall nat add chain=dstnat action=dst-nat in-interface=ether3 protocol=tcp \
    dst-port=2222 to-addresses=<CLIENT_IP> to-ports=22 comment="SSH to CLIENT-CHR"
/ip firewall filter add chain=forward action=accept connection-state=new \
    connection-nat-state=dstnat in-interface=ether3 comment="Allow port forwards" \
    place-before=[find chain=forward action=drop connection-state=new]
```

Test from CHR-ISP-1:

```routeros
/system ssh address=192.168.100.254 port=2222 user=admin
```

Expected: the login prompt of `CLIENT-CHR` (check the identity in the prompt), not HQ. `/ip firewall nat print stats` shows the dst-nat counter rising.

### 4. Log dropped input

```routeros
/ip firewall filter set [find chain=input action=drop connection-state=new] \
    log=yes log-prefix="DROP-IN"
```

Trigger from CHR-ISP-1: `/ping 192.168.100.254 count=3`. HQ only accepts ICMP from the LAN, so these packets are dropped.

```routeros
/log print where message~"DROP-IN"
```

Expected: three entries with `in:ether3`, source `192.168.100.1`, protocol ICMP.

### 5. FastTrack

```routeros
/ip firewall filter add chain=forward action=fasttrack-connection \
    connection-state=established,related comment="FastTrack" \
    place-before=[find chain=forward action=accept connection-state=established,related]
```

Repeat the LAB-09 bandwidth test from `CLIENT-CHR` to the ISP, then check:

```routeros
/ip firewall filter print stats where action=fasttrack-connection
/queue simple print stats
```

Expected: the FastTrack counter rises, and the LAB-09 simple queue no longer holds the client to its `max-limit`. FastTracked packets skip queues, mangle, and most of the firewall.

Decide and write down whether to keep FastTrack: speed for all traffic, or queues that work. One option is to exclude the queued subnet with `src-address=!192.168.10.0/24` on the FastTrack rule.

## Evidence to capture

| File name | Shows |
|---|---|
| `Address Lists.png` | `/ip firewall address-list print` with MGMT-HOSTS and BLOCKED |
| `PC1 Blocked.png` | PC1 ping to ISP timing out, ping to gateway working |
| `NAT Port Forward.png` | `/ip firewall nat print stats` with the dst-nat counter |
| `SSH Via Port Forward.png` | SSH from ISP landing on CLIENT-CHR |
| `Firewall Log.png` | `/log print where message~"DROP-IN"` |
| `FastTrack Counter.png` | FastTrack rule counter |
| `Queue With FastTrack.png` | Queue stats before and after FastTrack |
| `LAB-10.rsc` | `/export file=LAB-10` |

## Done when

- [ ] Management access is controlled by the `MGMT-HOSTS` list.
- [ ] A host in `BLOCKED` loses WAN access and gets it back after the timeout.
- [ ] SSH from the ISP to HQ `:2222` reaches CLIENT-CHR.
- [ ] Dropped input from the WAN appears in the log with the `DROP-IN` prefix.
- [ ] FastTrack effect on queues is measured and the keep/remove decision is written down.
- [ ] README updated with results and status changed to Completed.
