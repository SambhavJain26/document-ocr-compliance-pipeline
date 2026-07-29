CREATE OR REPLACE FUNCTION unmatched_vendor_review()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.vendor_id IS NOT NULL AND NEW.status='NEEDS_REVIEW' AND COALESCE(NEW.validation_flags,'[]'::jsonb)='[]'::jsonb THEN
    NEW.status := 'ON_FILE';
  ELSIF NEW.vendor_id IS NULL AND NEW.status = 'ON_FILE' THEN
    NEW.status := 'NEEDS_REVIEW';
    NEW.validation_flags := COALESCE(NEW.validation_flags, '[]'::jsonb) || '[{"code":"POSSIBLE_DUPLICATE_VENDOR","severity":"hard"}]'::jsonb;
  END IF;
  RETURN NEW;
END $$;
