#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$BASE_DIR/.env"

if [[ -e "$ENV_FILE" ]]; then
  echo "GAGAL: .env sudah ada. Skrip tidak menimpa konfigurasi yang ada." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "GAGAL: OpenSSL tidak tersedia untuk membuat password acak." >&2
  exit 2
fi

postgres_password="$(openssl rand -hex 24)"
pgadmin_password="$(openssl rand -hex 24)"

umask 077
cat > "$ENV_FILE" <<EOF
POSTGRES_DB=labdb
POSTGRES_USER=labuser
POSTGRES_PASSWORD=$postgres_password
PGADMIN_DEFAULT_EMAIL=admin@pens.ac.id
PGADMIN_DEFAULT_PASSWORD=$pgadmin_password
POSTGRES_HOST_PORT=15432
PGADMIN_HOST_PORT=15050
EOF

chmod 600 "$ENV_FILE"
echo "[PASS] .env dibuat dengan mode 600. Password acak tidak ditampilkan."
