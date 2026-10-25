# LAB-01 — RouterOS Foundation

> **Project:** MikroTik MTCNA Home Lab — Small Office Network  
> **Tahap:** LAB 01 / Fundamental RouterOS  
> **Status:** ✅ PASS — konektivitas PC1 ↔ MikroTik berhasil diverifikasi  
> **Fokus:** Interface, IPv4 addressing, subnet, connected route, ICMP, dan backup

## Daftar Isi

1. [Gambaran Umum](#1-gambaran-umum)
2. [Tujuan Pembelajaran](#2-tujuan-pembelajaran)
3. [Lingkungan Lab](#3-lingkungan-lab)
4. [Topologi dan Fungsi Interface](#4-topologi-dan-fungsi-interface)
5. [IP Addressing Plan](#5-ip-addressing-plan)
6. [Alur Konfigurasi](#6-alur-konfigurasi)
7. [Mengapa PC1 Bisa Berkomunikasi dengan Router?](#7-mengapa-pc1-bisa-berkomunikasi-dengan-router)
8. [Verifikasi dan Hasil Pengujian](#8-verifikasi-dan-hasil-pengujian)
9. [Troubleshooting Checklist](#9-troubleshooting-checklist)
10. [Backup dan Export](#10-backup-dan-export)
11. [Hal yang Belum Dibahas](#11-hal-yang-belum-dibahas)
12. [Lessons Learned](#12-lessons-learned)
13. [Dokumentasi Screenshot](#13-dokumentasi-screenshot)
14. [Kesimpulan dan Langkah Berikutnya](#14-kesimpulan-dan-langkah-berikutnya)

---

## 1. Gambaran Umum

LAB-01 adalah tahap awal dari proyek **MikroTik MTCNA Home Lab — Small Office Network**. Saya membangun jaringan lokal sederhana dengan sebuah **MikroTik CHR (Cloud Hosted Router)** dan **PC1 (VPCS)** di GNS3.

Pada tahap ini, tujuan saya **bukan menghubungkan PC1 ke Internet**, melainkan memahami bagaimana perangkat memperoleh alamat IP, mengenali jaringan yang terhubung langsung, dan saling berkomunikasi dalam subnet yang sama.

**Gambaran hasil akhir:**

- Laptop dapat digunakan untuk mengelola router melalui jaringan management.
- Router memiliki interface LAN dengan alamat `192.168.10.1/24`.
- PC1 menggunakan IP statis `192.168.10.10/24`.
- PC1 dan router berhasil saling melakukan `ping`.
- RouterOS mengenali jaringan LAN melalui *connected route* otomatis.

## 2. Tujuan Pembelajaran

Setelah mengulang lab ini, saya harus mampu menjawab:

1. Apa perbedaan fungsi interface management (`ether1`) dan LAN (`ether2`)?
2. Mengapa `192.168.10.1/24` dan `192.168.10.10/24` berada dalam satu subnet?
3. Bagaimana router mengetahui jaringan yang terhubung langsung?
4. Mengapa komunikasi PC1 ↔ router tidak memerlukan static route?
5. Apa fungsi default gateway, dan kapan gateway benar-benar digunakan?
6. Bagaimana mengecek konfigurasi IP, routing table, dan konektivitas?
7. Apa perbedaan file export `.rsc` dengan binary backup `.backup`?

## 3. Lingkungan Lab

| Komponen | Peran |
|---|---|
| GNS3 | Membuat topologi dan menghubungkan perangkat virtual |
| MikroTik CHR | Router yang dikonfigurasi dalam lab |
| Oracle VirtualBox | Lingkungan virtualisasi/host-only network |
| VPCS | PC1 sebagai perangkat client |
| WinBox | Mengakses dan mengelola RouterOS |

> **Batasan LAB-01:** Belum ada DHCP, NAT, konfigurasi firewall khusus, static route, DNS, maupun pengujian akses Internet dalam skenario ini.

## 4. Topologi dan Fungsi Interface

```text
                       Laptop / Host
                              |
                      VirtualBox Host-Only
                       192.168.56.0/24
                              |
                       ether1 (Management)
                       192.168.56.108/24
                     +--------------------+
                     |    MikroTik CHR    |
                     |   MTCNA-SOHO-R1    |
                     +--------------------+
                       ether2 (LAN)
                       192.168.10.1/24
                              |
                       192.168.10.0/24
                              |
                         PC1 (VPCS)
                       192.168.10.10/24
```

### Fungsi setiap interface

| Interface | Digunakan untuk | Catatan |
|---|---|---|
| `ether1` | Management dari laptop ke MikroTik | Terhubung ke jaringan VirtualBox Host-Only; alamat yang tercatat `192.168.56.108/24` |
| `ether2` | Koneksi LAN MikroTik ↔ PC1 | Menggunakan `192.168.10.1/24` sebagai alamat router di LAN |

**Penting:** Kedua interface berada pada **subnet berbeda**. Adanya interface management tidak otomatis berarti PC1 sudah dapat mengakses laptop atau Internet. Lab ini hanya memverifikasi komunikasi PC1 dengan router melalui LAN.

## 5. IP Addressing Plan

| Perangkat | Interface | IPv4/prefix | Peran |
|---|---|---|---|
| MikroTik CHR | `ether1` | `192.168.56.108/24` | Management |
| MikroTik CHR | `ether2` | `192.168.10.1/24` | Alamat gateway LAN |
| PC1 | Ethernet | `192.168.10.10/24` | Client LAN |

### Memahami subnet LAN `/24`

| Parameter | Nilai |
|---|---|
| Network address | `192.168.10.0` |
| Subnet mask | `255.255.255.0` |
| CIDR prefix | `/24` |
| Rentang host yang dapat digunakan | `192.168.10.1`–`192.168.10.254` |
| Broadcast address | `192.168.10.255` |
| Total alamat | 256 |
| Alamat host yang dapat digunakan | 254 |

**Kenapa PC1 dan MikroTik dapat berkomunikasi?** Dengan subnet mask `/24`, keduanya menghitung network address yang sama, yaitu `192.168.10.0/24`. PC1 dapat mengirim traffic ke IP LAN router melalui koneksi lokal tanpa membutuhkan router lain sebagai perantara.

> `192.168.10.1` dipilih sebagai alamat gateway karena mudah dikenali, **bukan** karena gateway wajib menggunakan alamat `.1`. Alamat host lain yang valid dalam subnet dapat digunakan selama tidak bentrok.

## 6. Alur Konfigurasi

Bagian ini membedakan **konfigurasi yang tercatat** dan **contoh perintah untuk mengulang/memeriksa lab**. README awal mencatat nilai konfigurasi dan hasil pengujiannya, tetapi tidak mencatat seluruh klik WinBox maupun perintah yang diketik saat konfigurasi pertama dilakukan.

### Langkah 1 — Mengidentifikasi interface router

Pastikan interface management dan LAN terhubung sesuai topologi. Untuk mengecek daftar interface melalui Terminal RouterOS:

```routeros
/interface print
```

**Yang diperiksa:** interface `ether1` dan `ether2` tersedia dan koneksinya sesuai topologi.

### Langkah 2 — Mengatur identity router

Identity yang digunakan dalam lab ini adalah **`MTCNA-SOHO-R1`**.

Contoh perintah untuk menerapkan identity tersebut:

```routeros
/system identity set name=MTCNA-SOHO-R1
```

Verifikasi:

```routeros
/system identity print
```

**Mengapa penting?** Identity membantu membedakan router ketika suatu hari topologi berkembang menjadi beberapa router.

### Langkah 3 — Menetapkan alamat IP LAN MikroTik

Konfigurasi yang tercatat: `192.168.10.1/24` pada `ether2`.

Contoh perintah **jika IP belum dikonfigurasi**:

```routeros
/ip address add address=192.168.10.1/24 interface=ether2 comment="LAB01 - LAN PC1"
```

Untuk memeriksa hasilnya:

```routeros
/ip address print
```

> **Perhatian:** Jangan menjalankan perintah `add` berulang kali jika IP tersebut sudah ada. Periksa konfigurasi terlebih dahulu agar tidak membuat entri duplikat.

IP management `192.168.56.108/24` pada `ether1` tercatat dalam lab awal, tetapi metode perolehannya tidak didokumentasikan secara rinci. Karena itu, README ini tidak menganggap IP tersebut pasti dikonfigurasi secara manual ataupun DHCP.

### Langkah 4 — Mengatur alamat IP PC1

Nilai yang digunakan pada PC1:

```text
IP Address : 192.168.10.10
Subnet Mask: 255.255.255.0 (/24)
Gateway    : 192.168.10.1
```

Contoh konfigurasi melalui console VPCS:

```text
ip 192.168.10.10/24 192.168.10.1
```

Periksa konfigurasi PC1:

```text
show ip
```

**Catatan konsep:** Default gateway disimpan di PC1 untuk mengirim traffic menuju **subnet lain**. Saat PC1 melakukan `ping 192.168.10.1`, alamat tujuannya masih berada dalam subnet lokal; traffic tersebut tidak perlu diteruskan oleh router ke jaringan lain.

### Langkah 5 — Memeriksa routing table

```routeros
/ip route print
```

Ketika IP `192.168.10.1/24` aktif pada `ether2`, RouterOS otomatis mengenali jaringan `192.168.10.0/24` sebagai jaringan yang **directly connected**.

Ringkasan route yang tercatat dalam LAB-01:

```text
Destination: 192.168.10.0/24
Interface  : ether2
Type       : Connected
```

Tidak perlu menambahkan static route agar router berkomunikasi dengan PC1 dalam jaringan tersebut.

## 7. Mengapa PC1 Bisa Berkomunikasi dengan Router?

Saat PC1 ingin mengirim ping ke `192.168.10.1`, gambaran prosesnya adalah:

1. PC1 membandingkan IP tujuan dengan subnet lokalnya (`192.168.10.0/24`).
2. Karena `192.168.10.1` masih berada pada subnet yang sama, PC1 memilih komunikasi langsung melalui LAN.
3. Jika alamat MAC tujuan belum diketahui, PC1 dapat menggunakan **ARP** untuk mengetahui MAC address yang terkait dengan `192.168.10.1`.
4. PC1 mengirim **ICMP Echo Request** ke IP LAN MikroTik.
5. MikroTik merespons dengan **ICMP Echo Reply** jika traffic diterima dan pemrosesannya diizinkan.

**Tiga konsep yang jangan tertukar:**

| Konsep | Menjawab pertanyaan |
|---|---|
| IP address | *Perangkat/interface mana yang dituju pada Layer 3?* |
| ARP table | *MAC address apa yang digunakan untuk mencapai IPv4 tetangga di link lokal?* |
| Routing table | *Melalui interface/next hop mana paket dikirim untuk mencapai destination network?* |

> **Connected route bukan default route.** Connected route memberitahu router tentang subnet yang terpasang langsung. Default route (`0.0.0.0/0`) digunakan sebagai rute cadangan untuk tujuan yang tidak cocok dengan rute yang lebih spesifik. LAB-01 belum menguji default route menuju Internet.

## 8. Verifikasi dan Hasil Pengujian

### Test A — PC1 → MikroTik

Di console VPCS:

```text
ping 192.168.10.1
```

**Hasil yang tercatat:**

```text
84 bytes from 192.168.10.1
```

**Interpretasi:** PC1 menerima respons ICMP dari IP LAN router.

### Test B — MikroTik → PC1

Di Terminal RouterOS:

```routeros
/ping 192.168.10.10
```

**Hasil yang tercatat:**

```text
sent=3 received=3 packet-loss=0%
```

**Interpretasi:** Semua tiga paket pengujian yang tercatat menerima respons; packet loss pada pengujian tersebut adalah 0%.

### Test C — Connected Route

```routeros
/ip route print
```

**Hasil yang tercatat:** `192.168.10.0/24` dikenali melalui `ether2` sebagai jaringan directly connected.

| Pemeriksaan | Hasil LAB-01 |
|---|---|
| IP LAN router `192.168.10.1/24` | Terkonfigurasi |
| IP PC1 `192.168.10.10/24` | Terkonfigurasi |
| Ping PC1 → router | Berhasil |
| Ping router → PC1 | Berhasil (3/3) |
| Connected route LAN | Terdeteksi |
| Akses Internet | Tidak diuji pada lab ini |

## 9. Troubleshooting Checklist

Bagian ini adalah **panduan jika lab diulang dan hasil ping gagal**, bukan daftar masalah yang diklaim pernah terjadi pada pelaksanaan LAB-01.

| Gejala | Pemeriksaan pertama | Langkah berikutnya |
|---|---|---|
| PC1 tidak bisa ping `192.168.10.1` | Jalur/link GNS3 dan interface `ether2` | Pastikan kedua perangkat memakai subnet `/24` yang sama |
| PC1 memakai alamat berbeda | Jalankan `show ip` di VPCS | Samakan dengan IP addressing plan |
| Router tidak memiliki IP LAN | Jalankan `/ip address print` | Pastikan `192.168.10.1/24` ada pada `ether2` |
| Connected route LAN tidak tampak aktif | Jalankan `/ip route print` dan `/interface print` | Cek status interface dan alamat IP yang terpasang |
| Ping masih gagal meski addressing benar | Periksa ARP dan kemungkinan filter ICMP | Gunakan `/ip arp print` serta tinjau aturan firewall yang berlaku |

**Urutan berpikir saat troubleshooting:**

```text
Link / interface → IP address → Subnet → ARP → Route → Firewall → Ping ulang
```

Urutan tersebut merupakan checklist praktis, bukan aturan mutlak; pemeriksaan dapat disesuaikan dengan gejala.

## 10. Backup dan Export

Setelah konfigurasi selesai, dokumentasi awal mencatat dua bentuk penyimpanan.

### A. Text export (`.rsc`)

```routeros
/export file=LAB-01-final
```

Output:

```text
LAB-01-final.rsc
```

File `.rsc` mudah dibaca, dipelajari, dan dibandingkan perubahannya sebagai konfigurasi teks. Untuk repository publik, **tinjau dan sensor informasi sensitif** sebelum mengunggahnya.

### B. Binary backup (`.backup`)

```routeros
/system backup save name=LAB-01-final
```

Output:

```text
LAB-01-final.backup
```

Binary backup ditujukan untuk pemulihan RouterOS pada lingkungan yang kompatibel; format ini tidak cocok dijadikan dokumentasi teks yang dibaca langsung di GitHub dan dapat menyimpan informasi sensitif.

Cek file di router:

```routeros
/file print
```

**Saran repository:** Simpan README dan screenshot yang aman dipublikasikan. Hindari mengunggah `.backup` ke repository publik. Upload `.rsc` hanya setelah meninjau isi file dan menghapus informasi rahasia.

## 11. Hal yang Belum Dibahas

| Fitur | Status pada skenario LAB-01 |
|---|---|
| DHCP Server / Client | Belum menjadi bagian konfigurasi lab |
| NAT / masquerade | Belum dikonfigurasi dalam skenario lab |
| Firewall filter khusus | Belum dibahas |
| DNS configuration | Belum dibahas |
| Static route | Tidak dibutuhkan untuk pengujian lokal ini |
| WAN / Internet | Belum diuji |

Jangan mengartikan keberhasilan ping di LAN sebagai bukti bahwa client sudah bisa mengakses Internet.

## 12. Lessons Learned

**1. Interface mempunyai peran berbeda.** `ether1` digunakan untuk management, sedangkan `ether2` menghubungkan router dengan PC1 di LAN.

**2. Prefix menentukan batas subnet.** `/24` pada dua alamat LAN memungkinkan PC1 dan IP router berada pada network address yang sama, yaitu `192.168.10.0/24`.

**3. IP gateway bukan harus `.1`.** `192.168.10.1` adalah pilihan addressing dalam topologi ini, bukan syarat teknis semua gateway.

**4. Connected route dibuat otomatis.** Saat network langsung terpasang dan interface aktif, RouterOS mengenali jaringan tersebut tanpa static route manual.

**5. Ping adalah pengujian, bukan bukti semua layanan bekerja.** Ping yang sukses mengonfirmasi konektivitas ICMP untuk tujuan yang diuji, bukan otomatis menjamin DHCP, DNS, atau Internet berfungsi.

**6. Bukti hasil perlu disimpan.** Screenshot, hasil pengujian, dan export konfigurasi membantu mengulang analisis saat konfigurasi berkembang di lab berikutnya.

### Pertanyaan untuk menguji pemahaman diri

<details>
<summary>Kenapa PC1 bisa ping MikroTik tanpa static route?</summary>

Karena keduanya berada pada subnet `192.168.10.0/24` yang sama dan terhubung langsung lewat LAN. RouterOS juga mengenali subnet LAN sebagai connected network.

</details>

<details>
<summary>Apakah PC1 menggunakan default gateway untuk ping 192.168.10.1?</summary>

IP tujuan itu sendiri berada dalam subnet lokal PC1. Karena itu, PC1 mengirim frame langsung ke IP LAN router melalui link lokal. Default gateway diperlukan ketika tujuan berada di luar subnet lokal.

</details>

<details>
<summary>Apa perbedaan routing table dan ARP table?</summary>

Routing table memilih jalur atau interface untuk mencapai jaringan tujuan. ARP table memetakan alamat IPv4 tetangga pada jaringan lokal ke alamat MAC yang diperlukan untuk pengiriman frame.

</details>

## 13. Dokumentasi Screenshot

README ini tidak mengasumsikan bahwa gambar sudah disimpan di repository. Untuk menambahkan evidence, gunakan folder seperti berikut:

```text
LAB-01-RouterOS-Foundation/
├── README.md
└── screenshots/
    ├── 01-topology.png
    ├── 02-router-identity.png
    ├── 03-ip-addresses.png
    ├── 04-connected-route.png
    ├── 05-ping-pc-to-router.png
    ├── 06-ping-router-to-pc.png
    └── 07-backup-files.png
```

Setelah screenshot tersedia, gambar bisa ditampilkan pada README dengan sintaks:

```markdown
![Topologi LAB-01](screenshots/01-topology.png)
```

**Checklist evidence:** topologi GNS3, router identity, konfigurasi IP, routing table, ping dua arah, dan daftar file export/backup.

## 14. Kesimpulan dan Langkah Berikutnya

### ✅ LAB-01 — PASS

Saya berhasil membangun jaringan lokal antara MikroTik CHR dan VPCS, menetapkan IPv4 statis pada interface LAN serta client, mengamati connected route, dan memverifikasi komunikasi dua arah melalui ICMP.

**Batas keberhasilan:** Hasil ini membuktikan komunikasi PC1 ↔ MikroTik pada subnet LAN. DHCP, WAN, NAT, firewall khusus, dan koneksi Internet **belum menjadi hasil LAB-01**.

**Kelanjutan historis: LAB-02 — WAN & DHCP Client.** Pada tahap akhir pembelajaran enam lab, project diteruskan ke Final Project setelah LAB07 dihentikan dan LAB08 dibatalkan.

---

*Dokumentasi ini adalah bagian dari perjalanan belajar MikroTik secara bertahap: dari memahami konsep dasar, melakukan konfigurasi, memverifikasi hasil, hingga melatih troubleshooting.*

---

## Catatan Audit dan Kesinambungan (Oktober 2026)

> **Catatan kesinambungan project (25 Oktober 2026):** Roadmap yang benar-benar dijalankan adalah LAB01 RouterOS Foundation, LAB02 WAN/DHCP Client, LAB03 NAT, LAB04 Firewall, LAB05 DHCP Server LAN, dan LAB06 Static Routing HQ–BRANCH. LAB07 Network Troubleshooting **dihentikan sebelum selesai** dan LAB08 Backup/Restore **dibatalkan** atas keputusan pemilik project. Tahap berikutnya adalah **Final Project — Small Office Network Integration**. Perubahan ini tidak mengubah hasil historis lab ini.

### Kaitan dengan tahap selanjutnya

LAB01 menggunakan PC1 **IP statis `192.168.10.10/24`**. Pada LAB05, layanan DHCP LAN HQ mulai digunakan dan PC1 tercatat menerima `192.168.10.100/24`. Kedua IP adalah hasil dari **tahap yang berbeda**, bukan ketidakkonsistenan konfigurasi pada satu waktu.

### Batas validasi backup

Perintah export dan backup dicatat sebagai langkah dokumentasi. README ini tidak menyertakan output `/file print` yang memastikan masing-masing file benar-benar tersedia saat audit; verifikasi file perlu dilakukan bila artefak akan dipakai untuk recovery.
