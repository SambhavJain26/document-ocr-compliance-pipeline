#!/usr/bin/env bash
# Verify the scriptable n8n credentials without exposing their encrypted data.
set -euo pipefail

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
CONTAINER_FILE="/tmp/vendor-coi-chasing-creds.json"

credential_count="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM credentials_entity WHERE ((id = '$OPENAI_CREDENTIAL_ID' AND name = U&'OpenAI \\2014 Header Auth (Managed)' AND type = 'httpHeaderAuth') OR (id = '$POSTGRES_CREDENTIAL_ID' AND name = U&'Postgres \\2014 COI' AND type = 'postgres')) AND data !~ 'sk-';"
)"

[ "$credential_count" = "2" ] || {
  echo "Expected encrypted OpenAI and PostgreSQL credentials were not found" >&2
  exit 1
}

share_count="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM shared_credentials sc JOIN project p ON p.id = sc.\"projectId\" JOIN \"user\" u ON u.id = p.\"creatorId\" WHERE sc.\"credentialsId\" IN ('$OPENAI_CREDENTIAL_ID', '$POSTGRES_CREDENTIAL_ID') AND p.type = 'personal' AND u.\"roleSlug\" = 'global:owner';"
)"
[ "$share_count" = "2" ] || {
  echo "Scriptable credentials are not both shared with the owner project" >&2
  exit 1
}

if MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec --user root -T n8n test ! -e "$CONTAINER_FILE"; then
  echo "Credentials verified: encrypted, owner-visible, and no plaintext file remains."
else
  echo "Temporary plaintext credential file remains in the n8n container" >&2
  exit 1
fi
