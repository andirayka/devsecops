#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

network_name="andi-dso-bab3-user-bridge"
server_a="andi-dso-bab3-server-a"
server_b="andi-dso-bab3-server-b"
data_volume="andi-dso-bab3-data-vol"
writer_name="andi-dso-bab3-volume-writer"

if ! command -v docker >/dev/null 2>&1; then
  echo "BLOCKED: Docker CLI tidak tersedia. Pasang Docker Engine/Desktop, lalu ulangi." >&2
  exit 2
fi

if [[ ! -r secrets/db_password ]]; then
  if [[ ! -r secrets/db_password.example ]]; then
    echo "BLOCKED: secrets/db_password.example tidak ditemukan." >&2
    exit 2
  fi
  cp secrets/db_password.example secrets/db_password
  echo "Credential runtime dibuat dari contoh lokal; nilainya tidak dicetak."
fi
chmod 600 secrets/db_password

backup_file=""
tmpfs_name="andi-dso-bab3-tmpfs-$$"

cleanup() {
  if [[ -n "$backup_file" && -f "$backup_file" ]]; then
    cp -p "$backup_file" html/static.html
    rm -f "$backup_file"
  fi
  docker rm -f "$tmpfs_name" "$writer_name" "$server_a" "$server_b" >/dev/null 2>&1 || true
  docker network rm "$network_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker info >/dev/null
docker compose config --quiet
docker network create --driver bridge "$network_name"
docker run -d --name "$server_a" --network "$network_name" --network-alias server-a alpine:3.20 sleep 3600
docker run -d --name "$server_b" --network "$network_name" --network-alias server-b alpine:3.20 sleep 3600
echo "== Uji DNS dan konektivitas user-defined bridge =="
docker exec "$server_a" nslookup server-b
docker exec "$server_a" ping -c 3 server-b
echo "PASS: server-a me-resolve server-b dan menerima tiga balasan ping."

echo "== Uji named volume dan backup arsip =="
docker volume create "$data_volume"
docker run -d --name "$writer_name" --mount "source=$data_volume,target=/data" alpine:3.20 \
  sh -c 'while true; do date -u +%FT%TZ >> /data/activity.log; sleep 1; done'
sleep 2
docker rm -f "$writer_name"
docker run --rm --mount "source=$data_volume,target=/data,readonly" alpine:3.20 \
  sh -c 'test -s /data/activity.log && echo "Volume tetap terbaca setelah container writer dihapus:" && cat /data/activity.log'
mkdir -p backups
docker run --rm \
  --mount "source=$data_volume,target=/source,readonly" \
  --mount "type=bind,source=$BASE_DIR/backups,target=/backup" \
  alpine:3.20 sh -c \
  'tar czf /backup/andi-dso-bab3-data-vol.tar.gz -C /source . && tar tzf /backup/andi-dso-bab3-data-vol.tar.gz'
shasum -a 256 backups/andi-dso-bab3-data-vol.tar.gz

docker compose up -d --build

wait_for_stack() {
  local attempt service container_id health all_healthy
  for attempt in $(seq 1 60); do
    all_healthy=1
    for service in db app web; do
      container_id="$(docker compose ps -q "$service")"
      if [[ -z "$container_id" ]]; then
        all_healthy=0
        break
      fi
      health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")"
      if [[ "$health" != "healthy" ]]; then
        all_healthy=0
        break
      fi
    done
    if [[ "$all_healthy" -eq 1 ]]; then
      return 0
    fi
    sleep 2
  done
  docker compose ps
  docker compose logs --tail 100
  echo "FAIL: stack tidak menjadi sehat dalam 120 detik." >&2
  return 1
}

wait_for_stack
docker compose ps

echo "== Uji sukses: HTTP aplikasi dan health =="
app_response="$(curl -fsS http://127.0.0.1:18083/api/)"
printf '%s\n' "$app_response"
grep -Eq '"status"[[:space:]]*:[[:space:]]*"ok"' <<<"$app_response"
curl -fsS http://127.0.0.1:18083/api/health

echo "== Uji sukses: DNS backend dari app =="
docker compose exec -T app python -c 'import socket; print(socket.gethostbyname("db"))'
db_container="$(docker compose ps -q db)"
db_published="$(docker inspect --format '{{range $port, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{$port}} {{end}}{{end}}' "$db_container")"
if [[ -n "$db_published" ]]; then
  echo "FAIL: PostgreSQL memublikasikan port host: $db_published" >&2
  exit 1
fi
echo "PASS: PostgreSQL tidak memiliki published port host."

echo "== Uji negatif: db tidak terlihat dari frontend web =="
if ! docker compose exec -T web sh -c 'command -v nslookup >/dev/null 2>&1'; then
  echo "BLOCKED: nslookup tidak tersedia di container web; uji isolasi DNS tidak dapat dijalankan." >&2
  exit 1
fi
if docker compose exec -T web sh -c 'nslookup db >/dev/null 2>&1'; then
  echo "FAIL: service web dapat me-resolve db di network frontend." >&2
  exit 1
else
  echo "PASS: nama service db tidak tersedia dari network frontend."
fi

echo "== Uji negatif: bind mount tidak dapat ditulis dari web =="
if docker compose exec -T web sh -c 'printf x >> /usr/share/nginx/html/static.html' 2>/dev/null; then
  echo "FAIL: bind mount dapat ditulis dari container web." >&2
  exit 1
else
  echo "PASS: bind mount read-only menolak penulisan dari container."
fi

echo "== Uji bind mount: perubahan host terlihat tanpa rebuild =="
backup_file="$(mktemp)"
cp -p html/static.html "$backup_file"
marker="BIND_MOUNT_HOST_CHANGE_$(date +%s)"
printf '\n<!-- %s -->\n' "$marker" >> html/static.html
static_response=""
for attempt in $(seq 1 10); do
  if static_response="$(curl -fsS http://127.0.0.1:18083/static.html)" \
    && grep -Fq "$marker" <<<"$static_response"; then
    break
  fi
  sleep 1
done
if ! grep -Fq "$marker" <<<"$static_response"; then
  echo "FAIL: host change was not visible through the bind mount within 10 seconds." >&2
  exit 1
fi
grep -F "$marker" <<<"$static_response"
cp -p "$backup_file" html/static.html

echo "== Uji sukses: named volume bertahan setelah container dibuat ulang =="
docker compose exec -T db psql -U labuser -d labdb -v ON_ERROR_STOP=1 -c \
  "CREATE TABLE IF NOT EXISTS bab3_volume_check (record_key text PRIMARY KEY, value text NOT NULL); INSERT INTO bab3_volume_check (record_key, value) VALUES ('persist', 'volume-data-survived') ON CONFLICT (record_key) DO NOTHING;"
docker compose down
docker compose up -d --build
wait_for_stack
persisted_value="$(docker compose exec -T db psql -At -U labuser -d labdb -c \
  "SELECT value FROM bab3_volume_check WHERE record_key = 'persist';")"
if [[ "$persisted_value" != "volume-data-survived" ]]; then
  echo "FAIL: data PostgreSQL tidak bertahan setelah docker compose down/up." >&2
  exit 1
fi
echo "PASS: $persisted_value"

echo "== Uji sukses: data tmpfs hilang setelah container dihentikan =="
docker run -d --name "$tmpfs_name" --tmpfs /scratch:rw,noexec,nosuid,size=16m alpine:3.20 sleep 3600 >/dev/null
docker exec "$tmpfs_name" sh -c 'printf volatile > /scratch/probe'
docker exec "$tmpfs_name" test -s /scratch/probe
docker stop "$tmpfs_name" >/dev/null
docker start "$tmpfs_name" >/dev/null
if docker exec "$tmpfs_name" test -e /scratch/probe; then
  echo "FAIL: file tmpfs masih ada setelah container dihentikan dan dijalankan kembali." >&2
  exit 1
fi
echo "PASS: file tmpfs hilang setelah stop/start container."

echo "== Bukti akhir =="
docker compose ps
curl -fsS http://127.0.0.1:18083/api/
curl -i http://127.0.0.1:18083/api/health
docker compose logs --tail 30
echo "Semua uji Bab 3 lulus. Stack Compose tetap aktif untuk capture bukti; jalankan docker compose down setelahnya."
