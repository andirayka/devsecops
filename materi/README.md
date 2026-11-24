# Materi Dosen (Bab 5–7)

Materi ajar di folder ini berasal dari repo publik dosen pengampu,
[`ferryas-pens/devsecops`](https://github.com/ferryas-pens/devsecops)
(remote Git lokal bernama `ferry`), yang dipecah per bab dari buku ajar
*Buku Tutorial DevSecOps Praktis Berbasis Docker*.

## Isi

| Berkas | Isi |
| --- | --- |
| `bab-05.md` | Materi Bab 5 — Database Service di Docker: PostgreSQL |
| `bab-06.md` | Materi Bab 6 — Centralized Logging dengan Fluent Bit dan PostgreSQL |
| `bab-07.md` | Materi Bab 7 — Monitoring Resource: Prometheus, cAdvisor, Node Exporter, Grafana |
| `cheatsheets/bab-05-cs.md` | Cheatsheet lab Bab 5 (PostgreSQL, pgAdmin, backup, restore) |
| `cheatsheets/bab-06-cs.md` | Cheatsheet lab Bab 6 (Fluent Bit, PostgreSQL JSONB) |
| `cheatsheets/bab-07-cs.md` | Cheatsheet lab Bab 7 (Prometheus, Grafana, alert) |
| `assets/` | Diagram arsitektur Bab 5–7 dari materi sumber |

## Penggunaan

Materi ini adalah rujukan, bukan bukti praktikum. Pekerjaan Andi untuk tiap
bab tetap berada di `lab/babN/` (berkas kerja), `evidence/babN/` (bukti yang
dibuat sendiri), dan `chapters/babN.md` (laporan). Jangan menyalin bukti dari
materi ini ke `evidence/`.

## Catatan

- Berkas disalin dari `ferry/main` (commit `8bb8bde`) tanpa menimpa pekerjaan
  Andi; kedua repo tidak berbagi riwayat commit.
- Nilai password sintetis pada contoh `.env`/konfigurasi diganti menjadi
  placeholder `REPLACE_WITH_A_LAB_PASSWORD` agar repo tidak memuat
  credential yang terlihat seperti rahasia. Contoh lain dibiarkan sesuai asli.
- Repo sumber memuat materi Bab 1–17; hanya Bab 5–7 yang dibawa ke sini karena
  sesuai ruang lingkup pekerjaan saat ini.
