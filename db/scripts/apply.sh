#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
set -a; source .env; set +a
COMPOSE=(docker compose --project-name vendor-coi-chasing --env-file .env -f infra/docker-compose.yml)
PSQL=("${COMPOSE[@]}" exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB")

"${PSQL[@]}" -q -f - < db/migrations/000_migrations_table.sql
for migration in db/migrations/*.sql; do
  filename="$(basename "$migration")"
  checksum="$(sha256sum "$migration" | awk '{print $1}')"
  stored="$("${PSQL[@]}" -Atqc "SELECT checksum FROM schema_migrations WHERE filename = '$filename'")"
  if [ -n "$stored" ]; then
    [ "$stored" = "$checksum" ] || { echo "Migration checksum changed: $filename" >&2; exit 1; }
    echo "  $filename (already applied)"
    continue
  fi
  echo "  applying $filename"
  "${PSQL[@]}" -q -f - < "$migration"
  "${PSQL[@]}" -q -c "INSERT INTO schema_migrations (filename, checksum) VALUES ('$filename', '$checksum')"
done
echo "Migrations up to date."
