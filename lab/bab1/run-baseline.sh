#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace/devsecops-lab"

mkdir -p "$WORKSPACE"/{app,policy,reports,sbom,keys}
chmod 700 "$WORKSPACE/keys"
cat > "$WORKSPACE/keys/README-placeholder.txt" <<'EOF'
Placeholder non-rahasia untuk uji izin akses.
Jangan simpan private key, token, atau credential nyata di direktori praktikum.
EOF
chmod 600 "$WORKSPACE/keys/README-placeholder.txt"
cat > "$WORKSPACE/.gitignore" <<'EOF'
.env
.env.*
!.env.example
keys/*
reports/*
sbom/*
*.key
*.pem
EOF

printf '=== Baseline Bab 1: DevSecOps ===\n'
printf 'Waktu: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf 'Workspace: %s\n' "$WORKSPACE"

printf '\n=== Host macOS ===\n'
sw_vers
printf 'Arsitektur host: %s\n' "$(uname -m)"
printf 'Git host: '; git --version
printf 'OpenSSL host: '; openssl version
printf 'cURL host: '; curl --version | sed -n '1p'

printf '\n=== Docker client dan engine ===\n'
printf 'Context aktif: '; docker context show
docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}}'
docker compose version
docker info --format 'Server={{.OperatingSystem}} / {{.Architecture}}; CPUs={{.NCPU}}; MemoryBytes={{.MemTotal}}'
docker info --format 'SecurityOptions={{json .SecurityOptions}}; CgroupDriver={{.CgroupDriver}}; CgroupVersion={{.CgroupVersion}}'

printf '\n=== VM Linux Colima ===\n'
colima status
colima ssh -- cat /etc/os-release
printf 'Arsitektur VM: '; colima ssh -- uname -m
printf 'Akun VM: '; colima ssh -- id
printf 'OpenSSL VM: '; colima ssh -- openssl version
printf 'cURL VM: '; colima ssh -- curl --version | sed -n '1p'
printf 'Docker Compose dalam VM: '; colima ssh -- docker compose version
printf 'Ruang filesystem VM dan Docker data: '; colima ssh -- df -h / /var/lib/docker

printf '\n=== Struktur dan mode izin ===\n'
find "$WORKSPACE" -maxdepth 2 -print | sort
ls -ld "$WORKSPACE" "$WORKSPACE"/{app,policy,reports,sbom,keys} "$WORKSPACE/keys/README-placeholder.txt"
printf 'Mode keys=%s, placeholder=%s\n' \
  "$(stat -f '%Lp' "$WORKSPACE/keys")" \
  "$(stat -f '%Lp' "$WORKSPACE/keys/README-placeholder.txt")"
test "$(stat -f '%Lp' "$WORKSPACE/keys")" = 700
test "$(stat -f '%Lp' "$WORKSPACE/keys/README-placeholder.txt")" = 600
printf 'PASS: direktori keys hanya dapat diakses pemilik; placeholder hanya dapat dibaca/ditulis pemilik.\n'
printf 'Bukti: berkas placeholder bukan private key atau credential nyata.\n'

printf '\n=== Kondisi container sebelum praktikum ===\n'
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'
printf '\n=== Baseline Bab 1 selesai ===\n'
