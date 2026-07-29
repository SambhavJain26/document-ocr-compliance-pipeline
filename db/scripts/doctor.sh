#!/usr/bin/env bash
# Stage 0 gate: verify prerequisites before infrastructure work begins.
set -uo pipefail

FAIL=0
ENV_READY=1

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
bad()  { printf "  \033[31m✗\033[0m %s\n" "$1"; FAIL=1; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }

has() { command -v "$1" >/dev/null 2>&1; }

PYTHON_BIN="python"
if [ -x "fixtures/.venv/bin/python" ]; then
  PYTHON_BIN="fixtures/.venv/bin/python"
elif [ -x "fixtures/.venv/Scripts/python.exe" ]; then
  PYTHON_BIN="fixtures/.venv/Scripts/python.exe"
fi

echo "── Toolchain ─────────────────────────────────────"
for tool in git python docker node curl openssl; do
  if has "$tool"; then ok "$tool"; else bad "$tool not found"; fi
done

if has psql; then
  ok "psql"
else
  warn "psql not found on host; Stage 2 can use psql inside postgres:16"
fi

if has jq; then
  ok "jq"
else
  warn "jq not found; Python's json.tool is available as the JSON fallback"
fi

if docker info >/dev/null 2>&1; then
  ok "Docker daemon reachable"
else
  bad "Docker daemon is not reachable"
fi

if docker compose version >/dev/null 2>&1; then
  ok "Docker Compose v2"
else
  bad "Docker Compose v2 not available"
fi

echo
echo "── Reusable Docker images ────────────────────────"
for image in postgres:16 n8nio/n8n:latest caddy:2; do
  if docker image inspect "$image" >/dev/null 2>&1; then
    ok "$image available locally (reuse; do not pull)"
  else
    warn "$image not present locally; Stage 1 will need to pull it"
  fi
done

echo
echo "── Environment ───────────────────────────────────"
if [ -f .env ]; then
  ok ".env exists"
  # The file is local and trusted; exporting lets indirect expansion validate it.
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
else
  bad ".env missing (copy .env.example and fill it locally)"
  ENV_READY=0
fi

required_vars=(
  N8N_HOST WEBHOOK_URL N8N_ENCRYPTION_KEY N8N_BASIC_AUTH_PASSWORD
  POSTGRES_PASSWORD OPENAI_API_KEY GOOGLE_OAUTH_CLIENT_ID
  GOOGLE_OAUTH_CLIENT_SECRET DASHBOARD_TOKEN GENERIC_TIMEZONE ACME_EMAIL
)

for name in "${required_vars[@]}"; do
  value="${!name:-}"
  if [ -z "$value" ]; then
    bad "$name is empty"
    ENV_READY=0
  elif [[ "$value" == *CHANGE_ME* ]] || [[ "$value" == *example.com* ]]; then
    bad "$name still has a placeholder value"
    ENV_READY=0
  else
    ok "$name set"
  fi
done

encryption_key="${N8N_ENCRYPTION_KEY:-}"
if [ "${#encryption_key}" -lt 32 ]; then
  bad "N8N_ENCRYPTION_KEY is shorter than 32 characters"
  ENV_READY=0
else
  ok "N8N_ENCRYPTION_KEY length is valid"
fi

echo
echo "── DNS ───────────────────────────────────────────"
if [ "$ENV_READY" -eq 1 ]; then
  resolved_ip="$("$PYTHON_BIN" - "$N8N_HOST" <<'PY'
import socket
import sys
try:
    print(socket.gethostbyname(sys.argv[1]))
except OSError:
    pass
PY
)"
  if [ -n "$resolved_ip" ]; then
    ok "$N8N_HOST resolves"
  else
    bad "$N8N_HOST does not resolve"
  fi
else
  warn "DNS check skipped until .env is complete"
fi

echo
echo "── OpenAI ────────────────────────────────────────"
if [ "$ENV_READY" -eq 1 ]; then
  response_file="$(mktemp)"
  http_status="$(curl --silent --show-error --output "$response_file" --write-out "%{http_code}" \
    https://api.openai.com/v1/responses \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"gpt-5.4-mini-2026-03-17","input":"Reply with the single word: ready","max_output_tokens":16,"reasoning":{"effort":"low"}}')" || http_status="000"
  if [ "$http_status" = "200" ]; then
    ok "OpenAI responded 200 for the pinned model"
  else
    bad "OpenAI returned HTTP $http_status"
  fi
  rm -f "$response_file"
else
  warn "OpenAI check skipped until .env is complete"
fi

echo
echo "── Python packages ───────────────────────────────"
for package in reportlab pypdf PIL; do
  if "$PYTHON_BIN" -c "import $package" 2>/dev/null; then
    ok "python: $package"
  else
    warn "python: $package missing (needed for Stage 3)"
  fi
done

echo
if [ "$FAIL" -eq 0 ]; then
  printf "\033[32mStage 0 gate PASSED\033[0m\n"
else
  printf "\033[31mStage 0 gate FAILED — fix the ✗ items above\033[0m\n"
fi
exit "$FAIL"
