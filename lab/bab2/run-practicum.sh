#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAB_LABEL='com.andi.lab=devsecops-bab12'
NGINX_NAME='andi-dso-bab12-nginx'
EXPOSE_NAME='andi-dso-bab12-expose-only'
CUSTOM_NAME='andi-dso-bab12-custom-web'
CREATED_CONTAINERS=()

cleanup_owned_container() {
  local name="$1"
  local owner
  if docker container inspect "$name" >/dev/null 2>&1; then
    owner="$(docker inspect --format '{{ index .Config.Labels "com.andi.lab" }}' "$name")"
    if [[ "$owner" == 'devsecops-bab12' ]]; then
      printf 'Cleanup container milik praktikum: %s\n' "$name"
      docker rm --force "$name"
    else
      printf 'Tidak menghapus %s: label ownership tidak cocok (%s).\n' "$name" "$owner" >&2
      return 1
    fi
  fi
}

cleanup() {
  local status=$?
  local name
  trap - EXIT
  if [[ ${#CREATED_CONTAINERS[*]} -gt 0 ]]; then
    for name in "${CREATED_CONTAINERS[@]}"; do
      cleanup_owned_container "$name" || status=1
    done
  fi
  printf '\nContainer praktikum yang masih tercatat:\n'
  docker ps -a --filter "label=$LAB_LABEL" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
  printf '\nContainer aktif setelah cleanup:\n'
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
  exit "$status"
}
trap cleanup EXIT

printf '=== Praktikum Bab 2: Docker dan container ===\n'
printf 'Waktu: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf 'Context: %s\n' "$(docker context show)"
docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}}'
docker compose version
printf 'Image nginx:alpine yang tersedia: '
docker image inspect nginx:alpine --format '{{index .RepoDigests 0}}'

for port in 18082 19092; do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    printf 'GAGAL preflight: port %s sedang digunakan; tidak membuat container.\n' "$port" >&2
    exit 1
  fi
  printf 'PASS preflight: 127.0.0.1:%s tersedia.\n' "$port"
done

for name in "$NGINX_NAME" "$EXPOSE_NAME" "$CUSTOM_NAME"; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    printf 'GAGAL preflight: nama container %s sudah ada; tidak menimpanya.\n' "$name" >&2
    exit 1
  fi
done

printf '\n=== 1. Uji image hello-world ===\n'
docker run --rm --name andi-dso-bab12-hello --label "$LAB_LABEL" hello-world

printf '\n=== 2. Uji image Ubuntu ===\n'
docker run --rm --name andi-dso-bab12-ubuntu --label "$LAB_LABEL" ubuntu:24.04 \
  sh -c 'cat /etc/os-release; printf "\nArsitektur container: "; uname -m; printf "\nIdentitas proses: "; id'

printf '\n=== 3. Menjalankan Nginx pada loopback port 18082 ===\n'
docker run --detach --name "$NGINX_NAME" --label "$LAB_LABEL" \
  --publish 127.0.0.1:18082:80 nginx:alpine
CREATED_CONTAINERS+=("$NGINX_NAME")
for attempt in {1..15}; do
  if curl --fail --silent http://127.0.0.1:18082/ >/dev/null; then
    break
  fi
  sleep 1
done
docker ps --filter "name=^/${NGINX_NAME}$" --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
NGINX_BODY="$(curl --fail --silent --show-error --max-time 5 http://127.0.0.1:18082/)"
if printf '%s' "$NGINX_BODY" | grep -Fq 'Welcome to nginx!'; then
  printf 'PASS assertion body: halaman default Nginx memuat marker "Welcome to nginx!".\n'
else
  printf 'FAIL assertion body: marker halaman default Nginx tidak ditemukan.\n' >&2
  exit 1
fi
printf '\nRespons HTTP Nginx:\n'
curl --show-error --include --max-time 5 http://127.0.0.1:18082/
printf '\nLog Nginx:\n'
docker logs --tail 10 "$NGINX_NAME"

printf '\n=== 4. Build image kustom pens-web:1.0 ===\n'
docker build --tag pens-web:1.0 "$SCRIPT_DIR"
docker image inspect pens-web:1.0 --format 'ID={{.Id}} OS={{.Os}} Architecture={{.Architecture}} ExposedPorts={{json .Config.ExposedPorts}}'

printf '\n=== 5. Bedakan EXPOSE dan publish ===\n'
docker run --detach --name "$EXPOSE_NAME" --label "$LAB_LABEL" pens-web:1.0
CREATED_CONTAINERS+=("$EXPOSE_NAME")
docker inspect "$EXPOSE_NAME" --format 'ExposedPorts={{json .Config.ExposedPorts}}; HostPortBindings={{json .HostConfig.PortBindings}}; RuntimePorts={{json .NetworkSettings.Ports}}'
cleanup_owned_container "$EXPOSE_NAME"

printf '\n=== 6. Publish image kustom hanya ke loopback port 19092 ===\n'
docker run --detach --name "$CUSTOM_NAME" --label "$LAB_LABEL" \
  --publish 127.0.0.1:19092:80 pens-web:1.0
CREATED_CONTAINERS+=("$CUSTOM_NAME")
for attempt in {1..15}; do
  if curl --fail --silent http://127.0.0.1:19092/ >/dev/null; then
    break
  fi
  sleep 1
done
docker ps --filter "name=^/${CUSTOM_NAME}$" --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
CUSTOM_BODY="$(curl --fail --silent --show-error --max-time 5 http://127.0.0.1:19092/)"
if printf '%s' "$CUSTOM_BODY" | grep -Fq 'DEVSECOPS-BAB2-ANDI-3123640021-PENS-WEB-1.0'; then
  printf 'PASS assertion body: marker unik image pens-web:1.0 dan identitas Andi ditemukan.\n'
else
  printf 'FAIL assertion body: marker unik image kustom tidak ditemukan.\n' >&2
  exit 1
fi
printf '\nRespons HTTP image kustom:\n'
curl --show-error --include --max-time 5 http://127.0.0.1:19092/
printf '\nLog image kustom:\n'
docker logs --tail 10 "$CUSTOM_NAME"

printf '\n=== Praktikum Bab 2 selesai ===\n'
