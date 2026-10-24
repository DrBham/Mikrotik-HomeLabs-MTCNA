# LAB-02 — WAN & DHCP Client

> **MikroTik Junior Journey to Master MikroTik**  
> **Track:** MTCNA Home Lab — Small Office Network  
> **Status:** ✅ PASS  
> **Fokus:** Simulasi ISP, DHCP Server, DHCP Client pada WAN, default route, dan DNS lokal.

## Daftar Isi

1. [Ringkasan Lab](#1-ringkasan-lab)
2. [Tujuan dan Batasan](#2-tujuan-dan-batasan)
3. [Environment dan Topologi](#3-environment-dan-topologi)
4. [IP Addressing](#4-ip-addressing)
5. [Alur Kerja Jaringan](#5-alur-kerja-jaringan)
6. [Konfigurasi dan Pemeriksaan](#6-konfigurasi-dan-pemeriksaan)
7. [Verification dan Hasil](#7-verification-dan-hasil)
8. [Troubleshooting](#8-troubleshooting)
9. [Konsep Networking yang Dipelajari](#9-konsep-networking-yang-dipelajari)
10. [Backup dan Evidence](#10-backup-dan-evidence)
11. [Kesimpulan dan Refleksi](#11-kesimpulan-dan-refleksi)
12. [Materi Lanjutan](#12-materi-lanjutan)

---

## 1. Ringkasan Lab

LAB-02 melanjutkan LAB-01. Sebelumnya, **PC1 dan CHR-HQ-1** telah dapat saling berkomunikasi pada LAN `192.168.10.0/24`. Kali ini ditambahkan **CHR-ISP-1** sebagai router upstream (ISP simulasi), sehingga HQ bisa mempelajari cara memperoleh konfigurasi WAN otomatis melalui DHCP.

**Gambaran proses:**

```text
ISP DHCP Server (ether2)
        │ memberi lease IP, gateway, DNS
        ▼
HQ DHCP Client (ether3)
        │ memperoleh WAN IP dan default route
        ▼
HQ dapat menguji keterjangkauan ISP dan tujuan eksternal simulasi
```

**Hasil utama yang tercatat:** DHCP Client HQ berstatus `bound`, mendapat `192.168.100.254/24`, menerima gateway dan DNS `192.168.100.1`, serta berhasil menguji konektivitas WAN dan DNS simulasi. LAN dari LAB-01 tetap berfungsi.

## 2. Tujuan dan Batasan

### Target praktik

- Membuat router ISP simulasi dan DHCP Server pada interface yang mengarah ke HQ.
- Menghubungkan port WAN HQ ke ISP.
- Mengaktifkan DHCP Client di WAN HQ dan memeriksa status lease `bound`.
- Memahami IP dynamic, default gateway, dan default route.
- Menguji komunikasi HQ–ISP, tujuan eksternal simulasi, serta resolusi DNS lokal.
- Memastikan konektivitas PC1 → HQ dari LAB-01 masih berfungsi.

### Batasan lab

**Lab ini belum membuktikan akses Internet publik.** Alamat `8.8.8.1` dipakai sebagai *simulated external destination*. Pengujian `google.com` menghasilkan `resolve failed`, dan dokumentasi asal menyebut ISP belum mempunyai upstream Internet sungguhan. Hasil pengujian tersebut **tidak menggugurkan** tujuan LAB-02.

Jangan menganggap `8.8.8.1` sebagai alamat Internet publik yang telah diuji langsung, atau menyimpulkan NAT sudah dikonfigurasi di lab ini.

## 3. Environment dan Topologi

**Perangkat lunak dan node:** GNS3, MikroTik CHR / RouterOS, Oracle VirtualBox, VPCS, dan WinBox.

```text
       Host-Only VirtualBox (Management: 192.168.56.0/24)
               │                         │
        CHR-ISP-1 ether1            CHR-HQ-1 ether1

                CHR-ISP-1
             ether2: 192.168.100.1/24
                      │
                   WAN link
                      │
             ether3: DHCP Client
                  CHR-HQ-1
             ether2: 192.168.10.1/24
                      │
                    LAN link
                      │
                PC1: 192.168.10.10/24
```

> **Ingat:** Interface management (`ether1`) berbeda fungsi dengan link ISP–HQ. Jangan menyamakan jaringan Host-Only `192.168.56.0/24` dengan subnet WAN `192.168.100.0/24`.

### Fungsi interface

| Node | Interface | Peran | Keterangan |
|---|---|---|---|
| CHR-ISP-1 | `ether1` | Management | Akses administrasi melalui VirtualBox Host-Only |
| CHR-ISP-1 | `ether2` | Upstream menuju HQ | DHCP Server ISP berada di sini |
| CHR-HQ-1 | `ether1` | Management | Akses WinBox dari laptop |
| CHR-HQ-1 | `ether2` | LAN | Gateway bagi PC1 |
| CHR-HQ-1 | `ether3` | WAN | DHCP Client, menerima konfigurasi dari ISP |

## 4. IP Addressing

| Perangkat | Interface | IP / Prefix | Metode / Fungsi |
|---|---|---|---|
| CHR-ISP-1 | `ether1` | `192.168.56.109/24` | Management |
| CHR-ISP-1 | `ether2` | `192.168.100.1/24` | Gateway DHCP sisi ISP |
| CHR-HQ-1 | `ether1` | `192.168.56.108/24` | Management |
| CHR-HQ-1 | `ether2` | `192.168.10.1/24` | Gateway LAN |
| CHR-HQ-1 | `ether3` | `192.168.100.254/24` | **Dynamic**, diperoleh dari DHCP |
| PC1 | Ethernet (`ether0`) | `192.168.10.10/24` | Client LAN, gateway `192.168.10.1` |

### Dua subnet yang perlu dibedakan

- **LAN:** `192.168.10.0/24`. PC1 dan `ether2` HQ saling terhubung langsung.
- **WAN simulasi:** `192.168.100.0/24`. `ether3` HQ dan `ether2` ISP saling terhubung langsung.
- **Management:** `192.168.56.0/24`. Digunakan untuk pengelolaan node dari host, bukan jalur uji WAN–ISP.

**Catatan:** IP `192.168.100.254` merupakan *lease* yang didapat pada pelaksanaan lab, bukan jaminan bahwa DHCP Client akan selalu mendapatkan alamat tersebut pada percobaan lain.

## 5. Alur Kerja Jaringan

### A. Saat HQ menerima WAN DHCP

1. ISP menyediakan DHCP Server di `ether2`.
2. HQ menjalankan DHCP Client pada `ether3`.
3. DHCP Server mengalokasikan alamat dari pool yang disiapkan.
4. HQ menerima IP, subnet mask, gateway, dan DNS sesuai hasil lease.
5. DHCP Client berstatus `bound`; default route ke ISP tersedia.

**Pendalaman konsep — DORA:** DHCP secara umum menggunakan pertukaran *Discover → Offer → Request → Acknowledge* untuk mendapatkan lease. Ini penjelasan teori protokol; README awal tidak mencatat packet capture DORA.

### B. Ketika HQ mengirim paket ke tujuan

```text
Destination di subnet WAN (mis. 192.168.100.1)
  → HQ memakai connected route 192.168.100.0/24 via ether3

Destination di luar subnet yang dikenal HQ (mis. 8.8.8.1)
  → HQ menggunakan default route 0.0.0.0/0 via 192.168.100.1
```

**Penting:** default route menentukan *next hop*, tetapi tidak otomatis menjamin bahwa router upstream dapat meneruskan paket hingga Internet.

### C. LAN tetap hidup

PC1 (`192.168.10.10/24`) dan LAN HQ (`192.168.10.1/24`) tetap berada dalam satu subnet. Ping PC1 → gateway LAN tidak memerlukan Internet maupun default route ISP.

## 6. Konfigurasi dan Pemeriksaan

Bagian ini memisahkan **parameter yang dicatat pada lab** dari **perintah contoh untuk mengulangnya**. Perintah tidak dimaksudkan sebagai rekaman CLI asli dari sesi LAB-02.

### A. ISP — parameter DHCP Server yang digunakan

| Parameter | Nilai |
|---|---|
| DHCP Server name | `ISP-DHCP` |
| Server interface | `ether2` |
| Pool name | `ISP-POOL` |
| Address pool | `192.168.100.10-192.168.100.254` |
| DHCP network | `192.168.100.0/24` |
| Gateway yang dibagikan | `192.168.100.1` |
| DNS yang dibagikan | `192.168.100.1` |
| Lease time | `30m` |

**Contoh RouterOS CLI untuk mereplikasi konfigurasi inti pada ISP** (periksa terlebih dahulu apakah alamat, pool, atau server sudah ada; jangan membuat duplikat):

```routeros
/ip address add address=192.168.100.1/24 interface=ether2 comment="WAN to HQ"
/ip pool add name=ISP-POOL ranges=192.168.100.10-192.168.100.254
/ip dhcp-server network add address=192.168.100.0/24 gateway=192.168.100.1 dns-server=192.168.100.1
/ip dhcp-server add name=ISP-DHCP interface=ether2 address-pool=ISP-POOL lease-time=30m disabled=no
```

**Validasi pada ISP:**

```routeros
/ip address print
/ip pool print
/ip dhcp-server print detail
/ip dhcp-server network print detail
/ip dhcp-server lease print detail
```

### B. HQ — DHCP Client WAN

**Hasil yang dicatat:**

```text
Interface : ether3
Status    : bound
Address   : 192.168.100.254/24
Gateway   : 192.168.100.1
DNS       : 192.168.100.1
```

**Contoh konfigurasi** (hanya jika DHCP Client belum ada di `ether3`):

```routeros
/ip dhcp-client add interface=ether3 add-default-route=yes use-peer-dns=yes disabled=no
```

**Cara memeriksa:**

```routeros
/ip dhcp-client print detail
/ip address print
/ip route print
/ip dns print
```

Lihat apakah DHCP Client `bound`, alamat WAN muncul sebagai dynamic, dan ada route `0.0.0.0/0` menuju `192.168.100.1`. Opsi `use-peer-dns=yes` pada contoh di atas mengizinkan DNS yang diberikan DHCP dipakai oleh router, sedangkan `add-default-route=yes` mengizinkan penambahan default route.

### C. Memahami connected route dan default route

| Route | Terbentuk karena | Fungsi |
|---|---|---|
| `192.168.10.0/24` via `ether2` | IP LAN pada HQ | Mengakses jaringan LAN secara langsung |
| `192.168.100.0/24` via `ether3` | DHCP memberikan IP WAN HQ | Mengakses jaringan WAN ISP secara langsung |
| `0.0.0.0/0` via `192.168.100.1` | Default route dari DHCP Client | Mengirim traffic ke tujuan lain melalui ISP |

**Jangan tertukar:** IP WAN dinamis bukan berarti seluruh routing otomatis berfungsi ke mana saja. Route menunjukkan jalur berikutnya; keterjangkauan akhir tetap harus dibuktikan dengan testing.

## 7. Verification dan Hasil

| Pengujian | Tujuan | Hasil tercatat | Status |
|---|---|---|---|
| PC1 → `192.168.10.1` | Memastikan LAN LAB-01 tetap berjalan | Berhasil | ✅ PASS |
| HQ → `192.168.100.1` | Menguji link ke gateway ISP | `0% packet loss` | ✅ PASS |
| HQ → `8.8.8.1` | Menguji simulated external destination | Berhasil | ✅ PASS |
| DHCP Client HQ | Memastikan HQ mendapat lease | `bound` | ✅ PASS |
| DNS `lab02.test` → `8.8.8.1` | Menguji resolusi nama lokal | Berhasil | ✅ PASS |
| Nama domain `google.com` | Memeriksa resolusi Internet nyata | `resolve failed` | ⚠️ Di luar target Internet LAB-02 |

**Contoh perintah verifikasi untuk mengulang lab:**

Di **PC1 (VPCS)**:

```text
show ip
ping 192.168.10.1
```

Di **CHR-HQ-1 (RouterOS)**:

```routeros
/ip dhcp-client print detail
/ip route print detail
/ping 192.168.100.1 count=3
/ping 8.8.8.1 count=3
:put [:resolve "lab02.test"]
```

Perintah resolusi DNS contoh di atas memerlukan entri DNS simulasi dan DNS service yang memang bekerja. File sumber mencatat bahwa `lab02.test` berhasil di-resolve, tetapi **tidak merinci perintah yang dipakai untuk membuat entri DNS tersebut**. Jangan menebak konfigurasi aslinya.

> **Interpretasi hasil:** ping ISP membuktikan komunikasi ke next hop; ping tujuan simulasi membuktikan jalur yang diuji berfungsi; resolusi `lab02.test` membuktikan DNS simulasi. Ketiganya **tidak sama** dengan bukti Internet publik.

## 8. Troubleshooting

### Pelajaran utama: mapping GNS3 ≠ asumsi interface RouterOS

Selama LAB-02 ditemukan bahwa urutan adapter atau port di GNS3 tidak boleh langsung dianggap identik dengan `ether1`, `ether2`, atau `ether3` pada RouterOS.

**Langkah diagnosis yang bisa diulang:**

1. Cocokkan kabel di topologi GNS3 dengan interface yang terlihat di RouterOS.
2. Periksa interface dan status link:

   ```routeros
   /interface print
   ```

3. Periksa IP untuk mengetahui peran tiap interface:

   ```routeros
   /ip address print
   ```

4. Pastikan DHCP Client dipasang pada interface **WAN HQ yang benar**, yaitu `ether3` menurut dokumentasi ini.
5. Pastikan DHCP Server ISP berada pada `ether2`.
6. Periksa status `bound`, lease, dan default route; baru lanjutkan pengujian ping.

### Jika masalah muncul kembali

| Gejala | Pemeriksaan pertama | Yang perlu dipahami |
|---|---|---|
| DHCP Client tidak `bound` | Link fisik/virtual, interface DHCP Client, DHCP Server ISP | Kedua ujung harus terhubung pada segmen yang sesuai |
| IP WAN muncul, ISP tidak bisa diping | Subnet, alamat gateway, interface dan link | Mendapat lease belum cukup untuk menjamin komunikasi |
| ISP bisa diping, tujuan simulasi gagal | Default route HQ, jalur/rute pada ISP, keberadaan tujuan simulasi | Next hop aktif belum tentu destination terjangkau |
| Ping IP berhasil, nama domain gagal | DNS dari DHCP, layanan DNS, dan record uji | DNS adalah mekanisme berbeda dari routing IP |
| PC1 → HQ gagal setelah perubahan WAN | IP PC1, IP `ether2`, kabel LAN | Perubahan WAN seharusnya tidak merusak komunikasi satu subnet |

**Urutan berpikir yang dipakai:** `Interface → IP → DHCP Lease → Route → Ping by IP → DNS`.

## 9. Konsep Networking yang Dipelajari

| Konsep | Pengertian dalam konteks LAB-02 |
|---|---|
| **DHCP Server** | Komponen ISP yang membagikan konfigurasi IP ke HQ |
| **DHCP Client** | Komponen HQ yang meminta dan menerima lease pada interface WAN |
| **Dynamic IP** | IP diberikan lewat DHCP; bisa berubah sesuai lease dan kebijakan server |
| **Lease Time** | Periode peminjaman alamat sebelum proses renewal diperlukan |
| **Default Gateway** | Alamat next hop untuk menuju jaringan di luar network lokal |
| **Connected Route** | Route otomatis untuk subnet yang secara langsung terpasang pada interface |
| **Default Route** | Route `0.0.0.0/0` untuk tujuan yang tidak memiliki route lebih spesifik |
| **DNS** | Mengubah nama domain menjadi alamat IP, terpisah dari fungsi ping/routing |
| **Management/LAN/WAN** | Tiga peran jaringan berbeda walaupun semua memakai interface Ethernet |

### Contoh pertanyaan untuk belajar ulang

1. Mengapa DHCP Client harus ditempatkan di `ether3`, bukan `ether2` HQ?
2. Apa arti status `bound`, dan informasi apa yang diterima HQ?
3. Mengapa default route `0.0.0.0/0` menuju `192.168.100.1`?
4. Apa beda ping `192.168.100.1` dengan ping `8.8.8.1` pada lab ini?
5. Mengapa kegagalan `google.com` tidak otomatis berarti LAB-02 gagal?
6. Jika IP WAN mendapat lease tetapi tidak ada default route, apa yang akan diperiksa?
7. Mengapa management network dan WAN network tidak boleh dicampur saat menganalisis topologi?

## 10. Backup dan Evidence

### Backup yang tercatat

Dokumentasi asli mencatat nama backup berikut:

```text
LAB-01-final
LAB-02-final
LAB-02-ISP-final
```

LAB-02 mencakup backup untuk **CHR-HQ-1** dan **CHR-ISP-1**. Format file persisnya tidak disebutkan dalam README LAB-02 awal, sehingga tidak diasumsikan apakah semuanya `.rsc` atau `.backup`.

**Rekomendasi untuk pengarsipan berikutnya:** gunakan export `.rsc` yang sudah diperiksa dan dibersihkan dari data sensitif untuk repository GitHub; simpan binary backup secara privat karena dapat mengandung konfigurasi sensitif.

Contoh membuat export pada masing-masing router (bukan klaim perintah yang digunakan pada sesi asli):

```routeros
/export file=LAB-02-final
```

> Sebelum mengunggah file ekspor, periksa IP manajemen, password/secret, key, token, dan informasi lingkungan internal. Binary backup sebaiknya tidak dipublikasikan.

### Daftar screenshot/evidence

- [ ] Topologi GNS3
- [ ] IP address CHR-HQ-1
- [ ] DHCP Client HQ berstatus `bound`
- [ ] Routing table/default route HQ
- [ ] IP address CHR-ISP-1
- [ ] DHCP Server ISP dan pool
- [ ] DHCP network ISP (gateway dan DNS)
- [ ] Ping HQ → ISP gateway
- [ ] Ping HQ → external destination simulasi
- [ ] DNS verification `lab02.test`
- [ ] Ping PC1 → gateway LAN HQ
- [ ] Daftar backup/export

> Kotak centang di atas merupakan daftar arsip yang perlu dikumpulkan, **bukan** pernyataan bahwa seluruh screenshot sudah dilampirkan ke repository.

**Saran struktur folder GitHub:**

```text
LAB-02-WAN-DHCP-Client/
├── README.md
├── evidence/
│   ├── topology.png
│   ├── dhcp-client-bound.png
│   ├── default-route.png
│   ├── isp-dhcp-server.png
│   ├── wan-ping.png
│   └── dns-verification.png
└── configs/
    ├── README.md
    └── (opsional: export .rsc yang sudah disanitasi)
```

Nama file screenshot di atas **contoh penamaan**, bukan nama file yang telah diverifikasi tersedia.

## 11. Kesimpulan dan Refleksi

### ✅ LAB-02 — PASS

Target utama telah tercapai:

- CHR-ISP-1 menyediakan DHCP Server pada network WAN simulasi.
- CHR-HQ-1 memperoleh IP WAN dynamic beserta gateway dan DNS.
- Default route ke ISP terpasang.
- Konektivitas HQ → ISP, tujuan eksternal simulasi, dan DNS lokal berhasil diuji.
- Koneksi PC1 → gateway LAN dari LAB-01 tetap berfungsi.

**Pelajaran penting:** konfigurasi yang terlihat benar harus tetap diuji. Untuk mendiagnosis kegagalan, saya perlu memeriksa interface, addressing, status DHCP, route, lalu membedakan masalah konektivitas IP dengan masalah DNS.

## 12. Materi Lanjutan

LAB berikutnya akan ditentukan setelah **Assessment-02**, sesuai dokumentasi awal. Area pembelajaran berikutnya dapat memperluas simulasi menuju routing, NAT, firewall, dan koneksi Internet sesuai tahapan lab yang dijalankan.

---

**Project:** MikroTik Junior Journey to Master MikroTik  
**Lab:** LAB-02 — WAN & DHCP Client  
**Result:** ✅ PASS
