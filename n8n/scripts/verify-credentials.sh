#!/usr/bin/env bash
# Verify n8n credentials without exposing encrypted values.
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

POSTGRES_CREDENTIAL_ID="d2e3f4a5-b6c7-4d8e-9f0a-1b2c3d4e5f60"
CONTAINER_FILE="/tmp/vendor-coi-chasing-creds.json"

postgres_count="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM credentials_entity WHERE id = '$POSTGRES_CREDENTIAL_ID' AND name = U&'Postgres \\2014 COI' AND type = 'postgres' AND data !~ 'sk-';"
)"
[ "$postgres_count" = "1" ] || {
  echo "Expected encrypted PostgreSQL credential was not found" >&2
  exit 1
}

owner_share_count="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM shared_credentials sc JOIN project p ON p.id = sc.\"projectId\" JOIN \"user\" u ON u.id = p.\"creatorId\" WHERE sc.\"credentialsId\" = '$POSTGRES_CREDENTIAL_ID' AND p.type = 'personal' AND u.\"roleSlug\" = 'global:owner';"
)"
[ "$owner_share_count" = "1" ] || {
  echo "PostgreSQL credential is not shared with the owner project" >&2
  exit 1
}

openai_count="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM credentials_entity c JOIN shared_credentials sc ON sc.\"credentialsId\" = c.id JOIN project p ON p.id = sc.\"projectId\" JOIN \"user\" u ON u.id = p.\"creatorId\" WHERE c.type = 'openAiApi' AND p.type = 'personal' AND u.\"roleSlug\" = 'global:owner';"
)"
[ "$openai_count" -ge 1 ] || {
  echo "An owner-visible n8n OpenAI API credential is required" >&2
  exit 1
}

gmail_count="$(
  "${COMPOSE[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d n8n -Atc \
    "SELECT count(*) FROM credentials_entity c JOIN shared_credentials sc ON sc.\"credentialsId\" = c.id JOIN project p ON p.id = sc.\"projectId\" JOIN \"user\" u ON u.id = p.\"creatorId\" WHERE c.type = 'gmailOAuth2' AND p.type = 'personal' AND u.\"roleSlug\" = 'global:owner';"
)"
[ "$gmail_count" -ge 1 ] || {
  echo "An owner-visible n8n Gmail OAuth2 credential is required" >&2
  exit 1
}

if MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec --user root -T n8n test ! -e "$CONTAINER_FILE"; then
  echo "Credentials verified: PostgreSQL encrypted; n8n-native OpenAI and Gmail credentials owner-visible; no plaintext file remains."
else
  echo "Temporary plaintext credential file remains in the n8n container" >&2
  exit 1
fi
