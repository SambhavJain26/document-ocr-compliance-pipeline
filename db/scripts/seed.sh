#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a; source .env; set +a
COMPOSE=(docker compose --project-name vendor-coi-chasing --env-file .env -f infra/docker-compose.yml)
PSQL=("${COMPOSE[@]}" exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB")

[ -n "${DASHBOARD_TOKEN:-}" ] && [[ "$DASHBOARD_TOKEN" != *CHANGE_ME* ]] || {
  echo "DASHBOARD_TOKEN must be set in .env" >&2
  exit 1
}

{
  cat <<'SQL'
CREATE TEMP TABLE vendor_import (
  legal_name TEXT, display_name TEXT, trade TEXT, contact_email TEXT,
  producer_name TEXT, producer_email TEXT, wc_exempt BOOLEAN, notes TEXT
);
\copy vendor_import FROM STDIN WITH (FORMAT csv, HEADER true)
SQL
  cat db/seeds/vendors.csv
  cat <<'SQL'
\.
UPDATE vendors v SET
  display_name = i.display_name,
  normalised_name = btrim(regexp_replace(regexp_replace(regexp_replace(lower(i.legal_name),
    '(^|[[:space:]])(llc|l\.l\.c\.|inc|inc\.|incorporated|corp|corp\.|corporation|co|co\.|company|ltd|ltd\.|limited|lp|llp|pllc|pc|dba)([[:space:]]|$)', ' ', 'g'),
    '[^a-z0-9 ]', ' ', 'g'), '\s+', ' ', 'g')),
  trade = COALESCE(i.trade, 'DEFAULT'),
  contact_email = i.contact_email,
  producer_name = i.producer_name,
  producer_email = i.producer_email,
  wc_exempt = COALESCE(i.wc_exempt, false),
  updated_at = now()
FROM vendor_import i
WHERE v.legal_name = i.legal_name;

INSERT INTO vendors (legal_name, display_name, normalised_name, trade,
                     contact_email, producer_name, producer_email, wc_exempt)
SELECT i.legal_name, i.display_name,
  btrim(regexp_replace(regexp_replace(regexp_replace(lower(i.legal_name),
    '(^|[[:space:]])(llc|l\.l\.c\.|inc|inc\.|incorporated|corp|corp\.|corporation|co|co\.|company|ltd|ltd\.|limited|lp|llp|pllc|pc|dba)([[:space:]]|$)', ' ', 'g'),
    '[^a-z0-9 ]', ' ', 'g'), '\s+', ' ', 'g')),
  COALESCE(i.trade, 'DEFAULT'), i.contact_email, i.producer_name,
  i.producer_email, COALESCE(i.wc_exempt, false)
FROM vendor_import i
WHERE NOT EXISTS (SELECT 1 FROM vendors v WHERE v.legal_name = i.legal_name);
SQL
} | "${PSQL[@]}"

"${PSQL[@]}" -q -v dashboard_token="$DASHBOARD_TOKEN" <<'SQL'
INSERT INTO client_config (key, value, description)
VALUES ('dashboard_token', :'dashboard_token', 'Matches local DASHBOARD_TOKEN')
ON CONFLICT (key) DO UPDATE
  SET value = EXCLUDED.value, description = EXCLUDED.description, updated_at = now();
SQL
echo "Reference data and vendors seeded."
