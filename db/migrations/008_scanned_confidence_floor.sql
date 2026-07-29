CREATE OR REPLACE FUNCTION scanned_confidence_floor()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.extraction_method = 'vision' AND NEW.extraction_confidence = 'LOW'
     AND COALESCE(NEW.raw_extraction->>'vendor_legal_name','') <> ''
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(NEW.raw_extraction->'coverages','[]'::jsonb)) c WHERE COALESCE(c->>'expiration_date','') <> '') THEN
    NEW.extraction_confidence := 'MEDIUM';
    NEW.confidence_reason := 'Scanned certificate: vendor and expiration date are legible; other fields need review.';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_scanned_confidence_floor ON certificates;
CREATE TRIGGER trg_scanned_confidence_floor BEFORE INSERT OR UPDATE ON certificates
FOR EACH ROW EXECUTE FUNCTION scanned_confidence_floor();
