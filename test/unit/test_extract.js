import test from 'node:test';import assert from 'node:assert/strict';import {normaliseName} from '../../n8n/code/lib/normalise.js';import {parseISODate} from '../../n8n/code/lib/dates.js';import {validate} from '../../n8n/code/04_validate.js';
const base={is_certificate_of_insurance:true,vendor_legal_name:'Vaughn Electric Co',certificate_holder:'Harbourline Property Management LLC',extraction_confidence:'HIGH',coverages:[{type:'GENERAL_LIABILITY',effective_date:'2026-01-01',expiration_date:'2027-01-01',each_occurrence:1e6,general_aggregate:2e6}]};
test('normalises suffixes',()=>assert.equal(normaliseName('Kessler Heating & Air Inc.'),'kessler heating air'));
test('rejects impossible dates',()=>assert.equal(parseISODate('2026-02-30'),null));
test('flags inverted dates',()=>assert.equal(validate({...base,coverages:[{...base.coverages[0],effective_date:'2027-01-01',expiration_date:'2026-01-01'}]}).status,'NEEDS_REVIEW'));
test('rejects non certificates',()=>assert.equal(validate({...base,is_certificate_of_insurance:false}).status,'REJECTED'));
test('flags missing GL',()=>assert.ok(validate({...base,coverages:[{...base.coverages[0],type:'AUTO'}]}).flags.includes('NO_GL_LINE')));
