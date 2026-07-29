CREATE OR REPLACE FUNCTION assign_intake_vendor()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE norm TEXT; filtered JSONB;
BEGIN
  IF NEW.vendor_id IS NULL AND NEW.raw_extraction ? 'vendor_legal_name' THEN
    norm := trim(regexp_replace(regexp_replace(regexp_replace(lower(COALESCE(NEW.raw_extraction->>'vendor_legal_name','')), '[^a-z0-9 ]', ' ', 'g'), '(^| )(llc|inc|ltd|corp|co|company)( |$)', ' ', 'g'), ' +', ' ', 'g'));
    SELECT id INTO NEW.vendor_id FROM vendors WHERE active AND normalised_name = norm LIMIT 1;
  END IF;
  IF NEW.extraction_method='text' AND NEW.extraction_confidence='LOW' AND NEW.raw_extraction ? 'vendor_legal_name' AND jsonb_array_length(COALESCE(NEW.raw_extraction->'coverages','[]'::jsonb))>0 THEN
    NEW.extraction_confidence := 'HIGH';
    NEW.confidence_reason := NULL;
    SELECT COALESCE(jsonb_agg(value),'[]'::jsonb) INTO filtered FROM jsonb_array_elements(COALESCE(NEW.validation_flags,'[]'::jsonb)) WHERE value->>'code' <> 'LOW_CONFIDENCE';
    NEW.validation_flags := filtered;
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION calculate_coverage_gap()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE prior_exp DATE; new_effective DATE; gap INT;
BEGIN
  SELECT MAX(cv.expiration_date) INTO prior_exp FROM certificates prior JOIN coverages cv ON cv.certificate_id=prior.id
  WHERE prior.vendor_id=(SELECT vendor_id FROM certificates WHERE id=NEW.certificate_id) AND prior.id<>NEW.certificate_id AND prior.status IN ('ON_FILE','NEEDS_REVIEW');
  new_effective := NEW.effective_date;
  IF prior_exp IS NOT NULL AND new_effective IS NOT NULL AND new_effective>prior_exp THEN
    gap := new_effective-prior_exp;
    UPDATE certificates SET coverage_gap_days=gap,validation_flags=validation_flags || jsonb_build_array(jsonb_build_object('code','COVERAGE_GAP','severity','soft','gap_days',gap)) WHERE id=NEW.certificate_id;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_calculate_coverage_gap ON coverages;
CREATE TRIGGER trg_calculate_coverage_gap AFTER INSERT ON coverages FOR EACH ROW EXECUTE FUNCTION calculate_coverage_gap();
