# LAB-09 — QoS and Bandwidth Management

**Status:** Planned — guide ready, not yet performed
**Platform:** GNS3, MikroTik CHR (RouterOS 7), WinBox
**Skills:** simple queues, max-limit, burst, PCQ, bandwidth testing

## Goal

Limit and share LAN bandwidth on HQ with **simple queues**, then prove each limit with a real traffic test. Builds on the LAB-06 topology (with the LAB-07 bridge if done).

## Topology change

VPCS cannot generate bulk traffic. Add **CLIENT-CHR**, a CHR node with identity `CLIENT`, to the HQ LAN (`bridge-lan` from LAB-07, or `ether2`).

```text
CLIENT-CHR ── HQ LAN ── CHR-HQ-1 ── ether3 ── CHR-ISP-1 (bandwidth-test server)
```

> [!WARNING]
> A free CHR license limits upload on each interface to **1 Mbps**. Keep test limits well below that (256k–512k), or activate the free 60-day `p1` trial license.

## Steps

### 1. Prepare the client and the server

On CLIENT-CHR:

```routeros
/system identity set name=CLIENT
/ip dhcp-client add interface=ether1
/ip address print
```

Expected: a lease from `DHCP-LAN` in `192.168.10.10-192.168.10.100`. Write down `<CLIENT_IP>`.

On ISP (LAB-08 hardening turns this off):

```routeros
/tool bandwidth-server set enabled=yes authenticate=yes
```

### 2. Baseline without a queue

On CLIENT-CHR:

```routeros
/tool bandwidth-test address=192.168.100.1 protocol=tcp direction=both \
    user=admin password=<ISP_PASSWORD> duration=20s
```

Record tx/rx averages. This is the number every queue is compared with.

### 3. Simple queue with max-limit

On HQ. `max-limit` is written **upload/download** from the target's point of view.

```routeros
/queue simple add name=CLIENT-limit target=<CLIENT_IP>/32 max-limit=256k/512k
```

Run the bandwidth test again, then:

```routeros
/queue simple print stats
```

Expected: client upload close to 256 kbps, download close to 512 kbps, and the queue byte counters rising.

### 4. Burst

```routeros
/queue simple set [find name=CLIENT-limit] max-limit=256k/256k \
    burst-limit=512k/512k burst-threshold=192k/192k burst-time=16s/16s
```

Run a 40-second test. Expected: the first seconds near 512 kbps, then a drop to 256 kbps once the average rate passes the threshold. Explain the result with the three burst values.

### 5. PCQ for per-host fairness

```routeros
/queue simple remove [find name=CLIENT-limit]
/queue type add name=pcq-up kind=pcq pcq-rate=128k pcq-classifier=src-address
/queue type add name=pcq-down kind=pcq pcq-rate=128k pcq-classifier=dst-address
/queue simple add name=LAN-PCQ target=192.168.10.0/24 \
    queue=pcq-up/pcq-down max-limit=512k/512k
```

Expected: CLIENT-CHR gets about 128 kbps each way even though the queue allows 512k. PCQ makes one sub-queue per address, so each host gets its own share instead of one host taking everything. With a second CHR client, both would get 128k.

### 6. FastTrack note

Connections that are fast-tracked skip simple queues. LAB-06 HQ has no FastTrack rule, so queues work here. LAB-10 adds FastTrack and shows the conflict.

### 7. Clean up

```routeros
/queue simple print
/export file=LAB-09
```

Turn the ISP bandwidth server off again if you keep the LAB-08 hardening.

## Evidence to capture

| File name | Shows |
|---|---|
| `Topology.png` | GNS3 drawing with CLIENT-CHR |
| `Baseline Test.png` | Bandwidth test with no queue |
| `Max-Limit Test.png` | Test result with `CLIENT-limit` |
| `Queue Stats.png` | `/queue simple print stats` |
| `Burst Test.png` | Rate during the first seconds and after |
| `PCQ Test.png` | Test result with `LAN-PCQ` |
| `LAB-09.rsc` | `/export file=LAB-09` on HQ |

## Done when

- [ ] Baseline, max-limit, burst, and PCQ tests recorded with numbers.
- [ ] Each measured rate explained against its queue setting.
- [ ] README updated with results and status changed to Completed.
