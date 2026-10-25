# MikroTik MTCNA Home Labs — Junior Network Engineer Journey

> **Hands-on networking practice using MikroTik RouterOS, GNS3, and VirtualBox.**  
> Dokumentasi pembelajaran MTCNA fundamentals melalui konfigurasi, pengujian, dan troubleshooting pada lingkungan jaringan virtual.

## Overview

Repository ini berisi dokumentasi **enam home lab MikroTik** yang saya kerjakan untuk mengulang dan memperkuat konsep dasar **MikroTik Certified Network Associate (MTCNA)** serta membangun portofolio menuju peran **Junior Network Engineer**.

Saya menggunakan pendekatan **learn → configure → verify → troubleshoot → document**. Setiap lab mencatat tujuan, topologi, konfigurasi, alasan teknis, hasil pengujian, dan pelajaran yang saya dapatkan. README tiap lab juga berfungsi sebagai bahan belajar ulang.

> **Scope:** Repository ini adalah *home lab* berbasis simulasi, bukan klaim implementasi produksi atau penguasaan seluruh silabus MTCNA.

## Lab Environment

| Tool | Function |
|---|---|
| **GNS3** | Mendesain topologi serta menghubungkan node virtual |
| **MikroTik CHR / RouterOS** | Router untuk addressing, DHCP, NAT, firewall, dan routing |
| **Oracle VirtualBox** | Mendukung virtualisasi dan jaringan host-only untuk management |
| **WinBox** | Administrasi dan inspeksi RouterOS |
| **VPCS** | Simulasi client untuk pengujian IP connectivity |

## Learning Roadmap

| Lab | Topic | Skills demonstrated | Status |
|---|---|---|---|
| [LAB-01 — RouterOS Foundation](LAB-01%20RouterOS%20Foundation/) | Interface & IPv4 addressing | LAN setup, subnet, connected route, ICMP | Completed |
| [LAB-02 — WAN & DHCP Client](LAB-02%20WAN%20%26%20DHCP%20Client/) | Simulated ISP & dynamic WAN | DHCP Client, WAN lease, default route, DNS simulation | Completed |
| [LAB-03 — NAT & Internet Access](LAB-03%20NAT%20%26%20Internet%20Access/) | Source NAT | Masquerade, NAT counter, connection tracking | Completed* |
| [LAB-04 — Firewall Fundamental](LAB-04%20Firewall%20Fundamental/) | Stateful filtering | Input/forward/output, connection states, rule order | Completed |
| [LAB-05 — DHCP Server & LAN Client Management](LAB-05%20DHCP%20Server%20%26%20LAN%20Client%20Management/) | Dynamic LAN addressing | DHCP pool, network, lease, DORA, troubleshooting | Completed |
| [LAB-06 — Routing Fundamental](LAB-06%20Routing%20Fundamental/) | HQ–BRANCH integration | Static routes, firewall forward policy, NAT exemption, bidirectional testing | Technical PASS |

*LAB-03 memverifikasi **NAT dan konektivitas menuju ISP simulasi**, bukan akses Internet publik. ISP pada topologi ini tidak memiliki upstream Internet sungguhan.*

**Next milestone:** Final Project — Small Office Network Integration, sebagai implementasi terintegrasi dari materi yang telah dipelajari.

## Network Evolution

### Foundation: LAB-01 hingga LAB-05

```text
Laptop / WinBox (Host-Only management)
            |
         CHR-HQ-1
         /      \
   LAN ether2   WAN ether3 (DHCP Client)
       |               |
      PC1         CHR-ISP-1
 192.168.10.0/24  192.168.100.0/24
```

Perkembangan konfigurasi dari lab awal hingga LAB-05 mencakup:

- IP statis PC1 untuk pengujian LAN awal.
- DHCP Client WAN HQ untuk memperoleh IP dinamis dan default route.
- Source NAT masquerade pada interface WAN HQ.
- Basic stateful firewall pada HQ.
- DHCP Server LAN HQ; PC1 kemudian memperoleh IP melalui DHCP.

### Multi-site routing: LAB-06

```text
                  CHR-ISP-1
                 192.168.100.1
                       |
                     Switch
                    /      \
                   /        \
             CHR-HQ-1      CHR-BRANCH-1
           WAN .254*       WAN .253
               |              |
            HQ LAN         BRANCH LAN
        192.168.10.0/24  192.168.20.0/24
               |              |
              PC1            PC2
```

