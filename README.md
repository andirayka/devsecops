# Laporan Praktikum DevSecOps Bab 1–5

> **Status:** praktikum Bab 1–5 lulus. Lima PDF per bab lulus verifikasi overlap dan pemeriksaan visual. Bab 5 memakai PostgreSQL 16, pgAdmin, volume persisten, serta uji backup dan restore.

## Identitas

- **Nama:** Andi Rayka C
- **NRP:** 3123640021
- **Kelas:** D4 LJ Informatika
- **Program studi:** LJ-D4 Teknik Informatika
- **Institusi:** Politeknik Elektronika Negeri Surabaya (PENS)

## Cakupan bab

1. **Bab 1 — Fondasi Teoretis dan Kerangka Kerja:** konsep DevSecOps, pergeseran keamanan sepanjang siklus pengembangan, baseline laboratorium, threat modeling, dan evidence yang dapat diverifikasi.
2. **Bab 2 — Konsep Container dan Instalasi Docker:** perbedaan VM dan container, arsitektur Docker, instalasi/penggunaan Docker, container dasar, dan custom image.
3. **Bab 3 — Docker Network, Volume, Bind Mount, dan Compose:** DNS dan segmentasi jaringan, persistensi data, bind mount/tmpfs, serta orkestrasi multi-container dan healthcheck.
4. **Bab 4 — Web Service Container: Apache, Nginx, Reverse Proxy, dan TLS:** pemisahan layanan web/API, routing reverse proxy, TLS, pengamanan private key, dan pencatatan akses.
5. **Bab 5 — Database Service di Docker: PostgreSQL:** PostgreSQL dan pgAdmin, init script, named volume, logical backup, checksum, dan restore ke database terpisah.

Topik ini mengikuti ruang lingkup praktikum. Hasil, klaim, dan kesimpulan setiap bab harus berasal dari pekerjaan serta verifikasi Andi sendiri.

## Susunan folder

| Lokasi | Isi dan kegunaan |
| --- | --- |
| `chapters/bab1.md`–`chapters/bab5.md` | Sumber Markdown untuk generator. Build penuh memerlukan kelima file tidak kosong; build satu bab hanya memerlukan file yang dipilih. |
| `lab/babN/` | Berkas kerja tiap bab, misalnya konfigurasi dan kode/container praktikum. Simpan materi sesuai babnya. |
| `evidence/babN/` | Bukti milik Andi untuk bab terkait: tangkapan layar dan hasil pemeriksaan yang relevan. Jangan menaruh screenshot orang lain sebagai bukti. |
| `assets/` | Aset laporan, termasuk logo PENS yang sudah tersedia di `assets/logo-pens.png`. |
| `output/babN/` | Lima PDF per bab yang dihasilkan `build_report.py` dan dipublikasikan. |
| `output/` | Generator dapat menyimpan PDF gabungan lokal di sini; PDF gabungan sengaja diabaikan dan tidak masuk repo publik. |
| `renders/` | PNG hasil render verifier (default); artefak render lokal ini diabaikan oleh `.gitignore`. |

Folder `lab/` dan `evidence/` menyimpan konfigurasi serta bukti praktikum milik Andi. Hasil runtime dan hasil verifikasi PDF dicatat terpisah di bawah.

## Keluaran laporan

PDF yang dipublikasikan adalah lima laporan per bab:

| PDF | Halaman |
| --- | ---: |
| [Laporan Bab 1](output/bab1/3123640021_Andi.pdf) | 7 |
| [Laporan Bab 2](output/bab2/3123640021_Andi.pdf) | 6 |
| [Laporan Bab 3](output/bab3/3123640021_Andi.pdf) | 5 |
| [Laporan Bab 4](output/bab4/3123640021_Andi.pdf) | 4 |
| [Laporan Bab 5](output/bab5/3123640021_Andi.pdf) | 4 |

Total laporan per bab yang dipublikasikan adalah 26 halaman. Generator tetap mendukung keluaran gabungan sebagai artefak lokal, tetapi bukan bagian dari publikasi ini.

## Lingkungan dan port praktikum

Preflight lokal menemukan Docker Engine siap melalui **Colima dengan Ubuntu 24.04.4 LTS ARM64**. Perintah yang memerlukan lingkungan Linux harus dijalankan di VM tersebut, bukan dianggap berjalan pada kernel macOS host.

Port Bab 2–4 berikut adalah **rencana pemetaan port host yang diadaptasi**, bukan hasil pengujian. Bab 5 sudah dijalankan dengan port loopback berikut:

| Bab | Port host |
| --- | --- |
| 2 | `18082` (Nginx) dan `19092` (custom web) |
| 3 | `18083` (web) |
| 4 | `18084` (HTTP) dan `18444` (HTTPS) |
| 5 | `127.0.0.1:15432` (PostgreSQL) dan `127.0.0.1:15050` (pgAdmin), hasil aktual |

Periksa ketersediaan port sebelum menjalankan stack. Pertahankan container atau stack pengguna yang sudah berjalan; jangan menghentikannya hanya untuk membebaskan port tanpa persetujuan.

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

Bantuan generator telah diperiksa melalui `python3 build_report.py --help`. Build penuh memerlukan `chapters/bab1.md` sampai `chapters/bab5.md` dan menghasilkan satu PDF per bab serta satu PDF gabungan lokal. PDF gabungan tidak dipublikasikan. Opsi `--chapter FILE` membangun satu bab saja tanpa memerlukan file bab lainnya:

```bash
python3 build_report.py --help
python3 build_report.py
python3 build_report.py --chapter chapters/bab2.md
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
python3 verify_report.py output/bab1/3123640021_Andi.pdf renders/bab1
```

PDF Bab 5 memiliki empat halaman. `python3 verify_report.py output/bab5/3123640021_Andi.pdf renders/bab5` lulus dengan nol overlap di atas `8 pt²` dan merender keempat halaman pada 120 dpi. Saya memeriksa setiap render. PDF mencakup cover, hasil runtime, lima jawaban evaluasi, latihan mandiri, dan daftar pustaka.

Kode verifier saat ini menerima path PDF dan folder render sebagai argumen posisi; `--help` belum tersedia pada verifier.

## Referensi, provenance, dan privasi

- Jangan menyalin tangkapan layar, log, atau identitas dari laporan orang lain. Gunakan bukti praktikum yang dibuat sendiri, simpan di `evidence/babN/`, dan cantumkan sumber eksternal yang digunakan.
- Jangan unggah kredensial, token, `.env` berisi rahasia, private key, atau backup volume database. Git mengabaikan direktori `keys/`, folder `lab/**/backup/` dan `lab/**/backups/`, berkas `*.key`/`*.pem`, dan isi `secrets/`; hanya file `*.example` di dalam `secrets/` yang trackable. File contoh harus berisi placeholder/demo yang aman untuk publik, bukan password nyata. Berkas `*.raw.txt` dan artefak review lokal `/.amp/in/` juga diabaikan; tambahkan hanya evidence yang sudah disanitasi.
- Sertifikat publik berekstensi `.crt` atau `.cer` tidak diabaikan; verifikasi isinya sebelum dibagikan. Berkas `.pem` selalu diabaikan, termasuk jika berisi sertifikat publik.
- Periksa kembali screenshot/log agar tidak memuat data pribadi, alamat internal yang sensitif, atau rahasia sebelum menambahkannya ke repo publik.
