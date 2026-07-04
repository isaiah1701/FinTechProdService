#!/usr/bin/env bash
set -euo pipefail

: "${BANK_ACCOUNT_APP_PASSWORD:?set BANK_ACCOUNT_APP_PASSWORD for local Postgres bootstrap}"

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v app_password="$BANK_ACCOUNT_APP_PASSWORD" <<'SQL'
ALTER ROLE bank_account_app WITH PASSWORD :'app_password';
SQL
