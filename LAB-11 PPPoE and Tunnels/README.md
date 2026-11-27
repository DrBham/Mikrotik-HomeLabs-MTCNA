# LAB-11 — PPPoE and Tunnels

**Status:** Planned — guide ready, not yet performed
**Platform:** GNS3, MikroTik CHR (RouterOS 7), VPCS, WinBox
**Skills:** PPPoE server and client, PPP profiles and secrets, L2TP/IPsec site-to-site, route distance, failover

## Goal

**Part A:** make the ISP hand out the HQ uplink over **PPPoE**, like a real broadband line. **Part B:** connect HQ and BRANCH with an **L2TP/IPsec** tunnel and prefer it over the LAB-06 static routes, keeping those routes as a backup. Builds on the LAB-06 topology plus `CLIENT-CHR` on the HQ LAN from LAB-09.

## Topology change

No new nodes. New logical links run over the existing transit segment:

```text
CHR-ISP-1  PPPoE server on ether2, 10.10.10.1
     |  PPPoE session (pppoe-out1)
CHR-HQ-1   pppoe-out1 10.10.10.x   ether3 192.168.100.254 (kept for BRANCH)
     |  L2TP/IPsec  172.16.0.1 <-> 172.16.0.2
CHR-BRANCH-1   ether3 192.168.100.253
```

> [!WARNING]
> Turn on WinBox **Safe Mode** before each part. Part A moves HQ's default route; Part B changes the routes between the sites.

## Part A — PPPoE

### 1. PPPoE server on CHR-ISP-1

```routeros
/ip pool add name=PPPOE-POOL ranges=10.10.10.10-10.10.10.20
/ppp profile add name=PPPOE-PROFILE local-address=10.10.10.1 \
    remote-address=PPPOE-POOL dns-server=192.168.100.1
/ppp secret add name=hq-pppoe password=<PPPOE_PASSWORD> service=pppoe profile=PPPOE-PROFILE
/interface pppoe-server server add service-name=ISP-PPPOE interface=ether2 \
    default-profile=PPPOE-PROFILE one-session-per-host=yes disabled=no
```

### 2. PPPoE client on CHR-HQ-1

Keep the ether3 DHCP address (BRANCH routes to `.254`) but stop it from installing a default route:

```routeros
/ip dhcp-client set [find interface=ether3] add-default-route=no
/interface pppoe-client add name=pppoe-out1 interface=ether3 user=hq-pppoe \
    password=<PPPOE_PASSWORD> add-default-route=yes use-peer-dns=yes disabled=no
```

### 3. NAT and firewall for the new uplink

```routeros
/ip firewall nat add chain=srcnat action=masquerade out-interface=pppoe-out1 \
    comment="Masquerade PPPoE"
/ip firewall filter add chain=forward action=accept connection-state=new \
    src-address=192.168.10.0/24 out-interface=pppoe-out1 comment="LAN to PPPoE" \
    place-before=[find chain=forward action=drop connection-state=new]
```

### 4. Verify Part A

```routeros
# CHR-ISP-1
/ppp active print
# CHR-HQ-1
/interface pppoe-client monitor pppoe-out1 once
/ip route print where dst-address=0.0.0.0/0
```

| Check | Expected |
|---|---|
| `/ppp active print` on ISP | One session, user `hq-pppoe`, address from `10.10.10.10-20` |
| PPPoE client monitor | `status: connected`, MTU `1480` |
| HQ default route | Gateway `pppoe-out1`; no DHCP default route on ether3 |
| PC1 `ping 10.10.10.1` | Replies; NAT counter of "Masquerade PPPoE" rises |
| PC1 → PC2 | Still works through ether3 (LAB-06 routes untouched) |

MTU is 1480, not 1500, because PPPoE adds an 8-byte header to every frame.

## Part B — L2TP/IPsec between HQ and BRANCH

### 5. L2TP server on CHR-HQ-1

