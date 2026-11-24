# Lab Bab 7 — Monitoring Resource (Prometheus, cAdvisor, Node Exporter, Grafana)

Stack monitoring untuk laporan Bab 7, diadaptasi dari cheatsheet Bab 7 dosen
(`materi/cheatsheets/bab-07-cs.md`). Berkas kerja milik Andi; bukti eksekusi
ada di `evidence/bab7/`.

## Isi

| Berkas | Fungsi |
| --- | --- |
| `compose.yaml` | Prometheus, Grafana, Node Exporter, cAdvisor, dan generator beban (`profile: load`) |
| `prometheus/prometheus.yml` | Interval scrape dan target |
| `prometheus/rules/*.yml` | Recording rules dan alert rules |
| `prometheus/tests/rules.test.yml` | Unit test alert `TargetDown` |
| `grafana/provisioning/` | Datasource Prometheus (dan PostgreSQL opsional) + provider dashboard |
| `grafana/dashboards/bab-7-overview.json` | Dashboard resource |
| `scripts/create-env.sh` | Membuat `.env` dengan password acak (mode 600) |
| `scripts/verify-stack.sh` | Verifikasi endpoint, target, rule, dan PromQL |
| `scripts/connect-bab6.sh` | Integrasi opsional log PostgreSQL Bab 6 (perlu stack Bab 6) |

## Menjalankan

```bash
./scripts/create-env.sh          # membuat .env lokal (mode 600), di-ignore git
docker compose pull
docker compose up -d
docker compose ps
./scripts/verify-stack.sh
```

Antarmuka lokal: Prometheus `http://127.0.0.1:9090`, Grafana
`http://127.0.0.1:3000` (dashboard folder **DevSecOps Lab**). Hanya dua
antarmuka itu yang dipublikasikan ke loopback; endpoint exporter tidak
dipublikasikan ke host.

## Adaptasi dari cheatsheet

- `scripts/verify-stack.sh` aslinya memeriksa target segera setelah Prometheus
  siap, padahal target masih `unknown` sebelum scrape pertama (interval 15 detik)
  selesai. Skrip di sini menunggu hingga minimal tiga target berstatus `up`
  sebelum melanjutkan.
- `name: andi-devsecops-bab7` ditambahkan pada `compose.yaml` agar nama proyek
  konsisten dengan lab lain.
- `.env.example` memakai placeholder; `scripts/create-env.sh` membangkitkan
  password acak dan tidak pernah menyimpan credential nyata di repo.

## Catatan keamanan

cAdvisor berjalan `privileged: true` agar dapat membaca metadata runtime
container. Ini pengecualian berisiko yang hanya boleh dipakai pada laptop lab
terisolasi, bukan pada host produksi atau mesin dengan data sensitif.
