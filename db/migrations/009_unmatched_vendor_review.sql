CREATE OR REPLACE FUNCTION unmatched_vendor_review()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.vendor_id IS NULL AND NEW.status = 'ON_FILE' THEN
    NEW.status := 'NEEDS_REVIEW';
    NEW.validation_flags := COALESCE(NEW.validation_flags, '[]'::jsonb) || '[{"code":"POSSIBLE_DUPLICATE_VENDOR","severity":"hard"}]'::jsonb;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_unmatched_vendor_review ON certificates;
CREATE TRIGGER trg_unmatched_vendor_review BEFORE INSERT OR UPDATE ON certificates
FOR EACH ROW EXECUTE FUNCTION unmatched_vendor_review();
