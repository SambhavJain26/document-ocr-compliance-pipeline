-- $1 = vendor_id
UPDATE outreach_log
SET awaiting_reply = false, closed_at = now(), close_reason = 'CERTIFICATE_RECEIVED'
WHERE vendor_id = $1 AND awaiting_reply
RETURNING id;
