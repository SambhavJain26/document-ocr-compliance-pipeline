SELECT o.id AS outreach_id, o.vendor_id, o.bucket, o.recipient, o.sent_at,
  o.follow_up_due, o.attempt_number, v.display_name, v.legal_name,
  v.producer_email, (SELECT today FROM v_today) AS today,
  CASE WHEN o.attempt_number >=
    (SELECT value::int FROM client_config WHERE key = 'max_chase_attempts')
    THEN 'ESCALATE' ELSE 'REOPEN' END AS action
FROM outreach_log o
JOIN vendors v ON v.id = o.vendor_id
WHERE o.awaiting_reply AND o.sent_at IS NOT NULL AND o.approved IS TRUE
  AND NOT o.escalated
  AND o.follow_up_due <= (SELECT today FROM v_today)
  AND NOT EXISTS (
    SELECT 1 FROM certificates c
    WHERE c.vendor_id = o.vendor_id AND c.received_at > o.sent_at
      AND c.status = 'ON_FILE'
  )
ORDER BY o.follow_up_due;
