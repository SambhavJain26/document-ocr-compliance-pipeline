SELECT
  vendor_id, display_name, legal_name, trade, certificate_id, certificate_status,
  certificate_date, certificate_holder, holder_match, extraction_confidence,
  confidence_reason, extraction_method, validation_flags,
  cancellation_notice_wording, coverage_gap_days, stored_path,
  earliest_expiration, coverage_line_count, has_gl, has_wc,
  gl_each_occurrence, gl_general_aggregate, earliest_insurer,
  earliest_policy_number, days_to_expiry, bucket, colour, today,
  chase_paused, wc_exempt
FROM v_vendor_status
ORDER BY CASE bucket
  WHEN 'NEVER_RECEIVED' THEN 0 WHEN 'EXPIRED' THEN 1
  WHEN 'NEEDS_REVIEW' THEN 2 WHEN 'D14' THEN 3 WHEN 'D30' THEN 4
  WHEN 'D60' THEN 5 WHEN 'RE_ATTEST' THEN 6 WHEN 'PAUSED' THEN 7 ELSE 8
END, earliest_expiration NULLS FIRST, display_name;
