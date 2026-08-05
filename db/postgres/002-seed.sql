BEGIN;

INSERT INTO client_config(key, value) VALUES
  ('min_each_occurrence', '1000000'),
  ('min_general_aggregate', '2000000'),
  ('from_mailbox', 'demo@example.test'),
  ('reminder_days', '60,30,14,0'),
  ('reattest_days', '90'),
  ('approval_channel', 'email'),
  ('telegram_chat_id', ''),
  ('timezone', 'America/New_York'),
  -- gpt-5.4-nano was the original default and is no longer usable here: it reads
  -- the watermarked synthetic fixtures as "not a certificate" even on the clean
  -- happy-path document. coi-demo-build-plan.md warned against the nano tier for
  -- exactly this reason and recommended the mini tier. Verified 2026-08-05: mini
  -- files all seven demo fixtures and still refuses f11-not-a-certificate.
  ('model_id', 'gpt-5.4-mini'),
  ('model_id_fallback', 'gpt-5.6-luna')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value;

INSERT INTO holder_entities(legal_name, is_primary) VALUES
  ('Harbourline Property Management LLC', true),
  ('Harbourline Oakview Owner LLC', false),
  ('Harbourline Cedar Flats LLC', false)
ON CONFLICT (legal_name) DO UPDATE
SET is_primary = EXCLUDED.is_primary;

INSERT INTO trade_requirements(trade, min_each_occurrence, min_general_aggregate, wc_required) VALUES
  ('DEFAULT', 1000000, 2000000, true),
  ('Roofing', 2000000, 4000000, true),
  ('Landscaping', 500000, 1000000, true)
ON CONFLICT (trade) DO UPDATE
SET
  min_each_occurrence = EXCLUDED.min_each_occurrence,
  min_general_aggregate = EXCLUDED.min_general_aggregate,
  wc_required = EXCLUDED.wc_required;

WITH seed_vendors(legal_name, trade, wc_exempt, contact_email, producer_name, producer_email, producer_phone) AS (
  VALUES
    ('Apex Plumbing Services LLC', 'Plumbing', false, 'apex-plumbing@example.test', 'Northgate Risk Partners', 'certs+northgate@example.test', '555-0101'),
    ('Blue Ridge HVAC Co.', 'HVAC', false, 'blue-ridge-hvac@example.test', 'Cardinal Coverage Group', 'certs+cardinal@example.test', '555-0102'),
    ('Circuit Square Electric LLC', 'Electrical', false, 'circuit-square@example.test', 'Ironvale Insurance Services', 'certs+ironvale@example.test', '555-0103'),
    ('Summit Shield Roofing Inc.', 'Roofing', false, 'summit-shield@example.test', 'Northgate Risk Partners', 'certs+summit@example.test', '555-0104'),
    ('Greenline Groundskeeping LLC', 'Landscaping', false, 'greenline@example.test', 'Cardinal Coverage Group', 'certs+greenline@example.test', '555-0105'),
    ('Clearway Pest Control LLC', 'Pest Control', false, 'clearway-pest@example.test', 'Ironvale Insurance Services', 'certs+clearway@example.test', '555-0106'),
    ('Bright Hall Cleaning Co.', 'Cleaning', false, 'bright-hall@example.test', 'Northgate Risk Partners', 'certs+bright-hall@example.test', '555-0107'),
    ('Prime Coat Painting LLC', 'Painting', false, 'prime-coat@example.test', 'Cardinal Coverage Group', 'certs+prime-coat@example.test', '555-0108'),
    ('Anchor Tile and Flooring LLC', 'Flooring', false, 'anchor-tile@example.test', 'Ironvale Insurance Services', 'certs+anchor@example.test', '555-0109'),
    ('Harbor Point General Contractors LLC', 'General Contractor', false, 'harbor-point@example.test', 'Northgate Risk Partners', 'certs+harbor-point@example.test', '555-0110'),
    ('Lockstep Locksmith Services', 'Locksmith', false, 'lockstep@example.test', 'Cardinal Coverage Group', 'certs+lockstep@example.test', '555-0111'),
    ('Evergreen Appliance Repair LLC', 'Appliance Repair', false, 'evergreen-appliance@example.test', 'Ironvale Insurance Services', 'certs+evergreen@example.test', '555-0112'),
    ('Mason Creek Handyman', 'General Contractor', true, 'mason-creek@example.test', 'Northgate Risk Partners', 'certs+mason-creek@example.test', '555-0113'),
    ('Vista Glass and Door LLC', 'Glass and Door', false, 'vista-glass@example.test', 'Cardinal Coverage Group', 'certs+vista@example.test', '555-0114'),
    ('Oakbend Tree Service LLC', 'Tree Service', false, 'oakbend-tree@example.test', 'Ironvale Insurance Services', 'certs+oakbend@example.test', '555-0115'),
    ('Northstar Snow Removal LLC', 'Snow Removal', false, 'northstar-snow@example.test', 'Northgate Risk Partners', 'certs+northstar@example.test', '555-0116'),
    ('Rapid Response Restoration LLC', 'Restoration', false, 'rapid-restoration@example.test', 'Cardinal Coverage Group', 'certs+rapid@example.test', '555-0117'),
    ('Cedar Path Janitorial Services LLC', 'Cleaning', false, 'cedar-path@example.test', 'Ironvale Insurance Services', 'certs+cedar-path@example.test', '555-0118')
)
INSERT INTO vendors(legal_name, trade, wc_exempt, contact_email, producer_name, producer_email, producer_phone)
SELECT legal_name, trade, wc_exempt, contact_email, producer_name, producer_email, producer_phone
FROM seed_vendors
ON CONFLICT (normalised_name) DO UPDATE
SET
  legal_name = EXCLUDED.legal_name,
  trade = EXCLUDED.trade,
  wc_exempt = EXCLUDED.wc_exempt,
  contact_email = EXCLUDED.contact_email,
  producer_name = EXCLUDED.producer_name,
  producer_email = EXCLUDED.producer_email,
  producer_phone = EXCLUDED.producer_phone;

COMMIT;
