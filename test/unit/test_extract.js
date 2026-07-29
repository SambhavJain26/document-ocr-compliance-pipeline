import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { buildRequest } from '../../n8n/code/02_build_request.js';
import { parseResponse } from '../../n8n/code/03_parse_response.js';
import { validate } from '../../n8n/code/04_validate.js';
import { parseISODate } from '../../n8n/code/lib/dates.js';
import { normaliseName } from '../../n8n/code/lib/normalise.js';

const schemaPath = new URL('../../extraction/schema/coi_extraction.schema.json', import.meta.url);
const promptPath = new URL('../../extraction/prompts/extract.system.md', import.meta.url);
const base = {
  is_certificate_of_insurance: true, vendor_legal_name: 'Vaughn Electric Co',
  certificate_holder: 'Harbourline Property Management LLC', certificate_date: '2026-01-15',
  extraction_confidence: 'HIGH', confidence_reason: null,
  coverages: [
    { type: 'GENERAL_LIABILITY', effective_date: '2026-01-01', expiration_date: '2027-01-01', each_occurrence: 1_000_000, general_aggregate: 2_000_000 },
    { type: 'WORKERS_COMP', effective_date: '2026-01-01', expiration_date: '2027-01-01', each_occurrence: null, general_aggregate: null },
  ],
};
const matchedContext = {
  holders: [{ legal_name: 'Harbourline Property Management LLC', normalised: 'harbourline property management' }],
  vendors: [{ id: 42, legal_name: 'Vaughn Electric Co', normalised_name: 'vaughn electric' }],
};
const codes = (result) => result.flags.map((flag) => flag.code);
const clone = (change) => ({ ...base, ...change });

test('schema is strict at every object and all properties are required', async () => {
  const schema = JSON.parse(await readFile(schemaPath, 'utf8'));
  const assertStrict = (node) => {
    if (node?.type === 'object') {
      assert.equal(node.additionalProperties, false);
      assert.deepEqual(Object.keys(node.properties).sort(), [...node.required].sort());
      Object.values(node.properties).forEach(assertStrict);
    }
    if (node?.type === 'array') assertStrict(node.items);
  };
  assertStrict(schema);
});

test('system prompt retains the confidence and no-inference guardrails', async () => {
  const prompt = await readFile(promptPath, 'utf8');
  for (const phrase of ['Never infer', 'Do not carry a limit down', 'INSURED is the vendor', 'CONFIDENCE', 'Bias toward LOW']) {
    assert.match(prompt, new RegExp(phrase));
  }
});

test('request builder uses text or a previously uploaded file without an API key', () => {
  const common = { model_id: 'gpt-5.4-mini-2026-03-17', system_prompt: 'extract', schema: { type: 'object' } };
  const text = buildRequest({ ...common, document_text: 'certificate text' });
  const file = buildRequest({ ...common, file_id: 'file_123', is_scanned: true });
  assert.equal(text.body.input[0].content[0].type, 'input_text');
  assert.match(text.body.input[0].content[0].text, /certificate text/);
  assert.equal(file.body.input[0].content[0].file_id, 'file_123');
  assert.equal(file.body.reasoning.effort, 'medium');
  assert.equal(file.body.store, false);
  assert.throws(() => buildRequest(common), /document_text or file_id/);
});

test('response parser handles success and every expected failure shape', () => {
  assert.deepEqual(parseResponse({ output_text: '{"ok":true}' }), { ok: true, value: { ok: true } });
  assert.equal(parseResponse({ status: 429 }).error, 'MODEL_RETRYABLE');
  assert.equal(parseResponse({ statusCode: 503 }).error, 'MODEL_RETRYABLE');
  assert.equal(parseResponse({ status: 'incomplete', incomplete_details: { reason: 'max_output_tokens' } }).error, 'MODEL_INCOMPLETE');
  assert.equal(parseResponse({ output: [{ content: [{ type: 'refusal', refusal: 'no' }] }] }).error, 'MODEL_REFUSED');
  assert.equal(parseResponse({ output: [] }).error, 'MODEL_EMPTY');
  assert.equal(parseResponse({ output_text: 'not json' }).error, 'JSON_PARSE_FAILED');
  assert.equal(parseResponse({ body: '{bad json' }).error, 'MODEL_INVALID_RESPONSE');
});

test('date helper rejects impossible calendar dates', () => {
  assert.equal(parseISODate('2026-02-30'), null);
  assert.ok(parseISODate('2026-02-28'));
});

test('rule 1 rejects inverted coverage dates', () => {
  const result = validate(clone({ coverages: [{ ...base.coverages[0], effective_date: '2027-01-01', expiration_date: '2026-01-01' }] }));
  assert.equal(result.status, 'NEEDS_REVIEW');
  assert.ok(codes(result).includes('DATE_INVERTED'));
});

