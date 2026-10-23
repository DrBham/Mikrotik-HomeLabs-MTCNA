# LAB-01 — RouterOS Foundation

## 1. Overview

Lab ini merupakan tahap pertama dari project **MikroTik MTCNA Home Lab — Small Office Network**.

Pada lab ini kita melakukan konfigurasi dasar sebuah MikroTik CHR (Cloud Hosted Router) yang dijalankan secara virtual menggunakan GNS3 dan VirtualBox.

Tujuan utamanya adalah memahami bagaimana sebuah router MikroTik:

* memiliki beberapa network interface;
* diberikan IP address;
* menghubungkan sebuah client ke network;
* mengetahui network yang terhubung langsung dengannya;
* dan melakukan komunikasi dasar menggunakan IP.

Lab ini sengaja dibuat sederhana. Belum ada DHCP, NAT, firewall, maupun koneksi Internet. Fitur-fitur tersebut akan ditambahkan pada lab berikutnya secara bertahap.

---

## 2. Environment

Lab dijalankan menggunakan:

* GNS3 — network simulation
* MikroTik CHR — router virtual
* Oracle VirtualBox — hypervisor
* VPCS — virtual PC/client
* WinBox — management MikroTik

---

## 3. Topology

```text
                         Laptop
                           │
                     Host-Only Network
                           │
                        ether1
                    Management
                           │
                    ┌──────┴──────┐
                    │             │
                    │  CHR-HQ-1   │
                    │  MikroTik   │
                    │             │
                    └──────┬──────┘
                         ether2
                           │
                           │ LAN
                           │
                      ┌────┴────┐
                      │   PC1   │
                      │  VPCS   │
                      └─────────┘
```

### Fungsi masing-masing koneksi

**ether1 — Management**

Digunakan untuk mengakses MikroTik dari laptop menggunakan WinBox.

**ether2 — LAN**

Digunakan sebagai koneksi jaringan lokal antara MikroTik dan PC1.

---

## 4. IP Addressing

| Device   | Interface | IP Address        | Fungsi      |
| -------- | --------- | ----------------- | ----------- |
| CHR-HQ-1 | ether1    | 192.168.56.108/24 | Management  |
| CHR-HQ-1 | ether2    | 192.168.10.1/24   | LAN Gateway |
| PC1      | Ethernet  | 192.168.10.10/24  | LAN Client  |

### LAN Network

```text
Network      : 192.168.10.0/24
Gateway      : 192.168.10.1
PC1          : 192.168.10.10
Broadcast    : 192.168.10.255
```

---

## 5. Apa yang Dibangun?

Secara sederhana, kita membuat sebuah jaringan kecil:

```text
PC1
192.168.10.10
     │
     │
     ▼
MikroTik
192.168.10.1
```

MikroTik berfungsi sebagai gateway untuk jaringan `192.168.10.0/24`.

Karena PC1 dan interface LAN MikroTik berada dalam network yang sama, keduanya dapat berkomunikasi secara langsung.

---

## 6. Konfigurasi MikroTik

### Identity

Router diberikan identity:

```text
MTCNA-SOHO-R1
```

Identity digunakan agar router lebih mudah dikenali ketika dikelola melalui CLI maupun WinBox.

### LAN Interface

Interface `ether2` digunakan sebagai interface LAN.

IP address yang diberikan:

```text
192.168.10.1/24
```

Konfigurasi ini menjadikan MikroTik sebagai gateway untuk LAN.

---

## 7. Konfigurasi PC1

PC1 diberikan konfigurasi statis:

```text
IP Address : 192.168.10.10/24
Gateway    : 192.168.10.1
```

PC1 kemudian dapat melakukan komunikasi dengan MikroTik.

---

## 8. Connected Route

Setelah `192.168.10.1/24` diberikan pada `ether2`, RouterOS secara otomatis membuat route:

```text
192.168.10.0/24 → ether2
```

Artinya MikroTik mengetahui bahwa network `192.168.10.0/24` dapat dicapai secara langsung melalui `ether2`.

Tidak diperlukan static route untuk komunikasi antara PC1 dan MikroTik pada lab ini.

---

## 9. Verification

Beberapa pengujian dilakukan untuk memastikan konfigurasi benar.

### Dari PC1 ke MikroTik

```text
ping 192.168.10.1
```

Hasil:

```text
84 bytes from 192.168.10.1
```

Ping berhasil.

### Dari MikroTik ke PC1

```text
/ping 192.168.10.10
```

Hasil:

```text
sent=3 received=3 packet-loss=0%
```

Artinya MikroTik dan PC1 dapat berkomunikasi dua arah.

### Routing Table

RouterOS menampilkan:

```text
192.168.10.0/24 → ether2
```

yang menunjukkan bahwa network LAN dikenali sebagai directly connected network.

---

## 10. Konsep MTCNA yang Dipraktikkan

Lab ini memperkuat beberapa fundamental:

### Interface

Interface merupakan titik koneksi router terhadap network lain.

### IP Address

IP address digunakan untuk memberikan alamat Layer 3 pada interface.

### Subnet

Subnet menentukan network mana yang menjadi bagian dari sebuah IP address.

### Default Gateway

Gateway merupakan perangkat yang digunakan client ketika ingin berkomunikasi dengan network di luar network lokalnya.

### Connected Route

RouterOS dapat membuat route secara otomatis ketika sebuah IP address dengan subnet diberikan pada interface.

### Ping / ICMP

Ping digunakan untuk menguji apakah dua perangkat dapat melakukan komunikasi IP.

---

## 11. Hal yang Belum Dikonfigurasi

Fitur berikut sengaja belum digunakan:

* DHCP Server
* DHCP Client
* NAT
* Firewall
* DNS configuration
* Static Route
* Internet connectivity

Fitur tersebut akan dipelajari pada lab berikutnya.

---

## 12. Backup

Setelah konfigurasi dinyatakan berhasil, konfigurasi LAB-01 disimpan menggunakan dua metode.

### Export Configuration

```routeros
/export file=LAB-01-final
```

Menghasilkan:

```text
LAB-01-final.rsc
```

File `.rsc` berisi konfigurasi RouterOS dalam format teks sehingga dapat dibaca dan dipelajari.

### Binary Backup

```routeros
/system backup save name=LAB-01-final
```

Menghasilkan:

```text
LAB-01-final.backup
```

File backup digunakan untuk kebutuhan restoration konfigurasi RouterOS pada lingkungan yang sesuai.

---

## 13. Evidence / Documentation

Screenshot yang dikumpulkan:

1. GNS3 topology.
2. Router identity.
3. IP address configuration.
4. Routing table.
5. PC1 berhasil melakukan ping ke MikroTik.
6. MikroTik berhasil melakukan ping ke PC1.
7. File backup/export tersedia di `/file print`.

---

## 14. Result

**LAB-01 — PASS**

Network lokal berhasil dibangun dan komunikasi antara MikroTik dan PC1 berhasil dilakukan tanpa packet loss.

Lab berikutnya akan menambahkan koneksi WAN dan DHCP Client sehingga MikroTik dapat memperoleh IP dari perangkat upstream.

---

## 15. Learning Outcome

Setelah menyelesaikan lab ini, peserta diharapkan dapat menjelaskan:

* apa fungsi interface pada MikroTik;
* bagaimana IP address diberikan pada interface;
* bagaimana menentukan network address dari sebuah subnet;
* mengapa dua perangkat dalam subnet yang sama dapat berkomunikasi langsung;
* bagaimana RouterOS membuat connected route;
* fungsi default gateway;
* cara melakukan basic connectivity testing;
* dan cara melakukan backup konfigurasi RouterOS.