Kedua router berbagi subnet transit `192.168.100.0/24` pada switch Layer 2. Karena itu, komunikasi HQ–BRANCH tidak harus melewati router ISP. HQ menggunakan WAN DHCP dengan alamat `.254` **yang teramati pada pengujian**, sehingga alamat itu tidak dijamin tetap sama setelah lease berubah.

Pada LAB-06, kedua LAN dihubungkan menggunakan static route dua arah, disertai penyesuaian firewall `forward` dan NAT exemption di HQ. **Ping PC1 → PC2 dan PC2 → PC1 berhasil, masing-masing 10/10 balasan** pada pengujian akhir. LAB-06 dinyatakan *Technical PASS*; assessment akhir formal dan kelengkapan backup/export tidak boleh diasumsikan selesai tanpa evidence.

## How to Read This Repository

Setiap folder LAB-01 hingga LAB-06 memiliki `README.md` yang menjelaskan tujuan, topologi, konfigurasi, hasil pengujian, troubleshooting, dan pembelajaran dari lab tersebut.

File pendukung **diletakkan langsung di dalam folder masing-masing lab**, tanpa pemisahan folder `screenshots/`, `evidence/`, atau `configs/`. Isinya dapat berupa:

- **Screenshot** topologi GNS3, IP addressing, routing, DHCP, firewall, NAT, dan hasil ping.
- **Export RouterOS (`.rsc`)**, jika tersedia, untuk membaca kembali konfigurasi.
- **Backup RouterOS (`.backup`)**, jika tersedia, untuk kebutuhan pemulihan pada lingkungan yang kompatibel.
- **Handoff note** atau catatan pendukung yang merekam kelanjutan pekerjaan.

Contoh susunan file dalam salah satu folder lab:

```text
LAB-04 Firewall Fundamental/
├── README.md
├── Topology.png
├── IP Address.png
├── Routing Table.png
├── Firewall Filter.png
├── Firewall Filter Stats.png
├── Firewall NAT Stats.png
├── PC1 Connectivity Validation.png
├── LAB-04.rsc
├── LAB-04.backup
└── Handoff.md
```

> Contoh di atas menggambarkan **cara penyimpanan file**, bukan daftar file yang wajib ada pada setiap lab. Nama dan jumlah berkas dapat berbeda. Mulai dari LAB-01 untuk mengikuti pembelajaran berurutan, atau langsung buka LAB-06 untuk melihat implementasi routing HQ–BRANCH.

**Catatan verifikasi:** Screenshot dan konfigurasi hanya dianggap sebagai evidence jika memang tersedia. Command contoh di README tidak selalu berarti command tersebut dijalankan persis sama dalam praktik asli.

## Important Technical Boundaries

1. **Simulated ISP ≠ public Internet.** Ping ke ISP virtual, NAT counter, dan default route tidak otomatis membuktikan koneksi Internet publik.
2. **Dynamic WAN IP may change.** Static route di BRANCH yang menunjuk IP WAN HQ harus ditinjau apabila lease HQ berubah.
3. **Ping success has limits.** Hasil ICMP yang berhasil menunjukkan connectivity pada pengujian tersebut, bukan jaminan seluruh layanan berjalan.
4. **Security first.** Binary RouterOS `.backup` tidak disarankan untuk repository publik. Periksa dan sanitasi `.rsc`, screenshot, kredensial, dan detail lingkungan sebelum mengunggahnya.

## Final Project — Small Office Network Integration

Tahap berikutnya adalah **Final Project: Small Office Network Integration**, yaitu penerapan terintegrasi berdasarkan pembelajaran LAB-01–LAB-06. Proyek akhir berfokus pada desain HQ–BRANCH, addressing, DHCP, routing, NAT, firewall, verifikasi, troubleshooting yang terdokumentasi, dan prosedur backup.

Final Project akan ditempatkan pada **repository tersendiri** agar dokumentasi proses belajar di sini tetap terpisah dari deliverable portofolio akhir. Tautan repository Final Project akan ditambahkan **setelah repository tersebut dibuat**.

## Portfolio Purpose

Repository ini dibuat sebagai:

- Catatan belajar yang bisa saya kunjungi kembali untuk mengingat konsep MTCNA.
- Bukti praktik konfigurasi dan verifikasi RouterOS pada lingkungan virtual.
- Dokumentasi perkembangan troubleshooting dan cara berpikir berdasarkan evidence.
- Materi pendukung portofolio GitHub, CV, dan LinkedIn untuk posisi Junior Network Engineer.

---

**Current status:** LAB-01–LAB-06 documented · Final Project — Small Office Network Integration is the next milestone.

*Created as a personal networking learning journey. Feedback and technical corrections are welcome.*
