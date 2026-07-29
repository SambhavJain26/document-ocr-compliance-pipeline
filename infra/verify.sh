#!/usr/bin/env bash
set -euo pipefail

COMPOSE=(
  docker compose
  --project-name vendor-coi-chasing
  --env-file .env
  -f infra/docker-compose.yml
)

pass() { printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { printf "  \033[31m✗\033[0m %s\n" "$1" >&2; exit 1; }

for container in vendor-coi-chasing-postgres-1 vendor-coi-chasing-n8n-1; do
  status="$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || true)"
  [ "$status" = "healthy" ] || fail "$container is not healthy"
  pass "$container healthy"
done

postgres_user="$(docker exec vendor-coi-chasing-postgres-1 printenv POSTGRES_USER)"
postgres_db="$(docker exec vendor-coi-chasing-postgres-1 printenv POSTGRES_DB)"
database_count="$("${COMPOSE[@]}" exec -T postgres \
  psql -U "$postgres_user" -d "$postgres_db" -Atc \
  "SELECT count(*) FROM pg_database WHERE datname IN ('coi','n8n');")"
[ "$database_count" = "2" ] || fail "expected coi and n8n databases"
pass "coi and n8n databases exist"

if [ -n "$(docker port vendor-coi-chasing-postgres-1)" ]; then
  fail "PostgreSQL publishes a host port"
fi
pass "PostgreSQL has no published host port"

n8n_binding="$(docker port vendor-coi-chasing-n8n-1 5678/tcp)"
[ "$n8n_binding" = "127.0.0.1:5678" ] || fail "unexpected n8n binding: $n8n_binding"
pass "n8n is loopback-only on port 5678"

health_response="$(curl --silent --show-error --fail http://localhost:5678/healthz)"
[ "$health_response" = '{"status":"ok"}' ] || fail "unexpected n8n health response"
pass "n8n health endpoint returned OK"

logs="$("${COMPOSE[@]}" logs --no-color n8n)"
grep -q 'Registered runner "JS Task Runner"' <<<"$logs" \
  || fail "JavaScript task runner did not register"
pass "JavaScript task runner registered"

python_warning_count="$(grep -c 'Failed to start Python task runner' <<<"$logs" || true)"
[ "$python_warning_count" -le 1 ] || fail "Python availability warning repeated"
pass "no repeating Python runner failure"

printf "\033[32mLocal infrastructure gate PASSED\033[0m\n"
