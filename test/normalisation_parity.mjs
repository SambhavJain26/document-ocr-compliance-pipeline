import { execFileSync } from 'node:child_process';
import { normaliseName } from '../n8n/code/lib/normalise.js';

const values = [
  'Kessler Heating & Air Inc.', 'Sable Court Properties L.L.C.', 'Vaughn Electric Co',
  'Mercer Plumbing & Heating LLC', 'Atlas Roofing, Incorporated', 'Northstar Cleaning Company',
  'Prime Pest Control Corp.', 'Redwood Landscaping Ltd', 'Bluebird Painting Limited',
  'Mason General Contracting LP', 'Horizon Handyman LLP', 'Apex Fire Safety PLLC',
  'Cedar Millwork PC', 'Foxtrot Facilities DBA Brightside', "O'Brien Restoration LLC",
  'The Acme Co.', 'ACME CORPORATION', 'Acme, Inc', 'Acme L.L.C.', 'Acme  LLC',
  'Acme--Services', 'Acme / Services', 'Acme.Services', 'Acme (Services)',
  'Acme  Services', '  Acme Services  ', 'Acme & Sons Co', 'Élan Electric LLC',
  '123 Main Street Company', 'No Suffix Vendor',
];
const sqlLiteral = (value) => '\'' + value.replaceAll('\'', '\'\'') + '\'';
const rows = values.map((value, index) => '(' + (index + 1) + ', ' + sqlLiteral(value) + ')').join(', ');
const query = 'WITH input(id, raw) AS (VALUES ' + rows + ') ' +
  'SELECT btrim(regexp_replace(regexp_replace(regexp_replace(lower(raw), ' +
  '\'(^|[^a-z0-9])(l[.]l[.]c[.]?|llc|incorporated|inc[.]?|corporation|corp[.]?|company|co[.]?|limited|ltd[.]?|pllc|llp|lp|pc|dba)([^a-z0-9]|$)\', \'\\1 \', \'g\'), ' +
  '\'[^a-z0-9 ]\', \' \', \'g\'), \'[[:space:]]+\', \' \', \'g\')) FROM input ORDER BY id;';
const output = execFileSync(
  'docker',
  ['compose', '--project-name', 'vendor-coi-chasing', '--env-file', '.env', '-f', 'infra/docker-compose.yml', 'exec', '-T', 'postgres', 'psql', '-U', 'coi', '-d', 'coi', '-Atq', '-c', query],
  { encoding: 'utf8', cwd: process.cwd() },
).trim().split(/\r?\n/);
const expected = values.map(normaliseName);
if (output.length !== expected.length || output.some((value, index) => value !== expected[index])) {
  throw new Error('SQL/JS normalisation mismatch: ' + JSON.stringify({ output, expected }));
}
console.log('SQL/JS normalisation parity passed for ' + values.length + ' strings');
