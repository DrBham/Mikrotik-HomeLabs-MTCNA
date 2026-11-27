# LAB-13 — Wireless with hAP lite

**Status:** Planned — guide ready, not yet performed
**Platform:** MikroTik hAP lite (RB941-2nD), RouterOS 7, legacy `wireless` package, WinBox, one phone or laptop as client
**Skills:** AP mode, SSID and channel, WPA2-PSK security profile, registration table, access list, scan and frequency monitor, station mode

## Goal

Run a real 2.4 GHz access point and read client signal data, then turn the same radio into a **station** that uses another Wi-Fi network as its WAN. Only one MikroTik radio is needed.

## Topology change

Real hardware, not GNS3. Connect the laptop to hAP lite `ether2` and manage it with WinBox.

```text
Part A (AP)                        Part B (station)
phone/laptop ))) wlan1             home Wi-Fi AP ))) wlan1 (DHCP client, NAT)
                   |                                   |
             bridge-lan                         bridge-lan ether2-ether4
   ether2-ether4 + wlan1, 192.168.88.1/24          192.168.88.1/24
                   |                                   |
                laptop                              laptop
```

## Steps

### 0. Back up, then start from a blank configuration

> [!WARNING]
> `reset-configuration` erases every setting on the hAP lite, including any Wi-Fi and password you use today. Save a backup and an export first and copy both to your laptop from WinBox **Files**.

```routeros
/system backup save name=before-lab13
/export file=before-lab13
/system reset-configuration no-defaults=yes skip-backup=yes
```

After the reboot, reconnect with WinBox by MAC address (Neighbors tab) and set an admin password.

### Part A — Access point

#### 1. Bridge, address, and DHCP

```routeros
/interface bridge add name=bridge-lan
/interface bridge port add bridge=bridge-lan interface=ether2
/interface bridge port add bridge=bridge-lan interface=ether3
/interface bridge port add bridge=bridge-lan interface=ether4
/interface bridge port add bridge=bridge-lan interface=wlan1
/ip address add address=192.168.88.1/24 interface=bridge-lan
/ip pool add name=LAN-POOL ranges=192.168.88.10-192.168.88.100
/ip dhcp-server add name=DHCP-LAN interface=bridge-lan address-pool=LAN-POOL
/ip dhcp-server network add address=192.168.88.0/24 gateway=192.168.88.1 dns-server=192.168.88.1
```

#### 2. Security profile and AP

```routeros
/interface wireless security-profiles add name=LAB-WPA2 mode=dynamic-keys \
    authentication-types=wpa2-psk wpa2-pre-shared-key=<WIFI_PSK>
/interface wireless set wlan1 mode=ap-bridge ssid=MTCNA-LAB band=2ghz-b/g/n \
    channel-width=20mhz frequency=2437 country=indonesia \
    security-profile=LAB-WPA2 disabled=no
```

Expected: the phone sees `MTCNA-LAB`, joins with `<WIFI_PSK>`, and gets an address from `192.168.88.10–100`.

#### 3. Registration table

```routeros
/interface wireless registration-table print stats
```

Record signal strength, tx/rx rate, and CCQ at three distances (next to the router, one room away, two rooms away).

#### 4. Access list

```routeros
/interface wireless access-list add interface=wlan1 mac-address=<CLIENT_MAC> authentication=yes comment="Allowed client"
/interface wireless set wlan1 default-authentication=no
```

Expected: the listed client connects; any other device is refused. Use a second phone to prove it.

#### 5. Choose a channel

These tools stop the AP for a moment and disconnect clients.

```routeros
/interface wireless scan wlan1
/interface wireless frequency-monitor wlan1
```

Pick the least used of 2412, 2437, and 2462 MHz (channels 1, 6, 11), set it with `/interface wireless set wlan1 frequency=<FREQ>`, and record why.

### Part B — Station (Wi-Fi as WAN)

A plain `station` cannot be bridged to the LAN, so this part routes and NATs instead.

```routeros
/interface bridge port remove [find interface=wlan1]
/interface wireless security-profiles add name=HOME mode=dynamic-keys \
    authentication-types=wpa2-psk wpa2-pre-shared-key=<HOME_PSK>
/interface wireless set wlan1 mode=station ssid=<HOME_SSID> security-profile=HOME
/ip dhcp-client add interface=wlan1
/ip firewall nat add chain=srcnat action=masquerade out-interface=wlan1
/ip dns set allow-remote-requests=yes
```

Expected: `/interface wireless registration-table print` shows the home AP, `/ip dhcp-client print` shows `bound`, and the laptop on `ether2` reaches the Internet.

> [!NOTE]
> Part B opens no firewall. Add the LAB-04 style input and forward rules on `wlan1` before leaving it running.

## Limitations

- 2.4 GHz only; no 5 GHz tests.
- One MikroTik radio: no WDS, `station-bridge`, or point-to-point link between two MikroTik devices.
- No CAPsMAN (needs a controller and more access points).

## Evidence to capture

Blank out `<WIFI_PSK>`, `<HOME_PSK>`, `<HOME_SSID>`, and client MAC addresses before publishing screenshots.

| File name | Shows |
|---|---|
| `Lab Setup.jpg` | Photo of the hAP lite and the client |
| `Bridge Ports.png` | `/interface bridge port print` |
| `Wireless AP.png` | `wlan1` settings in WinBox |
| `Registration Table.png` | Client signal, rates, CCQ |
| `Access List Denied.png` | A second device refused |
| `Scan.png` | Scan or frequency monitor result |
| `Station Mode.png` | Registration to the home AP and DHCP client `bound` |
| `LAB-13.rsc` | `/export file=LAB-13` (remove PSKs before publishing) |

## Done when

- [ ] A phone joins `MTCNA-LAB` and gets a DHCP lease.
- [ ] Signal and rates recorded at three distances.
- [ ] Access list allows one client and refuses another.
- [ ] Channel chosen with a written reason.
- [ ] Station mode gives the wired laptop Internet through NAT.
- [ ] README updated with results and status changed to Completed.
