#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a; source .env; set +a
COMPOSE=(docker compose --project-name vendor-coi-chasing --env-file .env -f infra/docker-compose.yml)

"${COMPOSE[@]}" exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<'SQL'
BEGIN;
TRUNCATE coverages, certificates, outreach_log, dead_letter RESTART IDENTITY CASCADE;
UPDATE vendors SET chase_paused = false, chase_paused_at = NULL,
  chase_paused_by = NULL, chase_paused_note = NULL, last_attested_at = NULL;
COMMIT;
SELECT bucket, count(*) FROM v_vendor_status GROUP BY bucket ORDER BY bucket;
SQL
MSYS_NO_PATHCONV=1 "${COMPOSE[@]}" exec -T n8n sh -c 'rm -rf /data/certs/* 2>/dev/null || true'
echo "Demo state restored."
