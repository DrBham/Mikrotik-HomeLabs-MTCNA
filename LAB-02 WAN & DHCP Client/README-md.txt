# LAB-02 — WAN & DHCP Client

## 1. Objective

LAB-02 bertujuan memahami bagaimana MikroTik mendapatkan koneksi WAN secara dynamic dari router ISP menggunakan DHCP Client.

Target pembelajaran:

* Membuat ISP Router sederhana.
* Membuat DHCP Server pada ISP.
* Menghubungkan WAN ISP dengan MikroTik HQ.
* Menggunakan DHCP Client pada MikroTik HQ.
* Memahami dynamic IP address.
* Memahami gateway.
* Memahami default route.
* Melakukan testing konektivitas WAN.
* Memahami DNS melalui DHCP.
* Melakukan basic DNS verification.
* Menjaga koneksi LAN LAB-01 tetap berfungsi.

---

## 2. Environment

* GNS3
* MikroTik CHR
* Oracle VirtualBox
* VPCS
* WinBox
* RouterOS

---

## 3. Topology

```text
                 CHR-ISP-1
                    │
                 ether2
                    │
                    │ WAN
                    │
                 ether3
               CHR-HQ-1
              ┌─────┴─────┐
           ether1        ether2
        Management        LAN
                            │
                           PC1
                         ether0
```

Management menggunakan jaringan Host-Only VirtualBox.

---

## 4. IP Addressing

### CHR-HQ-1

| Interface | Function   | IP Address                 |
| --------- | ---------- | -------------------------- |
| ether1    | Management | 192.168.56.108/24          |
| ether2    | LAN        | 192.168.10.1/24            |
| ether3    | WAN        | 192.168.100.254/24 dynamic |

### CHR-ISP-1

| Interface | Function      | IP Address        |
| --------- | ------------- | ----------------- |
| ether1    | Management    | 192.168.56.109/24 |
| ether2    | WAN toward HQ | 192.168.100.1/24  |

### PC1

```text
IP Address : 192.168.10.10/24
Gateway    : 192.168.10.1
```

---

## 5. ISP DHCP Server

ISP menggunakan:

```text
Network    : 192.168.100.0/24
Gateway    : 192.168.100.1
Pool       : 192.168.100.10-192.168.100.254
DNS Server : 192.168.100.1
Lease Time : 30m
```

DHCP Server:

```text
Name      : ISP-DHCP
Interface : ether2
Pool      : ISP-POOL
```

---

## 6. HQ DHCP Client

CHR-HQ-1 menggunakan DHCP Client pada:

```text
ether3
```

Hasil DHCP:

```text
IP Address : 192.168.100.254/24
Gateway    : 192.168.100.1
DNS        : 192.168.100.1
Status     : bound
```

---

## 7. Default Route

DHCP Client membuat default route:

```text
0.0.0.0/0 → 192.168.100.1
```

Artinya traffic menuju network yang tidak dikenal oleh CHR-HQ-1 akan diarahkan ke ISP Router.

---

## 8. Verification

### LAN

PC1 berhasil melakukan ping:

```text
192.168.10.1
```

Result:

```text
PASS
```

### WAN Gateway

CHR-HQ-1 berhasil melakukan ping:

```text
192.168.100.1
```

Result:

```text
0% packet loss
```

### Simulated External Network

CHR-HQ-1 berhasil mencapai:

```text
8.8.8.1
```

Alamat tersebut digunakan sebagai simulated external destination untuk menguji penggunaan default route.

Result:

```text
PASS
```

### DNS

DHCP Client menerima:

```text
dynamic DNS server = 192.168.100.1
```

DNS lokal kemudian digunakan untuk menguji:

```text
lab02.test → 8.8.8.1
```

Result:

```text
PASS
```

### Internet

Testing:

```text
google.com
```

menghasilkan:

```text
resolve failed
```

Hal tersebut bukan failure LAB-02 karena ISP Router belum memiliki upstream Internet sungguhan.

Internet nyata akan dibahas pada lab berikutnya ketika materi NAT, firewall, dan koneksi Internet mulai diperkenalkan.

---

## 9. Troubleshooting Lesson

Selama lab ditemukan bahwa nomor adapter/port pada GNS3 tidak boleh langsung diasumsikan sama dengan nomor interface etherX pada RouterOS.

Mapping harus diverifikasi menggunakan:

```routeros
/interface print
/ip address print
```

RouterOS/WinBox digunakan sebagai source of truth untuk menentukan interface dan fungsi jaringan.

---

## 10. Backup

Backup yang dibuat:

```text
LAB-01-final
LAB-02-final
LAB-02-ISP-final
```

LAB-02 memiliki backup untuk:

* CHR-HQ-1
* CHR-ISP-1

---

## 11. Evidence

Evidence LAB-02 meliputi:

1. Topology GNS3.
2. IP address CHR-HQ-1.
3. DHCP Client status `bound`.
4. Default route.
5. IP address CHR-ISP-1.
6. DHCP Server ISP.
7. DHCP Network.
8. HQ → ISP gateway ping.
9. HQ → simulated external address.
10. DNS verification.
11. PC1 → HQ LAN gateway.
12. Backup configuration.

---

## 12. Result

LAB-02 dinyatakan:

# PASS

Objective utama LAB-02 telah tercapai.

---

## 13. Learning Outcome

Setelah menyelesaikan LAB-02, peserta memahami:

* DHCP Server dan DHCP Client.
* Dynamic IP Address.
* Gateway.
* Default Route.
* Connected Route.
* WAN interface.
* DNS melalui DHCP.
* Perbedaan management, LAN, dan WAN.
* Dasar troubleshooting interface dan topology.
* Pentingnya melakukan validation sebelum menyatakan konfigurasi berhasil.

---

## 14. Next Lab

LAB berikutnya melanjutkan perjalanan MikroTik menuju konfigurasi jaringan yang lebih lengkap.

Fokus berikutnya akan ditentukan setelah Assessment-02 selesai.
