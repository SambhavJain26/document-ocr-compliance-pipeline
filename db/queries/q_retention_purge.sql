SELECT c.id, c.stored_path, v.display_name, c.received_at
FROM certificates c
LEFT JOIN vendors v ON v.id = c.vendor_id
WHERE c.stored_path IS NOT NULL AND c.stored_path_purged_at IS NULL
  AND c.received_at < now() - (
    (SELECT value FROM client_config WHERE key = 'pdf_retention_months')
    || ' months')::interval
ORDER BY c.received_at
LIMIT 200;