```routeros
/ppp profile add name=L2TP-SITE local-address=172.16.0.1 remote-address=172.16.0.2
/ppp secret add name=branch password=<L2TP_PASSWORD> service=l2tp profile=L2TP-SITE
/interface l2tp-server server set enabled=yes default-profile=L2TP-SITE \
    use-ipsec=required ipsec-secret=<IPSEC_PSK>
/ip firewall filter add chain=input action=accept protocol=udp dst-port=500,1701,4500 \
    src-address=192.168.100.253 comment="L2TP/IPsec from BRANCH" \
    place-before=[find chain=input action=drop connection-state=new]
/ip firewall filter add chain=input action=accept protocol=ipsec-esp \
    src-address=192.168.100.253 comment="ESP from BRANCH" \
    place-before=[find chain=input action=drop connection-state=new]
```

### 6. L2TP client on CHR-BRANCH-1

```routeros
/interface l2tp-client add name=l2tp-hq connect-to=192.168.100.254 user=branch \
    password=<L2TP_PASSWORD> use-ipsec=yes ipsec-secret=<IPSEC_PSK> disabled=no
```

### 7. Prefer the tunnel, keep the static routes as backup

```routeros
# CHR-HQ-1
/ip route set [find dst-address=192.168.20.0/24 gateway=192.168.100.253] distance=10
/ip route add dst-address=192.168.20.0/24 gateway=172.16.0.2 distance=1 comment="BRANCH via L2TP"
# CHR-BRANCH-1
/ip route set [find dst-address=192.168.10.0/24 gateway=192.168.100.254] distance=10
/ip route add dst-address=192.168.10.0/24 gateway=172.16.0.1 distance=1 comment="HQ via L2TP"
```

### 8. Verify Part B

| Check | Expected |
|---|---|
| `/ip ipsec active-peers print` on HQ | One peer, `192.168.100.253`, state `established` |
| `/ip route print where dst-address=192.168.20.0/24` on HQ | Route via `172.16.0.2` active (`As`); distance-10 route inactive |
| PC1 `trace 192.168.20.100` | Second hop is `172.16.0.2` (tunnel), not `192.168.100.253` |
| PC1 ↔ PC2 ping | Still 10/10 both ways |

### 9. Failover test

```routeros
# CHR-BRANCH-1
/interface l2tp-client disable l2tp-hq
```

Expected: the tunnel routes go inactive, the distance-10 routes become active, and PC1 `trace 192.168.20.100` shows `192.168.100.253` as the second hop. Ping keeps working after a short gap. Enable the client again and confirm the tunnel path returns.

## Evidence to capture

| File name | Shows |
|---|---|
| `PPP Active ISP.png` | `/ppp active print` on the ISP |
| `PPPoE Client HQ.png` | `pppoe-client monitor` with status and MTU |
| `HQ Default Route PPPoE.png` | Default route via `pppoe-out1` |
| `IPsec Active Peers.png` | `/ip ipsec active-peers print` on HQ |
| `Routes With Distance.png` | Tunnel route active, static route as backup |
| `Trace Via Tunnel.png` | PC1 `trace` through `172.16.0.2` |
| `Trace Failover.png` | PC1 `trace` after the tunnel is disabled |
| `LAB-11-ISP.rsc`, `LAB-11-HQ.rsc`, `LAB-11-BRANCH.rsc` | `/export file=...` on each router |

Before publishing the exports, check that no PPP or IPsec secret appears in plain text. `/export` hides passwords unless `show-sensitive` is used.

## Done when

- [ ] HQ gets its default route from a PPPoE session on the ISP, and the LAN reaches `10.10.10.1`.
- [ ] HQ and BRANCH build an L2TP tunnel protected by IPsec.
- [ ] HQ–BRANCH traffic uses the tunnel and falls back to the static routes when it is down.
- [ ] README updated with results and status changed to Completed.
