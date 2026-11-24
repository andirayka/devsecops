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

grafana_admin_password="$(openssl rand -hex 24)"
grafana_db_password="$(openssl rand -hex 24)"

umask 077
cat > "$ENV_FILE" <<EOF
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$grafana_admin_password
GRAFANA_DB_USER=grafana_reader
GRAFANA_DB_PASSWORD=$grafana_db_password
POSTGRES_DB=labdb
EOF

chmod 600 "$ENV_FILE"
echo "[PASS] .env dibuat dengan mode 600. Password acak tidak ditampilkan."
