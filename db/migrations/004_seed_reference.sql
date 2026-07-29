INSERT INTO trade_requirements
  (trade, min_each_occurrence, min_general_aggregate, wc_required, note)
VALUES
  ('DEFAULT', 1000000, 2000000, true, 'Fallback'),
  ('Roofing', 2000000, 4000000, true, 'Height work'),
  ('Electrical', 1000000, 2000000, true, 'Fire risk'),
  ('Plumbing', 1000000, 2000000, true, 'Water damage risk'),
  ('HVAC', 1000000, 2000000, true, NULL),
  ('General Contracting', 2000000, 4000000, true, 'Structural work'),
  ('Landscaping', 500000, 1000000, false, 'Often sole proprietor'),
  ('Cleaning', 500000, 1000000, false, 'Often sole proprietor'),
  ('Pest Control', 500000, 1000000, true, 'Chemical handling'),
  ('Painting', 500000, 1000000, true, NULL),
  ('Handyman', 500000, 1000000, false, 'Often exempt')
ON CONFLICT (trade) DO NOTHING;

INSERT INTO holder_entities (legal_name, normalised, is_primary, note) VALUES
  ('Harbourline Property Management LLC', 'harbourline property management', true, 'Management company'),
  ('Harbourline Residential Holdings LLC', 'harbourline residential holdings', false, 'Owner LLC'),
  ('Sable Court Properties LLC', 'sable court properties', false, 'Owner LLC')
ON CONFLICT (normalised) DO NOTHING;