test('rule 2 rejects malformed and implausible dates', () => {
  const malformed = validate(clone({ coverages: [{ ...base.coverages[0], effective_date: '2026-02-30' }] }));
  const implausible = validate(clone({ coverages: [{ ...base.coverages[0], expiration_date: '2030-01-01' }] }));
  assert.ok(codes(malformed).includes('DATE_UNPARSEABLE'));
  assert.ok(codes(implausible).includes('DATE_IMPLAUSIBLE'));
});

test('rules 3, 5, and 11 surface absent GL and low per-trade limits', () => {
  const missing = validate(clone({ coverages: [{ ...base.coverages[1] }] }));
  const low = validate(
    clone({ coverages: [{ ...base.coverages[0], each_occurrence: 900_000, general_aggregate: 1_900_000 }] }),
    {},
    { trade_requirement: { trade: 'Electrical', min_each_occurrence: 1_000_000, min_general_aggregate: 2_000_000 } },
  );
  assert.ok(codes(missing).includes('NO_GL_LINE'));
  assert.ok(codes(low).includes('LIMIT_BELOW_MINIMUM'));
  assert.ok(codes(low).includes('AGGREGATE_BELOW_MINIMUM'));
});

test('rules 4 and 12 match any accepted holder entity', () => {
  const mismatch = validate(base, {}, { holders: [{ legal_name: 'Other Entity LLC', normalised: 'other entity' }] });
  const alternate = validate(
    clone({ certificate_holder: 'Sable Court Properties LLC' }),
    {},
    { holders: [{ legal_name: 'Harbourline Property Management LLC', normalised: 'harbourline property management' }, { legal_name: 'Sable Court Properties LLC', normalised: 'sable court properties' }] },
  );
  assert.ok(codes(mismatch).includes('HOLDER_MISMATCH'));
  assert.equal(alternate.holder_match, true);
  assert.equal(alternate.holder_matched_entity, 'Sable Court Properties LLC');
});

test('rules 6 and 7 gate low confidence and non-certificates', () => {
  const low = validate(clone({ extraction_confidence: 'LOW', confidence_reason: 'Expiration date is blurry.' }));
  const nonCoi = validate(clone({ is_certificate_of_insurance: false }));
  assert.ok(codes(low).includes('LOW_CONFIDENCE'));
  assert.equal(low.status, 'NEEDS_REVIEW');
  assert.equal(nonCoi.outcome, 'REJECT');
  assert.equal(nonCoi.reason_code, 'NOT_A_COI');
});

test('rules 8 and 9 prevent stale supersedes and show coverage gaps', () => {
  const old = validate(
    clone({ certificate_date: '2025-01-15' }),
    {},
    { ...matchedContext, existing_certificate: { id: 8, certificate_date: '2026-01-01', earliest_expiration: '2026-01-01' } },
  );
  const gap = validate(
    clone({ coverages: base.coverages.map((coverage) => ({ ...coverage, effective_date: '2026-01-15' })) }),
    {},
    { ...matchedContext, existing_certificate: { id: 8, certificate_date: '2025-12-01', earliest_expiration: '2026-01-01' } },
  );
  assert.ok(codes(old).includes('OLDER_THAN_ON_FILE'));
  assert.equal(gap.coverage_gap_days, 14);
  assert.ok(codes(gap).includes('COVERAGE_GAP'));
});

test('rule 10 suppresses the workers compensation flag for an exempt vendor', () => {
  const noWc = clone({ coverages: [{ ...base.coverages[0] }] });
  const required = validate(noWc);
  const exempt = validate(noWc, {}, { vendor: { wc_exempt: true } });
  assert.ok(codes(required).includes('NO_WC_LINE'));
  assert.ok(!codes(exempt).includes('NO_WC_LINE'));
});

test('rule 13 routes a near vendor match to human review rather than merging', () => {
  const result = validate(
    clone({ vendor_legal_name: 'Mercer Plumbing' }),
    {},
    { vendors: [{ id: 9, legal_name: 'Mercer Plumbing & Heating LLC', normalised_name: 'mercer plumbing heating' }] },
  );
  assert.equal(result.vendor_action, 'REVIEW');
  assert.equal(result.vendor_id, null);
  assert.ok(codes(result).includes('POSSIBLE_DUPLICATE_VENDOR'));
});

test('normalises known suffixes without inventing a vendor match', () => {
  assert.equal(normaliseName('Kessler Heating & Air Inc.'), 'kessler heating air');
  assert.equal(normaliseName('Sable Court Properties L.L.C.'), 'sable court properties');
});
