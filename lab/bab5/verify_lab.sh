#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVIDENCE_DIR="$BASE_DIR/../../evidence/bab5"
cd "$BASE_DIR"
mkdir -p "$EVIDENCE_DIR"
RESULTS_FILE="$EVIDENCE_DIR/runtime-results.txt"
exec > >(tee "$RESULTS_FILE") 2>&1

if ! command -v docker >/dev/null 2>&1; then
  echo "BLOCKED: Docker CLI tidak tersedia." >&2
  exit 2
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "BLOCKED: curl tidak tersedia pada host." >&2
  exit 2
fi
if [[ ! -f .env ]]; then
  echo "BLOCKED: jalankan ./scripts/create-env.sh sebelum verifikasi." >&2
  exit 2
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

docker info >/dev/null
docker compose config --quiet
echo "== Menjalankan PostgreSQL dan pgAdmin =="
docker compose up -d

wait_for_postgres() {
  local attempt container_id health
  for attempt in $(seq 1 60); do
    container_id="$(docker compose ps -q postgres-db)"
    if [[ -n "$container_id" ]]; then
      health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")"
      if [[ "$health" == "healthy" ]]; then
        return 0
      fi
    fi
    sleep 2
  done
  docker compose ps
  docker compose logs --tail 100 postgres-db pgadmin
  echo "GAGAL: PostgreSQL tidak sehat dalam 120 detik." >&2
  return 1
}

wait_for_postgres

echo "== Service aktif =="
docker compose ps

echo "== Verifikasi schema dan data awal =="
table_name="$(docker compose exec -T postgres-db \
  psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --tuples-only --no-align \
  --command "SELECT to_regclass('public.students');")"
[[ "$table_name" == "students" ]]
docker compose exec -T postgres-db \
  psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --command "SELECT id, nrp, name FROM students ORDER BY id;"

echo "== Uji constraint unique menolak NRP duplikat =="
if docker compose exec -T postgres-db \
  psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set ON_ERROR_STOP=1 \
  --command "INSERT INTO students (nrp, name) VALUES ('31230001', 'Duplikat');" \
  > "$EVIDENCE_DIR/duplicate-nrp-rejected.txt" 2>&1; then
  echo "GAGAL: constraint menerima NRP duplikat." >&2
  exit 1
fi
grep -qi "duplicate key" "$EVIDENCE_DIR/duplicate-nrp-rejected.txt"
cat "$EVIDENCE_DIR/duplicate-nrp-rejected.txt"
echo "[PASS] Constraint menolak NRP yang sudah digunakan."

echo "== Uji persistensi setelah container PostgreSQL dibuat ulang =="
docker compose exec -T postgres-db \
  psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set ON_ERROR_STOP=1 \
  --command "INSERT INTO students (nrp, name) VALUES ('31230003', 'Mahasiswa Tiga') ON CONFLICT (nrp) DO NOTHING;"
container_before="$(docker compose ps -q postgres-db)"
[[ -n "$container_before" ]]
docker compose stop postgres-db
docker compose rm -f postgres-db
docker compose up -d postgres-db
wait_for_postgres
container_after="$(docker compose ps -q postgres-db)"
if [[ -z "$container_after" || "$container_before" == "$container_after" ]]; then
  echo "GAGAL: container PostgreSQL tidak dibuat ulang." >&2
  exit 1
fi
printf '[PASS] ID container berubah: %.12s -> %.12s.\n' "$container_before" "$container_after"
persistent_row="$(docker compose exec -T postgres-db \
  psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --tuples-only --no-align \
  --command "SELECT nrp || ':' || name FROM students WHERE nrp = '31230003';")"
[[ "$persistent_row" == "31230003:Mahasiswa Tiga" ]]
echo "[PASS] Data uji tetap ada setelah container PostgreSQL dibuat ulang."

echo "== Membuat dan memeriksa backup =="
./scripts/backup.sh
latest_dump="$(find backup -maxdepth 1 -type f -name '*.dump' -print | sort | tail -n 1)"
[[ -n "$latest_dump" ]]
if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 -c "${latest_dump}.sha256"
else
  sha256sum -c "${latest_dump}.sha256"
fi
echo "== Restore test dan perbandingan isi =="
./scripts/restore-test.sh "$latest_dump" | tee "$EVIDENCE_DIR/restore-results.txt"

echo "== pgAdmin merespons melalui port loopback =="
pgadmin_status=""
for attempt in $(seq 1 60); do
  pgadmin_status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:${PGADMIN_HOST_PORT}/" || true)"
  if [[ "$pgadmin_status" == "200" || "$pgadmin_status" == "302" ]]; then
    break
  fi
  sleep 2
done
if [[ "$pgadmin_status" != "200" && "$pgadmin_status" != "302" ]]; then
  docker compose logs --tail 100 pgadmin
  echo "GAGAL: pgAdmin tidak merespons dengan HTTP 200 atau 302." >&2
  exit 1
fi
echo "[PASS] pgAdmin mengembalikan HTTP $pgadmin_status pada 127.0.0.1:${PGADMIN_HOST_PORT}."

echo "== Image dan volume lab =="
docker compose images
docker volume ls --filter "name=andi-devsecops-bab5"
echo "== Hasil akhir =="
docker compose ps
echo "[PASS] Verifikasi Bab 5 selesai. Dump berada di backup/ dan diabaikan Git."
