# Laporan Praktikum DevSecOps Bab 1–7

> **Status:** praktikum runtime Bab 1–7 lulus. Tujuh PDF per bab yang dipublikasikan lulus verifikasi overlap dan pemeriksaan visual. Bab 5 dipulihkan dari branch `tugas-bab-5`; Bab 6 dan Bab 7 dikerjakan berdasarkan materi dosen Pak Ferry (repo `ferryas-pens/devsecops`).

## Identitas

- **Nama:** Andi Rayka C
- **NRP:** 3126640005
- **Kelas:** D4 LJ Informatika
- **Program studi:** LJ-D4 Teknik Informatika
- **Institusi:** Politeknik Elektronika Negeri Surabaya (PENS)

## Cakupan bab

1. **Bab 1 — Fondasi Teoretis dan Kerangka Kerja:** konsep DevSecOps, pergeseran keamanan sepanjang siklus pengembangan, baseline laboratorium, threat modeling, dan evidence yang dapat diverifikasi.
2. **Bab 2 — Konsep Container dan Instalasi Docker:** perbedaan VM dan container, arsitektur Docker, instalasi/penggunaan Docker, container dasar, dan custom image.
3. **Bab 3 — Docker Network, Volume, Bind Mount, dan Compose:** DNS dan segmentasi jaringan, persistensi data, bind mount/tmpfs, serta orkestrasi multi-container dan healthcheck.
4. **Bab 4 — Web Service Container: Apache, Nginx, Reverse Proxy, dan TLS:** pemisahan layanan web/API, routing reverse proxy, TLS, pengamanan private key, dan pencatatan akses.
5. **Bab 5 — Database Service di Docker: PostgreSQL:** init script, named volume, constraint, healthcheck, backup/restore dengan pg_dump/pg_restore, dan pgAdmin.
6. **Bab 6 — Centralized Logging dengan Fluent Bit dan PostgreSQL:** Docker fluentd logging driver, penyimpanan JSONB, korelasi `request_id`, dan ketahanan pipeline saat database log mati.
7. **Bab 7 — Monitoring Resource: Prometheus, cAdvisor, Node Exporter, Grafana:** scrape metrics, recording/alert rule, dashboard Grafana, uji beban CPU, dan negative test alert `TargetDown`.

Topik ini mengikuti ruang lingkup praktikum. Hasil, klaim, dan kesimpulan setiap bab harus berasal dari pekerjaan serta verifikasi Andi sendiri.

## Materi dosen

Materi ajar Bab 5–7 dari Pak Ferry (repo `ferryas-pens/devsecops`) disalin ke
[`materi/`](materi/): naskah bab, cheatsheet lab, dan diagram arsitektur. Materi
ini rujukan; pekerjaan Andi tetap di `lab/babN/`, `evidence/babN/`, dan
`chapters/babN.md`.

## Aplikasi Axon Sales

Aplikasi UTS kelompok (Next.js + MySQL, CI/CD, SAST, DAST) ada di [`axon/`](axon/). Isinya berasal dari repo `andirayka/uts-devops` dan riwayat commit aslinya ikut tersimpan. Workflow GitHub Actions-nya ada di `.github/workflows/axon-*.yml`: CI berjalan saat `axon/**` berubah, sedangkan deploy ke VPS hanya lewat jalankan manual.

## Susunan folder

| Lokasi | Isi dan kegunaan |
| --- | --- |
| `chapters/bab1.md`–`chapters/bab7.md` | Sumber Markdown untuk generator. Build penuh memerlukan `bab1.md`–`bab4.md`; `--chapter` membangun satu bab saja (termasuk `bab5.md`–`bab7.md`). |
| `lab/babN/` | Berkas kerja tiap bab, misalnya konfigurasi dan kode/container praktikum. Simpan materi sesuai babnya. |
| `evidence/babN/` | Bukti milik Andi untuk bab terkait: tangkapan layar dan hasil pemeriksaan yang relevan. Jangan menaruh screenshot orang lain sebagai bukti. |
| `materi/` | Materi dosen Bab 5–7 (naskah bab, cheatsheet, diagram) dari `ferryas-pens/devsecops`. |
| `assets/` | Aset laporan, termasuk logo PENS yang sudah tersedia di `assets/logo-pens.png`. |
| `output/babN/` | Tujuh PDF per bab yang dihasilkan `build_report.py` dan dipublikasikan. |
| `output/` | Generator dapat menyimpan PDF gabungan lokal di sini; PDF gabungan sengaja diabaikan dan tidak masuk repo publik. |
| `renders/` | PNG hasil render verifier (default); artefak render lokal ini diabaikan oleh `.gitignore`. |

Folder `lab/` dan `evidence/` menyimpan konfigurasi serta bukti praktikum milik Andi. Hasil runtime dan hasil verifikasi PDF dicatat terpisah di bawah.

## Keluaran laporan

PDF yang dipublikasikan adalah tujuh laporan per bab:

