-- $1 vendor_id, $2 source, $3 source_ref, $4 original_filename,
-- $5 content_sha256, $6 stored_path, $7 byte_size, $8 page_count,
-- $9 certificate_date, $10 certificate_holder, $11 holder_match,
-- $12 holder_matched_entity, $13 confidence, $14 confidence_reason,
-- $15 extraction_method, $16 model_id, $17 input_tokens, $18 output_tokens,
-- $19 latency_ms, $20 raw_extraction, $21 validation_flags, $22 status,
-- $23 cancellation_notice_wording, $24 description_of_operations,
-- $25 coverage_gap_days.
INSERT INTO certificates (
  vendor_id, source, source_ref, original_filename, content_sha256, stored_path,
  byte_size, page_count, certificate_date, certificate_holder, holder_match,
  holder_matched_entity, extraction_confidence, confidence_reason,
  extraction_method, model_id, input_tokens, output_tokens, latency_ms,
  raw_extraction, validation_flags, status, cancellation_notice_wording,
  description_of_operations, coverage_gap_days
) VALUES (
  $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,
  $20::jsonb,$21::jsonb,$22,$23,$24,$25
)
ON CONFLICT (content_sha256) DO UPDATE SET
  validation_flags = EXCLUDED.validation_flags,
  extraction_confidence = EXCLUDED.extraction_confidence,
  confidence_reason = EXCLUDED.confidence_reason,
  raw_extraction = EXCLUDED.raw_extraction,
  status = EXCLUDED.status,
  status_set_at = now()
RETURNING id, (xmax = 0) AS was_insert;
