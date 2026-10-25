# LAB-04 — Firewall Fundamentals

**MikroTik MTCNA Home Lab · Junior Network Engineer Portfolio**  
**Status:** PASS · **Fokus:** Stateful firewall, chain `input`/`forward`/`output`, rule order, NAT integration

> **Catatan dokumentasi:** README ini disusun dari catatan praktik asli. Command verifikasi merupakan referensi untuk mengulang pemeriksaan; tidak semua command dinyatakan telah dijalankan ketika lab berlangsung. Nama interface dan nilai IP mengikuti evidence pada lab ini, bukan template untuk topologi lain.


## Daftar Isi

1. [Ringkasan](#1-ringkasan)
2. [Tujuan](#2-tujuan)
3. [Topologi dan IP](#3-topologi-dan-ip)
4. [Teori firewall dan packet flow](#4-teori-firewall-dan-packet-flow)
5. [Kebijakan final](#5-kebijakan-final)
6. [Verifikasi](#6-verifikasi)
7. [Troubleshooting](#7-troubleshooting)
8. [Backup dan evidence](#8-backup-dan-evidence)
9. [Learning outcome](#9-learning-outcome)

## 1. Ringkasan

LAB04 menerapkan **basic stateful firewall** pada CHR-HQ-1. Kebijakan ini membatasi koneksi baru ke router dan koneksi yang diteruskan, namun tetap mengizinkan LAN menuju WAN serta balasan untuk koneksi yang sudah ada. Validasi menunjukkan layanan management, LAN, WAN, dan NAT LAB03 tetap berjalan.

## 2. Tujuan

- Membedakan chain `input`, `forward`, dan `output`.
- Memahami action `accept`, `drop`, `log` dan urutan rule.
- Memahami connection state `new`, `established`, `related`, `invalid`.
- Menerapkan allow rule untuk traffic yang memang diperlukan dan drop untuk traffic baru lainnya.
- Memastikan firewall baru tidak mengganggu akses management dan NAT.

## 3. Topologi dan IP

```text
Management PC ── host-only ── ether1 [CHR-HQ-1]
PC1 ── ether2 (LAN) ──────── [CHR-HQ-1] ether3 (WAN) ── CHR-ISP-1
```

| Perangkat | Interface | IP Address | Fungsi |
|---|---|---|---|
| CHR-ISP-1 | ether1 | `192.168.56.109/24` | Management |
| CHR-ISP-1 | ether2 | `192.168.100.1/24` | ISP virtual |
| CHR-HQ-1 | ether1 | `192.168.56.108/24` | Management |
| CHR-HQ-1 | ether2 | `192.168.10.1/24` | LAN gateway |
| CHR-HQ-1 | ether3 | `192.168.100.254/24` | WAN |
| PC1 | Ethernet | `192.168.10.10/24` | GW `192.168.10.1` |

## 4. Teori firewall dan packet flow

| Chain | Traffic | Contoh pada lab |
|---|---|---|
| `input` | Paket **menuju** router HQ | PC1 ping `192.168.10.1` |
| `forward` | Paket **melewati** HQ | PC1 ping ISP `192.168.100.1` |
| `output` | Paket **dibuat** oleh HQ | HQ ping ISP `192.168.100.1` |

Connection state membantu membuat kebijakan **stateful**:

- `new`: koneksi/traffic baru yang belum menjadi bagian koneksi established.
- `established`: traffic pada koneksi yang sudah teridentifikasi.
- `related`: koneksi yang terkait dengan koneksi lain.
- `invalid`: traffic yang tidak dapat dilacak secara valid oleh connection tracking.

> **Perhatikan:** Rule diproses dari atas ke bawah **di dalam chain yang sesuai**. Rule `input` tidak otomatis menyaring traffic `forward`. Action `log` mencatat paket lalu pemrosesan dapat berlanjut; ia bukan pengganti `drop`.

## 5. Kebijakan final

Urutan berikut disalin dari README sumber sebagai **urutan konfigurasi yang terdokumentasi**, bukan command siap tempel:

| No. | Chain | Match utama | Action | Alasan |
|---:|---|---|---|---|
| 0 | input | `connection-state=invalid` | drop | Abaikan invalid ke router |
| 1 | forward | `connection-state=invalid` | drop | Abaikan invalid melewati router |
| 2 | input | `established,related` | accept | Izinkan traffic balasan ke router |
| 3 | forward | `established,related` | accept | Izinkan return traffic lintas router |
| 4 | forward | `src-address=192.168.10.0/24`, `out-interface=ether3`, `new` | accept | LAN → WAN |
| 5 | forward | `new` | drop | Tolak new forward lain |
| 6 | input | `src-address=192.168.56.0/24`, `new` | accept | Management network |
| 7 | input | `src-address=192.168.10.0/24`, `protocol=icmp` | accept | Ping LAN ke router |
| 8 | input | `new` | drop | Tolak new input lain |

**Catatan keamanan:** Rule management berdasarkan `src-address` saja mencerminkan lab aslinya; ini bukan template keamanan siap produksi. Pada implementasi nyata perlu meninjau interface sumber, layanan management yang diperlukan, dan akses admin. Jika firewall yang sudah aktif hendak diubah, gunakan WinBox Safe Mode atau mekanisme rollback untuk mengurangi risiko terputus dari router.

**Command inspeksi:**

```routeros
/ip firewall filter print detail
/ip firewall filter print stats
/ip firewall nat print stats
/ip firewall connection print
```

## 6. Verifikasi

| Pengujian dari dokumentasi | Hasil |
|---|---|
| PC1 → gateway HQ `192.168.10.1` | PASS |
| PC1 → ISP `192.168.100.1` | PASS |
| Management `192.168.56.106 → 192.168.56.108` | PASS |
| HQ → ISP `192.168.100.1` | PASS |
| Counter filter `accept` dan `drop` | Traffic cocok dengan rule |
| NAT counter `40 → 45 packets` | Masquerade tetap digunakan |

**Interpretasi:** Pengujian mengonfirmasi traffic yang diperlukan tetap diteruskan. Counter menunjukkan aktivitas rule, tetapi untuk membuktikan sebuah kebijakan `drop` secara spesifik, cocokkan juga dengan pengujian traffic yang ditolak dan posisi rule.

## 7. Troubleshooting

**Gejala:** DHCP Client WAN `ether3` HQ menunjukkan `searching...`, walaupun DHCP Server ISP aktif. Interface terlihat `RUNNING`, sementara lease ISP kosong.

**Tindakan tercatat:** Setelah restart GNS3, DHCP Client kembali `bound` dengan `192.168.100.254/24`.

**Makna diagnosis:** Status link `RUNNING` tidak berarti DHCP berhasil memperoleh lease. Catatan sumber menunjukkan koneksi pulih setelah restart, tetapi **akar penyebab definitif belum dibuktikan**. Karena itu pemeriksaan tetap dimulai dari status link, interface, DHCP, addressing, route, lalu firewall/NAT.

```text
LINK → INTERFACE → DHCP LEASE → IP → ARP → ROUTING → FIREWALL → NAT
```

## 8. Backup dan evidence

Backup sumber: `LAB-04.backup`, terverifikasi melalui `/file print`, ukuran tercatat **23.8 KiB**. Export `.rsc` tidak disebutkan sebagai file yang telah diverifikasi di sumber—jangan klaim tersedia tanpa pengecekan.

Screenshot yang dicatat:

```text
evidence/
├── 01-topology.png
├── 02-ip-address.png
├── 03-routing.png
├── 04-firewall-rules.png
├── 05-firewall-counters.png
├── 06-nat-counters.png
├── 07-connectivity-test.png
└── 08-backup.png
```

## 9. Learning outcome

Saya memahami mengapa `input` berbeda dari `forward`, bagaimana connection tracking memungkinkan traffic balasan tanpa membuka seluruh koneksi baru, dan mengapa rule order harus diperiksa sebelum menyimpulkan apakah sebuah paket akan diterima atau dibuang. Saya juga belajar bahwa NAT dan firewall adalah fungsi berbeda yang harus diverifikasi bersama.

**Pertanyaan review mandiri:** Apa yang terjadi jika drop `new` forward ditempatkan sebelum allow LAN→WAN? Mengapa ping yang dijalankan dari router tidak diuji melalui `forward`? Mengapa `established,related` biasanya diterima lebih awal? Apa batas interpretasi firewall counter?

**Kesimpulan:** LAB-04 **PASS** berdasarkan evidence LAN, WAN, management, rule counter dan NAT yang tetap bekerja.

---

## Catatan Audit dan Kesinambungan (Oktober 2026)

> **Catatan kesinambungan project (25 Oktober 2026):** Roadmap yang benar-benar dijalankan adalah LAB01 RouterOS Foundation, LAB02 WAN/DHCP Client, LAB03 NAT, LAB04 Firewall, LAB05 DHCP Server LAN, dan LAB06 Static Routing HQ–BRANCH. LAB07 Network Troubleshooting **dihentikan sebelum selesai** dan LAB08 Backup/Restore **dibatalkan** atas keputusan pemilik project. Tahap berikutnya adalah **Final Project — Small Office Network Integration**. Perubahan ini tidak mengubah hasil historis lab ini.

### Evolusi firewall pada LAB06

Rule yang tercantum di sini merupakan **baseline LAB04**. Ketika BRANCH (`192.168.20.0/24`) ditambahkan pada LAB06, HQ memerlukan rule `forward` yang menerima koneksi baru dari BRANCH menuju LAN HQ, ditempatkan **sebelum** rule umum `drop` untuk koneksi `new`. Jadi rule list LAB04 memang dapat berbeda dari firewall pada topologi final LAB06.

Daftar filter di sini mengatur traffic berdasarkan chain. Urutan nomor global tidak berarti paket melintasi semua chain: paket `input` tidak diproses sebagai `forward`.
