#!/usr/bin/env bash
# Import only the PostgreSQL credential from local .env values.
# OpenAI and Gmail use n8n-native credentials created through the UI.
set -euo pipefail
umask 077

cd "$(dirname "$0")/../.."
# shellcheck disable=SC1091
set -a; source .env; set +a

COMPOSE=(
  docker compose
  --project-name vendor-coi-chasing
  --env-file .env
  -f infra/docker-compose.yml
)

POSTGRES_CREDENTIAL_ID="d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f60"
TMP_DIR="$(mktemp -d)"
CONTAINER_FILE="/tmp/vendor-coi-chasing-creds.json"

cleanup() {
  MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec --user root -T n8n rm -f "$CONTAINER_FILE" >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

for variable in POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB; do
  value="${!variable:-}"
  if [ -z "$value" ] || [[ "$value" == *CHANGE_ME* ]]; then
    echo "$variable must be set in .env" >&2
    exit 1
  fi
done

owner_project_id="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT p.id FROM project p JOIN \"user\" u ON p.\"creatorId\" = u.id WHERE p.type = 'personal' AND u.\"roleSlug\" = 'global:owner';"
)"
[ -n "$owner_project_id" ] || { echo "n8n owner project not found" >&2; exit 1; }

postgres_matches="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM credentials_entity WHERE id = '$POSTGRES_CREDENTIAL_ID' AND name = U&'Postgres \\2014 COI' AND type = 'postgres';"
)"
postgres_ids="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM credentials_entity WHERE id = '$POSTGRES_CREDENTIAL_ID';"
)"

if [ "$postgres_ids" != "$postgres_matches" ]; then
  echo "PostgreSQL credential ID already exists with an unexpected shape; resolve manually" >&2
  exit 1
fi
if [ "$postgres_matches" = "1" ]; then
  echo "PostgreSQL credential already imported."
  exit 0
fi

python - "$TMP_DIR/credentials.json" <<'PY'
import json
import os
import sys

credential = [{
    "id": "d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f60",
    "name": "Postgres \N{EM DASH} COI",
    "type": "postgres",
    "data": {
        "host": "postgres",
        "port": 5432,
        "database": os.environ["POSTGRES_DB"],
        "user": os.environ["POSTGRES_USER"],
        "password": os.environ["POSTGRES_PASSWORD"],
        "ssl": "disable",
    },
}]

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(credential, handle)
PY

"${COMPOSE[@]}" cp "$TMP_DIR/credentials.json" "n8n:$CONTAINER_FILE"
MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec --user root -T n8n chown node:node "$CONTAINER_FILE"
MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec -T n8n n8n import:credentials \
  --input="$CONTAINER_FILE" --projectId="$owner_project_id"

echo "PostgreSQL credential import complete. Restart n8n before using it."
