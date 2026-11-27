# LAB-08 — RouterOS Management and Backup

**Status:** Planned — guide ready, not yet performed
**Platform:** GNS3, MikroTik CHR (RouterOS 7), WinBox
**Skills:** users and groups, service hardening, clock and NTP, packages and upgrades, backup vs export, scheduled backup, restore test

## Goal

Run the three routers from LAB-06 the way a small office would: personal accounts instead of `admin`, management limited to one network, the same time on every router, and backups that have been **restored at least once**. This lab replaces the cancelled backup/restore lab.

## Topology change

No new links. Add one fresh CHR node, **HQ-RESTORE**, connected only to the management network (`ether1`) for the restore test.

## Steps

### 1. Users and groups

Do this on HQ, BRANCH, and ISP.

```routeros
/user group add name=noc policy=read,winbox,ssh,ping,test comment="Read-only NOC"
/user add name=<NEW_ADMIN> group=full password=<STRONG_PASSWORD>
/user add name=noc group=noc password=<NOC_PASSWORD>
```

Log out, log in as `<NEW_ADMIN>`, then turn off the default account:

```routeros
/user disable admin
/user print
```

Expected: `admin` shows flag `X`. Log in as `noc` and try `/system identity set name=test`. Expected: `not enough permissions`.

### 2. Service hardening

Service hardening was applied to all routers in [LAB-06, management hardening](../LAB-06%20Routing%20Fundamental/#6-management-hardening-all-three-routers). Check that it is still in place:

```routeros
/ip service print
/ip neighbor discovery-settings print
```

Expected: only `winbox` and `ssh` enabled, both with `address=192.168.56.0/24`.

### 3. Clock and NTP

The lab has no Internet, so the ISP becomes the time source.

```routeros
# All routers
/system clock set time-zone-name=Asia/Jakarta

# ISP: set the time by hand once, then serve it
/system clock set date=<YYYY-MM-DD> time=<HH:MM:SS>
/system ntp server set enabled=yes

# HQ and BRANCH
/system ntp client set enabled=yes servers=192.168.100.1
/system ntp client print
```

Expected: HQ and BRANCH client status `synchronized` and the same time as ISP. If HQ shows no sync, check the HQ `input` chain: NTP replies come back as `established` and should pass.

### 4. Packages and upgrade

```routeros
/system package print
/system resource print
```

Record the RouterOS version and architecture. CHR in this lab has no Internet, so `check-for-updates` cannot work. Offline upgrade:

1. Download the matching `routeros-<VERSION>-x86_64.npk` from mikrotik.com on the host.
2. Drag it into **WinBox → Files** on one router.
3. `/system reboot`, then `/system package print` to confirm the new version.

Take a `.backup` before you upgrade.

### 5. Backup vs export

| | `.backup` | `.rsc` export |
|---|---|---|
| Readable | No | Yes |
| Restores users and passwords | Yes | No (passwords are not exported) |
| Restore target | Same router or same model | Any router with matching interface names |
| Safe to publish | No | Yes, after review |

### 6. Scheduled backup

```routeros
/system scheduler add name=daily-backup interval=1d start-time=02:00:00 \
    on-event="/system backup save name=auto-backup; /export file=auto-export"
/system scheduler print
```

To test now, run the same two commands by hand, then `/file print`. Expected: `auto-backup.backup` and `auto-export.rsc`.

### 7. Restore test on a fresh router

1. Copy [LAB-06-HQ.rsc](../LAB-06%20Routing%20Fundamental/LAB-06-HQ.rsc) to **HQ-RESTORE** through WinBox → Files.
2. Import it:

```routeros
/import file-name=LAB-06-HQ.rsc verbose=yes
```

3. Export the result and compare it with the original file (WinMerge or `fc` on Windows).

Expected: identical sections, except the `system id` line. Note any line that fails to import and why (for example, a missing interface).

### 8. `.backup` restore on the same router

```routeros
/system backup save name=before-change
/ip address add address=10.99.99.1/24 interface=ether4 comment="test change"
/system backup load name=before-change
```

Expected: the router reboots and the test address is gone.

## Optional: reset and Netinstall on the hAP lite

> [!WARNING]
> Reset and Netinstall **erase the whole device configuration**. Save a `.backup` and an export of the hAP lite to your PC first.

- `/system reset-configuration no-defaults=yes skip-backup=yes` clears the configuration and keeps RouterOS.
- **Netinstall** reinstalls RouterOS from a PC over Ethernet. Use it when the device does not boot or the password is lost. Record the steps you follow and the version you install.

## Evidence to capture

| File name | Shows |
|---|---|
| `Users.png` | `/user print` with `admin` disabled |
| `NOC Denied.png` | `noc` user blocked from a config change |
| `Services.png` | `/ip service print` after hardening |
| `NTP Client.png` | HQ NTP client `synchronized` |
| `Packages.png` | `/system package print` before and after upgrade |
| `Scheduler.png` | `/system scheduler print` and the files it made |
| `Restore Import.png` | `/import` output on HQ-RESTORE |
| `Export Compare.png` | Diff between original and restored export |
| `LAB-08.rsc` | `/export file=LAB-08` on HQ |

## Done when

- [ ] No router has an enabled `admin` user.
- [ ] HQ and BRANCH sync time from the ISP.
- [ ] A scheduled backup runs and leaves both files.
- [ ] LAB-06 HQ config restored on a fresh CHR and compared.
- [ ] README updated with results and status changed to Completed.
