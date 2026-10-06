#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"
EVIDENCE_DIR="$BASE_DIR/../../evidence/bab4"
mkdir -p "$EVIDENCE_DIR" logs/nginx

if ! command -v docker >/dev/null 2>&1; then
  echo "BLOCKED: Docker CLI tidak tersedia." >&2
  exit 2
fi
if ! command -v curl >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
  echo "BLOCKED: curl dan openssl harus tersedia pada host." >&2
  exit 2
fi
bash "$BASE_DIR/generate_cert.sh"
key_mode="$(stat -f '%Lp' certs/lab.key)"
[[ "$key_mode" == "600" ]]

docker info >/dev/null
docker compose config --quiet
docker compose up -d --build

wait_for_stack() {
  local attempt service container_id health all_healthy
  for attempt in $(seq 1 60); do
    all_healthy=1
    for service in apache-web flask-app proxy; do
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
  echo "FAIL: web stack tidak sehat dalam 120 detik." >&2
  return 1
}

wait_for_stack
docker compose ps
echo "== Validasi konfigurasi service yang berjalan =="
docker compose exec -T proxy nginx -t
docker compose exec -T apache-web httpd -t

echo "== Uji sukses: HTTP dialihkan ke HTTPS =="
redirect_headers="$(curl -sSI --max-time 5 -H 'Host: localhost' http://127.0.0.1:18084/)"
printf '%s\n' "$redirect_headers"
grep -Eq '^HTTP/[0-9.]+ 301' <<<"$redirect_headers"
grep -Eiq '^Location: https://localhost:18444/' <<<"$redirect_headers"

echo "== Uji sukses: Apache default melalui reverse proxy =="
default_page="$(curl -kfsS --max-time 5 https://localhost:18444/)"
printf '%s\n' "$default_page"
grep -Fq 'Apache di Belakang Nginx' <<<"$default_page"

echo "== Uji sukses: Flask API dan health melalui /api =="
api_response="$(curl -kfsS --max-time 5 https://localhost:18444/api/)"
printf '%s\n' "$api_response"
grep -Fq '"service":"flask-app"' <<<"$api_response"
grep -Fq '"forwarded_proto":"https"' <<<"$api_response"
health_response="$(curl -kfsS --max-time 5 https://localhost:18444/api/health)"
printf '%s\n' "$health_response"
grep -Fq '"status":"healthy"' <<<"$health_response"

echo "== Uji normalisasi path slash berulang di Nginx =="
normalized_response="$(curl -kfsS --path-as-is --max-time 5 'https://localhost:18444//api///health')"
printf '%s\n' "$normalized_response"
grep -Fq '"status":"healthy"' <<<"$normalized_response"
echo "PASS: //api///health dinormalisasi dan tetap mencapai health endpoint Flask."

echo "== Uji gagal yang diharapkan: sertifikat self-signed tidak dipercaya curl =="
if curl -fsS --max-time 5 https://localhost:18444/ >/dev/null 2>"$EVIDENCE_DIR/tls-untrusted-error.txt"; then
  echo "FAIL: curl menerima sertifikat self-signed tanpa opsi -k." >&2
  exit 1
fi
cat "$EVIDENCE_DIR/tls-untrusted-error.txt"
grep -Eiq 'certificate|issuer|self.signed' "$EVIDENCE_DIR/tls-untrusted-error.txt"
echo "PASS: verifikasi sertifikat menolak CA self-signed; -k hanya dipakai untuk lab."

echo "== Uji gagal yang diharapkan: endpoint API tidak dikenal menghasilkan 404 =="
unknown_status="$(curl -k -sS --max-time 5 -o /dev/null -w '%{http_code}' https://localhost:18444/api/not-found)"
printf 'HTTP %s\n' "$unknown_status"
[[ "$unknown_status" == "404" ]]

echo "== Uji sukses: TLS dan identitas sertifikat =="
openssl x509 -in certs/lab.crt -noout -subject -dates -ext subjectAltName
for protocol in tls1_2 tls1_3; do
  if [[ "$protocol" == "tls1_2" ]]; then
    expected_protocol="TLSv1.2"
  else
    expected_protocol="TLSv1.3"
  fi
  tls_result="$(openssl s_client -connect 127.0.0.1:18444 -servername localhost -"$protocol" -brief </dev/null 2>&1 || true)"
  printf '%s\n' "$tls_result"
  grep -Fq "Protocol version: $expected_protocol" <<<"$tls_result"
  echo "PASS: negosiasi $expected_protocol berhasil."
done

echo "== Uji sukses: hanya proxy mempublikasikan port loopback =="
proxy_id="$(docker compose ps -q proxy)"
proxy_bindings="$(docker port "$proxy_id")"
printf '%s\n' "$proxy_bindings"
grep -Fq '127.0.0.1:18084' <<<"$proxy_bindings"
grep -Fq '127.0.0.1:18444' <<<"$proxy_bindings"
cert_mount_read_only="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/certs"}}{{.RW}}{{end}}{{end}}' "$proxy_id")"
if [[ "$key_mode" != "600" || "$cert_mount_read_only" != "false" ]]; then
  echo "FAIL: mode key=$key_mode dan RO mount cert/key=$cert_mount_read_only tidak sesuai." >&2
  exit 1
fi
echo "PASS: private key mode 0600 dan mount cert/key read-only."

echo "== Uji sukses: backend tidak memiliki published port host =="
for service_port in 'apache-web 80' 'flask-app 5000'; do
  read -r service port <<<"$service_port"
  container_id="$(docker compose ps -q "$service")"
  published="$(docker inspect --format '{{range $port, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{$port}} {{end}}{{end}}' "$container_id")"
  if [[ -n "$published" ]]; then
    echo "FAIL: $service memiliki published port: $published" >&2
    exit 1
  fi
  echo "PASS: $service:$port hanya tersedia di network Compose."
done

echo "== Uji sukses: Nginx dapat mencapai backend pada network privat =="
docker compose exec -T proxy wget -qO- http://apache-web/ | grep -F 'Apache di Belakang Nginx'
docker compose exec -T proxy wget -qO- http://flask-app:5000/health

echo "== Uji sukses: TLS access log tersimpan pada host =="
for attempt in $(seq 1 10); do
  [[ -s logs/nginx/access.log ]] && break
  sleep 1
done
if [[ ! -s logs/nginx/access.log ]]; then
  echo "FAIL: logs/nginx/access.log kosong." >&2
  exit 1
fi
tail -n 8 logs/nginx/access.log
grep -Eq 'GET /api/health .* 200' logs/nginx/access.log

echo "== Bukti akhir =="
docker compose ps
printf 'HTTP redirect: %s\n' "$(grep -m1 -E '^HTTP/[0-9.]+ 301' <<<"$redirect_headers")"
printf 'HTTPS /: HTTP %s\n' "$(curl -k -sS -o /dev/null -w '%{http_code}' https://localhost:18444/)"
printf 'API /api/: %s\n' "$api_response"
printf 'API /api/health: %s\n' "$health_response"
echo "Semua uji Bab 4 lulus. Jalankan docker compose down setelah menyimpan bukti; jangan gunakan down -v bila ingin mempertahankan data."
