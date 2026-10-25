# LAB-05 — DHCP Server & LAN Client Management

**MikroTik MTCNA Home Lab · Junior Network Engineer Portfolio**  
**Status:** PASS setelah remedial · **Assessment awal:** 64/100 · **Backup tercatat:** `LAB-05.backup`

> **Catatan dokumentasi:** README ini disusun dari catatan praktik asli. Command verifikasi merupakan referensi untuk mengulang pemeriksaan; tidak semua command dinyatakan telah dijalankan ketika lab berlangsung. Nama interface dan nilai IP mengikuti evidence pada lab ini, bukan template untuk topologi lain.


## Daftar Isi

1. [Ringkasan](#1-ringkasan)
2. [Tujuan dan lingkungan](#2-tujuan-dan-lingkungan)
3. [Topologi dan IP](#3-topologi-dan-ip)
4. [Konfigurasi DHCP Server](#4-konfigurasi-dhcp-server)
5. [Penjelasan DORA, lease, gateway, dan DNS](#5-penjelasan-dora-lease-gateway-dan-dns)
6. [Hubungan DHCP, routing dan NAT](#6-hubungan-dhcp-routing-dan-nat)
7. [Validasi dan batas konektivitas](#7-validasi-dan-batas-konektivitas)
8. [Studi kasus troubleshooting](#8-studi-kasus-troubleshooting)
9. [Backup, evidence, dan assessment](#9-backup-evidence-dan-assessment)
10. [Learning outcome](#10-learning-outcome)

## 1. Ringkasan

Pada LAB05 saya mengonfigurasi **DHCP Server di LAN HQ** supaya PC1 memperoleh IP, gateway dan DNS secara otomatis. Hasil akhirnya PC1 memperoleh lease `192.168.10.100/24`, bisa mencapai gateway HQ dan ISP virtual, serta teramati menggunakan NAT yang sebelumnya dipasang. Pengujian ke Internet publik gagal karena ISP simulasi tidak memiliki upstream/default route; **hal itu tidak membatalkan keberhasilan DHCP**.

## 2. Tujuan dan lingkungan

- Membuat DHCP Pool, DHCP Server, dan DHCP Network.
- Memahami DORA dan membaca DHCP Lease.
- Memisahkan fungsi gateway, DNS, dan DHCP.
- Memverifikasi keterkaitan IP client, dynamic WAN lease, default route, dan NAT.
- Mengidentifikasi kesalahan konfigurasi dengan evidence.

**Tools:** GNS3, MikroTik CHR, WinBox, Oracle VirtualBox, VPCS.

## 3. Topologi dan IP

```text
VirtualBox host-only ── ether1 [CHR-HQ-1]
PC1 (DHCP) ── ether2 [CHR-HQ-1] ether3 (DHCP Client) ── ether2 [CHR-ISP-1]
                LAN 192.168.10.1                       ISP 192.168.100.1
```

| Perangkat | Interface | Address / assignment | Fungsi |
|---|---|---|---|
| ISP | ether1 | `192.168.56.109/24` | Management |
| ISP | ether2 | `192.168.100.1/24` | WAN / DHCP Server |
| HQ | ether1 | `192.168.56.108/24` | Management |
| HQ | ether2 | `192.168.10.1/24` | LAN / DHCP Server |
| HQ | ether3 | DHCP Client → tercatat `192.168.100.254/24` | WAN |
| PC1 | Ethernet | DHCP → `192.168.10.100/24` | GW/DNS `192.168.10.1` |

## 4. Konfigurasi DHCP Server

Tiga komponen DHCP pada HQ:

| Komponen | Konfigurasi | Peran |
|---|---|---|
| Pool | `LAN-POOL`, `192.168.10.10–192.168.10.100` | Pilihan IP untuk dibagikan (91 alamat) |
| Server | `DHCP-LAN`, `interface=ether2`, `lease-time=30m` | Melayani permintaan DHCP di LAN |
| Network | `192.168.10.0/24`, gateway/DNS `192.168.10.1` | Parameter IP yang diberikan ke client |

Perintah yang tercantum dalam catatan praktik:

```routeros
/ip pool add name=LAN-POOL ranges=192.168.10.10-192.168.10.100
/ip dhcp-server add name=DHCP-LAN interface=ether2 address-pool=LAN-POOL disabled=no
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=192.168.10.1
```

**Penting:** Saat mengulang lab, pastikan lease time `30m` memang sesuai setting aktual; parameter tersebut tercatat pada hasil final tetapi tidak dituliskan di baris command `add` sumber. Periksa juga apakah server yang sudah ada perlu diedit alih-alih membuat duplikat.

Pemeriksaan:

```routeros
/ip pool print
/ip dhcp-server print detail
/ip dhcp-server network print
/ip dhcp-server lease print detail
/ip dhcp-client print detail
```

## 5. Penjelasan DORA, lease, gateway, dan DNS

```text
PC1                         DHCP-LAN (HQ)
 | -- DISCOVER (mencari) ------> |
 | <-- OFFER (menawarkan IP) -- |
 | -- REQUEST (meminta IP) ---> |
 | <-- ACK (menetapkan lease) - |
```

Pada akhir DORA, catatan lease menunjukkan:

| Properti | Nilai |
|---|---|
| Address | `192.168.10.100` |
| MAC | `00:50:79:66:68:00` |
| Hostname | `PC1` |
| DHCP Server | `DHCP-LAN` |
| Status | `bound` |
| Lease time | `30m` |

**Lease** merupakan alokasi alamat IP dengan periode masa berlaku yang dapat diperbarui; bukan sekadar durasi perangkat terhubung ke jaringan.

**Gateway `192.168.10.1`:** titik keluar PC1 saat mengirim traffic ke jaringan lain. **DNS `192.168.10.1`:** alamat yang diberikan untuk resolusi nama. RouterOS baru bisa melayani query DNS client jika fitur DNS-nya memang dikonfigurasi sesuai kebutuhan, misalnya mengizinkan remote requests dan memiliki resolver/upstream yang sesuai. Pemberian IP DNS via DHCP **bukan bukti** DNS sudah bisa melakukan resolusi publik.

## 6. Hubungan DHCP, routing dan NAT

**Pada PC1:** DHCP memberi IP, mask, gateway, dan DNS. **Pada HQ ether3:** DHCP Client memperoleh IP WAN dan gateway dari ISP. Gateway WAN tersebut dapat membentuk default route dinamis.

```text
PC1 lease DHCP → Gateway LAN HQ → Route di HQ → Masquerade di WAN → ISP simulasi
```

`RUNNING` pada interface hanya menunjukkan link aktif, **tidak sama** dengan DHCP Client `bound`. Jika WAN DHCP `searching...`, gateway dinamis dan default route dari DHCP mungkin belum tersedia.

NAT HQ pada lab ini:

```text
chain=srcnat, action=masquerade, out-interface=ether3
```

Traffic yang cocok dapat memakai alamat WAN HQ sebagai source setelah masquerade. NAT tidak menggantikan kebutuhan ISP memiliki route ke destination berikutnya.

## 7. Validasi dan batas konektivitas

| Pemeriksaan | Evidence dalam sumber | Status |
|---|---|---|
| DHCP PC1 | IP `192.168.10.100/24`, GW/DNS `192.168.10.1`, server `192.168.10.1` | PASS |
| DHCP Lease HQ | `bound`, `DHCP-LAN`, PC1 | PASS |
| PC1 → gateway HQ | Ping `192.168.10.1` | PASS |
| PC1 → ISP virtual | Ping `192.168.100.1` | PASS |
| NAT HQ | Counter meningkat saat testing | PASS untuk rule match |
| PC1 → `8.8.8.8` | Ping gagal; ISP tanpa upstream | FAIL untuk Internet publik, bukan DHCP |

**Interpretasi:** Berhasil mencapai ISP virtual tidak berarti berhasil mencapai Internet. Kegagalan ping ke `8.8.8.8` tidak dapat diatasi hanya dengan memperbaiki DHCP jika masalahnya ada pada route/upstream ISP.

## 8. Studi kasus troubleshooting

| Masalah | Evidence / dugaan yang dicatat | Perbaikan atau pelajaran |
|---|---|---|
| Salah ketik DHCP Pool | `102.168.10.10–102.168.10.100` | Dikoreksi ke `192.168.10.10–192.168.10.100`. Command sukses ≠ konfigurasi benar |
| Salah gateway DHCP Network | `192.168.0.101` | Dikoreksi menjadi `192.168.10.1`, gateway yang benar di subnet PC1 |
| PC1 gagal mendapat DHCP | Sempat dibuat rule firewall sementara; kemudian dihapus | Rule tersebut **bukan** solusi final. Counter firewall saja tidak membuktikan root cause |
| WAN HQ `searching...` | ISP `ether2` sempat tidak `RUNNING`; default route dinamis hilang | Sesudah kondisi link/state normal, DHCP kembali `bound`. Periksa asal dynamic route |
| Ping Internet gagal | LAN, DHCP, HQ→ISP, NAT bekerja; ISP tanpa default route/upstream | Bedakan masalah WAN upstream dari masalah DHCP LAN |

**Urutan diagnosis yang dipakai sebagai panduan:**

```text
Link → Interface → IP → ARP → Route → Firewall → NAT → Connection tracking → Upstream
```

Jangan menuduh GNS3 atau firewall sebagai root cause tanpa bukti yang dapat diuji.

## 9. Backup, evidence, dan assessment

**Backup yang dicatat:** `LAB-05.backup`. Tidak ada export `.rsc` yang terkonfirmasi pada README asli. Hindari mengunggah backup binary ke GitHub publik; simpan privat dan sanitasi export sebelum diunggah.

Screenshot yang dicatat sebagai evidence:

```text
evidence/
├── 01-dhcp-pool.png
├── 02-dhcp-server.png
├── 03-dhcp-network.png
├── 04-pc1-show-ip.png
├── 05-dhcp-lease.png
├── 06-connectivity-test.png
└── 07-routing.png
```

**Assessment:** awal **64/100**, remedial **PASS**. Nilai remedial numerik tidak dicantumkan, sehingga tidak diasumsikan.

Pelajaran assessment: lease ≠ lama online; gateway ≠ DNS; IP ping tidak memerlukan DNS; NAT counter bukan bukti Internet sukses; DHCP `searching` dapat menyebabkan dynamic default route tidak tersedia.

## 10. Learning outcome

Saya kini dapat menjelaskan hubungan **Pool → Server → Network → Lease**, mengonfigurasi DHCP LAN, memeriksa assignment dari sisi client dan router, serta menyusun investigasi saat client tidak memperoleh IP atau tidak mencapai Internet. Saya belajar bahwa konfigurasi harus diverifikasi dari nilai aktual, bukan hanya dari keberhasilan mengeksekusi command.

**Pertanyaan review mandiri:** Apa beda DHCP pool dan DHCP network? Mengapa `bound` penting? Apakah `192.168.10.1` otomatis menjadi DNS resolver hanya karena dibagikan melalui DHCP? Mengapa interface RUNNING tidak menjamin default route tersedia? Mengapa ping IP publik gagal walau DHCP PC1 PASS?

**Kesimpulan:** LAB-05 **PASS setelah remedial**, dengan DHCP LAN berjalan; koneksi Internet publik tetap **tidak tersedia** karena batas upstream ISP simulasi.

---

## Catatan Audit dan Kesinambungan (Oktober 2026)

> **Catatan kesinambungan project (25 Oktober 2026):** Roadmap yang benar-benar dijalankan adalah LAB01 RouterOS Foundation, LAB02 WAN/DHCP Client, LAB03 NAT, LAB04 Firewall, LAB05 DHCP Server LAN, dan LAB06 Static Routing HQ–BRANCH. LAB07 Network Troubleshooting **dihentikan sebelum selesai** dan LAB08 Backup/Restore **dibatalkan** atas keputusan pemilik project. Tahap berikutnya adalah **Final Project — Small Office Network Integration**. Perubahan ini tidak mengubah hasil historis lab ini.

### Perubahan addressing antar-lab

PC1 menggunakan **IP statis `192.168.10.10/24`** pada LAB01–LAB04 dan baru memakai **DHCP `192.168.10.100/24`** pada LAB05. Pada LAB06, DHCP LAN HQ tetap dipakai dan ditambahkan DHCP Server untuk PC2 pada `192.168.20.0/24` di BRANCH. Jangan menggabungkan screenshot konfigurasi PC1 dari waktu yang berbeda seolah-olah diambil pada satu kondisi.

**Batas pengujian DNS:** DHCP memberikan alamat DNS `192.168.10.1` kepada PC1, namun hal ini **tidak otomatis membuktikan** RouterOS menerima query DNS dari client atau memiliki akses DNS publik yang berfungsi.

**Batas bukti DORA:** Lease `bound` menunjukkan hasil DHCP berhasil; urutan paket Discover/Offer/Request/Ack dijelaskan sebagai konsep. README tidak menyertakan packet capture terpisah yang membuktikan setiap langkah DORA diamati satu per satu.