| PDF | Halaman |
| --- | ---: |
| [Laporan Bab 1](output/bab1/3126640005_Andi.pdf) | 7 |
| [Laporan Bab 2](output/bab2/3126640005_Andi.pdf) | 6 |
| [Laporan Bab 3](output/bab3/3126640005_Andi.pdf) | 5 |
| [Laporan Bab 4](output/bab4/3126640005_Andi.pdf) | 4 |
| [Laporan Bab 5](output/bab5/3126640005_Andi.pdf) | 4 |
| [Laporan Bab 6](output/bab6/3126640005_Andi.pdf) | 5 |
| [Laporan Bab 7](output/bab7/3126640005_Andi.pdf) | 5 |

Total laporan per bab yang dipublikasikan adalah 36 halaman. Generator tetap mendukung keluaran gabungan sebagai artefak lokal, tetapi bukan bagian dari publikasi ini.

## Lingkungan dan port praktikum

Preflight lokal menemukan Docker Engine siap melalui **Colima dengan Ubuntu 24.04.4 LTS ARM64**. Perintah yang memerlukan lingkungan Linux harus dijalankan di VM tersebut, bukan dianggap berjalan pada kernel macOS host.

| Bab | Port host yang direncanakan |
| --- | --- |
| 2 | `18082` (Nginx) dan `19092` (custom web) |
| 3 | `18083` (web) |
| 4 | `18084` (HTTP) dan `18444` (HTTPS) |
| 5 | `15432` (PostgreSQL) dan `15050` (pgAdmin) |
| 6 | `18086` (portal) dan `24225` (Fluent Bit forward) |
| 7 | `9090` (Prometheus) dan `3000` (Grafana) |

Port Bab 5–7 hanya terikat ke loopback. Periksa ketersediaan port sebelum menjalankan stack. Pertahankan container atau stack pengguna yang sudah berjalan; jangan menghentikannya hanya untuk membebaskan port tanpa persetujuan.

## Persiapan dan build

`requirements.txt` menetapkan dependensi minimum berikut untuk generator ReportLab dan pemeriksaan/render PDF:

- `reportlab>=4.0`
- `pdfplumber>=0.11`
- `pypdfium2>=4.0`
- `Pillow>=10.0`

Contoh instalasi lokal dengan virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

Build penuh memerlukan `chapters/bab1.md` sampai `chapters/bab4.md` dan menghasilkan satu PDF per bab serta satu PDF gabungan lokal. Bab 5–7 dibangun mandiri dengan `--chapter`:

```bash
python3 build_report.py --help
python3 build_report.py
python3 build_report.py --chapter chapters/bab5.md
python3 build_report.py --chapter chapters/bab7.md
```

Opsi yang tersedia:

- `--chapters-dir PATH`: folder sumber bab (default `chapters/`).
- `--output-dir PATH`: folder keluaran PDF per bab dan keluaran gabungan default (default `output/`).
- `--output PATH`: lokasi khusus untuk PDF gabungan; PDF per bab tetap ditulis di `--output-dir`.
- `--chapter FILE`: membangun hanya satu file bab dan menulis PDF ke `--output-dir/babN/`; tidak dapat digunakan bersama `--output`.
- `--lecturer`, `--group`, `--academic-year`: metadata opsional. Isikan hanya data yang sudah dikonfirmasi.

Untuk struktur isi dan sintaks Markdown yang didukung generator, lihat [kontrak parser](PARSER_CONTRACT.md).

## Verifikasi PDF

Verifier memeriksa overlap teks-teks dan teks-gambar di atas `8 pt²`, lalu merender semua halaman ke PNG pada 120 dpi. Penggunaan yang tercantum di `verify_report.py`:

```bash
# Memeriksa PDF gabungan default dan menulis render ke renders/
python3 verify_report.py

# Contoh memeriksa satu PDF bab dengan folder render terpisah
python3 verify_report.py output/bab7/3126640005_Andi.pdf renders/bab7
```

Tujuh PDF per bab yang dipublikasikan lulus pemeriksaan overlap dengan ambang `8 pt²` dan seluruh halaman berhasil dirender. Render halaman diperiksa secara visual; tidak ditemukan overlap, clipping, atau glyph hitam.

## Referensi, provenance, dan privasi

- Jangan menyalin tangkapan layar, log, atau identitas dari laporan orang lain. Gunakan bukti praktikum yang dibuat sendiri, simpan di `evidence/babN/`, dan cantumkan sumber eksternal yang digunakan.
- Jangan unggah kredensial, token, `.env` berisi rahasia, private key, atau backup volume database. Git mengabaikan direktori `keys/`, `lab/**/backups/`, berkas `*.key`/`*.pem`, dan isi `secrets/`; hanya file `*.example` di dalam `secrets/` yang trackable. File contoh harus berisi placeholder/demo yang aman untuk publik, bukan password nyata. Berkas `*.raw.txt` dan artefak review lokal `/.amp/in/` juga diabaikan; tambahkan hanya evidence yang sudah disanitasi.
- Sertifikat publik berekstensi `.crt` atau `.cer` tidak diabaikan; verifikasi isinya sebelum dibagikan. Berkas `.pem` selalu diabaikan, termasuk jika berisi sertifikat publik.
- Periksa kembali screenshot/log agar tidak memuat data pribadi, alamat internal yang sensitif, atau rahasia sebelum menambahkannya ke repo publik.
