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

dump_file="${1:-}"
if [[ -z "$dump_file" ]]; then
  echo "Penggunaan: scripts/restore-test.sh backup/nama-file.dump" >&2
  exit 2
fi
if [[ "$dump_file" != /* ]]; then
  dump_file="$BASE_DIR/$dump_file"
fi
if [[ ! -s "$dump_file" || ! -s "${dump_file}.sha256" ]]; then
  echo "GAGAL: dump atau file checksum tidak ditemukan." >&2
  exit 1
fi

expected_checksum="$(awk 'NR == 1 {print $1}' "${dump_file}.sha256")"
if command -v shasum >/dev/null 2>&1; then
  actual_checksum="$(shasum -a 256 "$dump_file" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  actual_checksum="$(sha256sum "$dump_file" | awk '{print $1}')"
else
  echo "GAGAL: shasum atau sha256sum diperlukan untuk memeriksa checksum." >&2
  exit 2
fi
if [[ "$actual_checksum" != "$expected_checksum" ]]; then
  echo "GAGAL: checksum dump tidak cocok." >&2
  exit 1
fi
echo "[PASS] Checksum backup cocok."

restore_database="${POSTGRES_DB}_restore_test"
docker compose exec -T postgres-db \
  dropdb --username "$POSTGRES_USER" --if-exists "$restore_database"
docker compose exec -T postgres-db \
  createdb --username "$POSTGRES_USER" "$restore_database"
docker compose exec -T postgres-db \
  pg_restore \
  --username "$POSTGRES_USER" \
  --dbname "$restore_database" \
  --no-owner \
  --no-privileges \
  < "$dump_file"

source_rows="$(docker compose exec -T postgres-db \
  psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --tuples-only --no-align \
  --command "SELECT md5(string_agg(nrp || ':' || name, '|' ORDER BY nrp)) FROM students;")"
restored_rows="$(docker compose exec -T postgres-db \
  psql --username "$POSTGRES_USER" --dbname "$restore_database" \
  --tuples-only --no-align \
  --command "SELECT md5(string_agg(nrp || ':' || name, '|' ORDER BY nrp)) FROM students;")"

if [[ "$source_rows" != "$restored_rows" ]]; then
  echo "GAGAL: data hasil restore berbeda dari database sumber." >&2
  exit 1
fi

docker compose exec -T postgres-db \
  psql --username "$POSTGRES_USER" --dbname "$restore_database" \
  --command "SELECT nrp, name FROM students ORDER BY nrp;"
echo "[PASS] Restore terverifikasi pada database terpisah: $restore_database"
