SELECT s.*,
  COALESCE((
    SELECT MAX(o.attempt_number) FROM outreach_log o
    WHERE o.vendor_id = s.vendor_id AND o.bucket = s.bucket
      AND o.sent_at IS NOT NULL AND NOT o.escalated
  ), 0) + 1 AS attempt_number
FROM v_vendor_status s
WHERE s.bucket IN ('NEVER_RECEIVED','EXPIRED','D14','D30','D60','RE_ATTEST')
  AND NOT s.chase_paused
  AND NOT EXISTS (
    SELECT 1 FROM outreach_log o
    WHERE o.vendor_id = s.vendor_id AND o.bucket = s.bucket
      AND o.created_on = s.today
  )
  AND NOT EXISTS (
    SELECT 1 FROM outreach_log o
    WHERE o.vendor_id = s.vendor_id AND o.bucket = s.bucket AND o.awaiting_reply
  )
  AND COALESCE((
    SELECT MAX(o.attempt_number) FROM outreach_log o
    WHERE o.vendor_id = s.vendor_id AND o.bucket = s.bucket
      AND o.sent_at IS NOT NULL AND NOT o.escalated
  ), 0) < (SELECT value::int FROM client_config WHERE key = 'max_chase_attempts')
ORDER BY CASE s.bucket
  WHEN 'NEVER_RECEIVED' THEN 0 WHEN 'EXPIRED' THEN 1 WHEN 'D14' THEN 2
  WHEN 'D30' THEN 3 WHEN 'D60' THEN 4 ELSE 5
END, s.earliest_expiration NULLS FIRST;
