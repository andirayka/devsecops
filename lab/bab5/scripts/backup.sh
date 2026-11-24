#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE_DIR"

if [[ ! -f .env ]]; then
  echo "GAGAL: .env tidak ditemukan. Jalankan scripts/create-env.sh." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

mkdir -p backup
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
dump_file="backup/${POSTGRES_DB}-${timestamp}.dump"
temporary_file="${dump_file}.tmp"
checksum_file="${dump_file}.sha256"
trap 'rm -f "$temporary_file"' EXIT

docker compose exec -T postgres-db \
  pg_dump \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --format custom \
  --no-owner \
  --no-privileges \
  > "$temporary_file"

if [[ ! -s "$temporary_file" ]]; then
  echo "GAGAL: pg_dump tidak menghasilkan file." >&2
  exit 1
fi

mv "$temporary_file" "$dump_file"
if command -v shasum >/dev/null 2>&1; then
  checksum="$(shasum -a 256 "$dump_file" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  checksum="$(sha256sum "$dump_file" | awk '{print $1}')"
else
  echo "GAGAL: shasum atau sha256sum diperlukan untuk menghitung checksum." >&2
  exit 2
fi
printf '%s  %s\n' "$checksum" "$dump_file" > "$checksum_file"

echo "[PASS] Backup: $dump_file ($(wc -c < "$dump_file" | tr -d ' ') byte)"
echo "[PASS] SHA-256: $checksum_file"
