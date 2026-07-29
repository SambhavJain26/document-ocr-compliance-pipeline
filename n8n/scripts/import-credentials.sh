#!/usr/bin/env bash
# Import the two credentials that can safely be created from local .env values.
# Gmail OAuth is deliberately excluded: its token can only be obtained through
# an interactive consent flow in the n8n UI.
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

OPENAI_CREDENTIAL_ID="c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f"
POSTGRES_CREDENTIAL_ID="d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f60"
TMP_DIR="$(mktemp -d)"
CONTAINER_FILE="/tmp/vendor-coi-chasing-creds.json"

cleanup() {
  MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec --user root -T n8n rm -f "$CONTAINER_FILE" >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

for variable in OPENAI_API_KEY POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB; do
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

openai_matches="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM credentials_entity WHERE id = '$OPENAI_CREDENTIAL_ID' AND name = U&'OpenAI \\2014 Header Auth (Managed)' AND type = 'httpHeaderAuth';"
)"
postgres_matches="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM credentials_entity WHERE id = '$POSTGRES_CREDENTIAL_ID' AND name = U&'Postgres \\2014 COI' AND type = 'postgres';"
)"
matching_count=$((openai_matches + postgres_matches))
existing_ids="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM credentials_entity WHERE id IN ('$OPENAI_CREDENTIAL_ID', '$POSTGRES_CREDENTIAL_ID');"
)"

if [ "$existing_ids" != "$matching_count" ]; then
  echo "credential IDs already exist with an unexpected shape; resolve manually" >&2
  exit 1
fi

if [ "$matching_count" = "2" ]; then
  echo "Scriptable credentials already imported."
  exit 0
fi

IMPORT_OPENAI=$((1 - openai_matches)) IMPORT_POSTGRES=$((1 - postgres_matches)) \
  python - "$TMP_DIR/credentials.json" <<'PY'
import json
import os
import sys

credentials = []

if os.environ["IMPORT_OPENAI"] == "1":
    credentials.append({
        "id": "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f",
        "name": "OpenAI — Header Auth (Managed)",
        "type": "httpHeaderAuth",
        "data": {
            "name": "Authorization",
            "value": f"Bearer {os.environ['OPENAI_API_KEY']}",
        },
    })

if os.environ["IMPORT_POSTGRES"] == "1":
    credentials.append({
        "id": "d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f60",
        "name": "Postgres — COI",
        "type": "postgres",
        "data": {
            "host": "postgres",
            "port": 5432,
            "database": os.environ["POSTGRES_DB"],
            "user": os.environ["POSTGRES_USER"],
            "password": os.environ["POSTGRES_PASSWORD"],
            "ssl": "disable",
        },
    })

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(credentials, handle)
PY

"${COMPOSE[@]}" cp "$TMP_DIR/credentials.json" "n8n:$CONTAINER_FILE"
MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec --user root -T n8n chown node:node "$CONTAINER_FILE"
MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec -T n8n n8n import:credentials \
  --input="$CONTAINER_FILE" --projectId="$owner_project_id"

echo "Scriptable credential import complete. Restart n8n before using them."
