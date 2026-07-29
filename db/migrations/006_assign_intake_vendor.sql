CREATE OR REPLACE FUNCTION assign_intake_vendor()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE norm TEXT;
BEGIN
  IF NEW.vendor_id IS NULL AND NEW.raw_extraction ? 'vendor_legal_name' THEN
    norm := trim(regexp_replace(regexp_replace(lower(COALESCE(NEW.raw_extraction->>'vendor_legal_name','')), '(^| )(llc|inc|ltd|corp|co|company)( |$)', ' ', 'g'), ' +', ' ', 'g'));
    SELECT id INTO NEW.vendor_id FROM vendors WHERE active AND normalised_name = norm LIMIT 1;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_assign_intake_vendor ON certificates;
CREATE TRIGGER trg_assign_intake_vendor BEFORE INSERT ON certificates FOR EACH ROW EXECUTE FUNCTION assign_intake_vendor();
