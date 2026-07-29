#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a; source .env; set +a
COMPOSE=(docker compose --project-name vendor-coi-chasing --env-file .env -f infra/docker-compose.yml)
Q() {
  "${COMPOSE[@]}" exec -T postgres psql -v ON_ERROR_STOP=1 -Atq \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"
}

FAIL=0
ok() { printf '  [ok] %s\n' "$1"; }
bad() { printf '  [x] %s\n' "$1" >&2; FAIL=1; }
check() {
  [ "$2" = "$3" ] && ok "$1 = $3" || bad "$1: expected $2, got $3"
}

check "application tables" 9 "$(Q "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' AND table_name <> 'schema_migrations'")"
check "views" 5 "$(Q "SELECT count(*) FROM information_schema.views WHERE table_schema = 'public'")"
for table in client_config holder_entities trade_requirements vendors vendor_aliases certificates coverages outreach_log dead_letter; do
  [ "$(Q "SELECT to_regclass('public.$table') IS NOT NULL")" = "t" ] && ok "table $table" || bad "table $table missing"
done

check "client_config rows" 26 "$(Q "SELECT count(*) FROM client_config")"
check "trade requirements" 11 "$(Q "SELECT count(*) FROM trade_requirements")"
check "holder entities" 3 "$(Q "SELECT count(*) FROM holder_entities")"
check "vendors" 18 "$(Q "SELECT count(*) FROM vendors")"
check "WC-exempt vendors" 6 "$(Q "SELECT count(*) FROM vendors WHERE wc_exempt")"

placeholder_count="$(Q "SELECT count(*) FROM client_config WHERE value LIKE 'CHANGE_ME%'")"
check "config placeholders" 0 "$placeholder_count"
dashboard_value="$(Q "SELECT value FROM client_config WHERE key = 'dashboard_token'")"
[ "$dashboard_value" = "$DASHBOARD_TOKEN" ] && ok "dashboard token matches .env" \
  || bad "dashboard token does not match .env"

if rg -n --glob '*.sql' 'CURRENT_DATE' db/migrations db/queries >/dev/null; then
  bad "CURRENT_DATE found in database SQL"
else
  ok "timezone-safe date expressions"
fi

today="$(Q "SELECT today FROM v_today")"
[ -n "$today" ] && ok "v_today = $today" || bad "v_today returned no date"
check "v_vendor_status rows" 18 "$(Q "SELECT count(*) FROM v_vendor_status")"
check "NEVER_RECEIVED vendors" 18 "$(Q "SELECT count(*) FROM v_vendor_status WHERE bucket = 'NEVER_RECEIVED'")"
check "grey vendors" 18 "$(Q "SELECT count(*) FROM v_vendor_status WHERE colour = 'grey'")"
check "normalised Kessler" "kessler heating air" "$(Q "SELECT normalised_name FROM vendors WHERE legal_name = 'Kessler Heating & Air Inc'")"
dashboard_rows="$(cat db/queries/q_dashboard.sql | "${COMPOSE[@]}" exec -T postgres \
  psql -v ON_ERROR_STOP=1 -Atq -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  | wc -l | tr -d ' ')"
check "dashboard query rows" 18 "$dashboard_rows"

if [ "$FAIL" -eq 0 ]; then
  echo "Stage 2 gate PASSED"
else
  echo "Stage 2 gate FAILED" >&2
fi
exit "$FAIL"
