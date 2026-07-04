#!/usr/bin/env bash
set -euo pipefail

: "${MAL_ACCOUNT_APP_PASSWORD:?set MAL_ACCOUNT_APP_PASSWORD for local Postgres bootstrap}"

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v app_password="$MAL_ACCOUNT_APP_PASSWORD" <<'SQL'
ALTER ROLE mal_account_app WITH PASSWORD :'app_password';
SQL
