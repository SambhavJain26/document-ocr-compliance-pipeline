CREATE OR REPLACE FUNCTION process_intake(p JSONB)
RETURNS TABLE(certificate_id INT, was_insert BOOLEAN, outcome TEXT, reason_code TEXT)
LANGUAGE plpgsql AS $$
DECLARE
  ex JSONB := p->'extraction'; c_id INT; vendor INT; inserted BOOLEAN;
  flags JSONB := '[]'::jsonb; status_value TEXT := 'ON_FILE'; cov JSONB;
BEGIN
  IF COALESCE((ex->>'is_certificate_of_insurance')::boolean, false) = false THEN
    INSERT INTO dead_letter(source, source_ref, original_filename, content_sha256, reason_code, reason_detail, raw_payload)
    VALUES (p->>'source', p->>'source_ref', p->>'original_filename', p->>'content_sha256', 'NOT_A_COI',
            COALESCE(ex->>'confidence_reason','Document is not a certificate of insurance.'), p);
    RETURN QUERY SELECT NULL::INT, false, 'REJECT', 'NOT_A_COI'; RETURN;
  END IF;
  SELECT id INTO vendor FROM vendors WHERE active AND normalised_name = lower(regexp_replace(regexp_replace(COALESCE(ex->>'vendor_legal_name',''), '[^a-z0-9 ]', '', 'g'), '\m(llc|inc|ltd|corp|co|company)\M', '', 'g')) LIMIT 1;
  IF ex->>'extraction_confidence' = 'LOW' THEN flags := flags || '[{"code":"LOW_CONFIDENCE","severity":"hard"}]'; status_value := 'NEEDS_REVIEW'; END IF;
  FOR cov IN SELECT value FROM jsonb_array_elements(COALESCE(ex->'coverages','[]'::jsonb)) LOOP
    IF NULLIF(cov->>'effective_date','') IS NOT NULL AND NULLIF(cov->>'expiration_date','') IS NOT NULL
       AND (cov->>'expiration_date')::date <= (cov->>'effective_date')::date THEN
      flags := flags || jsonb_build_array(jsonb_build_object('code','DATE_INVERTED','severity','hard','coverage_type',cov->>'type'));
      status_value := 'NEEDS_REVIEW';
    END IF;
  END LOOP;
  INSERT INTO certificates(vendor_id,source,source_ref,original_filename,content_sha256,byte_size,certificate_date,certificate_holder,extraction_confidence,confidence_reason,extraction_method,model_id,input_tokens,output_tokens,raw_extraction,validation_flags,status,cancellation_notice_wording,description_of_operations)
  VALUES(vendor,p->>'source',p->>'source_ref',p->>'original_filename',p->>'content_sha256',(p->>'byte_size')::int,
         NULLIF(ex->>'certificate_date','')::date,ex->>'certificate_holder',ex->>'extraction_confidence',ex->>'confidence_reason',p->>'extraction_method','gpt-5.4-mini-2026-03-17',(p->>'input_tokens')::int,(p->>'output_tokens')::int,ex,flags,status_value,ex->>'cancellation_notice_wording',ex->>'description_of_operations')
  ON CONFLICT(content_sha256) DO UPDATE SET raw_extraction=EXCLUDED.raw_extraction, validation_flags=EXCLUDED.validation_flags, status=EXCLUDED.status, status_set_at=now()
  RETURNING id,(xmax=0) INTO c_id,inserted;
  IF inserted THEN
    INSERT INTO coverages(certificate_id,coverage_type,insurer_name,naic,policy_number,effective_date,expiration_date,each_occurrence,general_aggregate,addl_insd_asserted,subr_wvd_asserted)
    SELECT c_id, value->>'type',value->>'insurer_name',value->>'naic',value->>'policy_number',NULLIF(value->>'effective_date','')::date,NULLIF(value->>'expiration_date','')::date,NULLIF(value->>'each_occurrence','')::numeric,NULLIF(value->>'general_aggregate','')::numeric,NULLIF(value->>'addl_insd_asserted','')::boolean,NULLIF(value->>'subr_wvd_asserted','')::boolean FROM jsonb_array_elements(COALESCE(ex->'coverages','[]'::jsonb));
    IF vendor IS NOT NULL THEN UPDATE certificates SET status='SUPERSEDED',superseded_by=c_id,status_set_at=now() WHERE vendor_id=vendor AND id<>c_id AND status IN ('ON_FILE','NEEDS_REVIEW'); END IF;
  END IF;
  RETURN QUERY SELECT c_id, inserted, 'STORE', NULL::TEXT;
END $$;
