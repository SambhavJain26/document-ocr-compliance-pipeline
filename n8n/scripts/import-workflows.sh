#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
COMPOSE=(docker compose --project-name vendor-coi-chasing --env-file .env -f infra/docker-compose.yml)
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
credential_id() {
  "${COMPOSE[@]}" exec -T postgres psql -U coi -d n8n -Atc \
    "SELECT c.id FROM credentials_entity c WHERE c.type='$1' ORDER BY c.name LIMIT 1;"
}
POSTGRES_ID="$(credential_id postgres)"
OPENAI_ID="$(credential_id openAiApi)"
GMAIL_ID="$(credential_id gmailOAuth2)"
[ -n "$POSTGRES_ID" ] && [ -n "$OPENAI_ID" ] && [ -n "$GMAIL_ID" ] || {
  echo "Required n8n credentials are missing" >&2; exit 1;
}
for workflow in n8n/workflows/*.json; do
  [ -f "$workflow" ] || continue
  base="$(basename "$workflow")"
  python - "$workflow" "$TMP_DIR/$base" "$POSTGRES_ID" "$OPENAI_ID" "$GMAIL_ID" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
for key, value in zip(("POSTGRES", "OPENAI", "GMAIL"), sys.argv[3:]):
    text = text.replace("__" + key + "_CREDENTIAL_ID__", value)
pathlib.Path(sys.argv[2]).write_text(text, encoding="utf-8")
PY
  "${COMPOSE[@]}" cp "$TMP_DIR/$base" "n8n:/tmp/$base"
  MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec -T n8n n8n import:workflow --input="/tmp/$base"
done
for id in 13b4e779-2a6e-4f3e-a4cf-6cdd170e5420 8a3c3c3f-46ea-479e-9ae5-fdc0145ca83b; do
  "${COMPOSE[@]}" exec -T n8n n8n publish:workflow --id="$id"
done
