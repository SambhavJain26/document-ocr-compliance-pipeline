-- $1 new certificate id, $2 vendor id
UPDATE certificates
SET status = 'SUPERSEDED', superseded_by = $1, status_set_at = now(),
  status_set_by = 'system'
WHERE vendor_id = $2 AND id <> $1
  AND status IN ('ON_FILE','NEEDS_REVIEW')
RETURNING id;
