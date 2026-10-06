#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"
mkdir -p certs

if [[ ! -s certs/lab.key && ! -s certs/lab.crt ]]; then
  umask 077
  openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 365 \
    -keyout certs/lab.key \
    -out certs/lab.crt \
    -subj "/CN=localhost/O=PENS DevSecOps Lab Bab 4" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" >/dev/null 2>&1
elif [[ ! -s certs/lab.key || ! -s certs/lab.crt ]]; then
  echo "FAIL: hanya salah satu berkas sertifikat/kunci tersedia; periksa pasangan lokal sebelum melanjutkan." >&2
  exit 2
fi

chmod 600 certs/lab.key
chmod 644 certs/lab.crt
openssl pkey -in certs/lab.key -noout >/dev/null
openssl x509 -in certs/lab.crt -noout >/dev/null

key_mode="$(stat -f '%Lp' certs/lab.key)"
if [[ "$key_mode" != "600" ]]; then
  echo "FAIL: mode private key harus 600, ditemukan $key_mode." >&2
  exit 1
fi
printf 'Self-signed certificate siap; mode private key=%s (isi kunci tidak ditampilkan).\n' "$key_mode"
openssl x509 -in certs/lab.crt -noout -subject -dates -ext subjectAltName
