CREATE OR REPLACE FUNCTION normalise_coverage_type()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.coverage_type NOT IN ('GENERAL_LIABILITY','AUTO','UMBRELLA','WORKERS_COMP','OTHER') THEN
    NEW.coverage_type := 'OTHER';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_normalise_coverage_type ON coverages;
CREATE TRIGGER trg_normalise_coverage_type BEFORE INSERT OR UPDATE ON coverages
FOR EACH ROW EXECUTE FUNCTION normalise_coverage_type();
