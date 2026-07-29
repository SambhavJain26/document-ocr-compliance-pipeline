import test from 'node:test';
import assert from 'node:assert/strict';
import { normaliseForm } from '../../n8n/code/00_normalise_form.js';
import { preflight } from '../../n8n/code/01_preflight.js';
import { splitAttachments } from '../../n8n/code/03_split_attachments.js';

const pdf = Buffer.from('%PDF-1.7\\nsynthetic certificate');
const binary = (name = 'certificate.pdf', bytes = pdf) => ({
  data: bytes.toString('base64'), fileName: name, mimeType: 'application/pdf',
});

test('form files normalize to one routable intake item each', () => {
  const output = normaliseForm({ json: { submittedAt: '2026-07-30T00:00:00Z' }, binary: { certificate_0: binary(), certificate_1: binary('renewal.pdf') } });
  assert.equal(output.length, 2);
  assert.equal(output[0].json.source, 'form');
  assert.equal(output[1].json.original_filename, 'renewal.pdf');
});

test('preflight computes an idempotency hash and content-addressed path', () => {
  const output = preflight({ json: { source: 'form' }, binary: { data: binary() } }, new Date('2026-07-30T00:00:00Z'));
  assert.equal(output.json.preflight_ok, true);
  assert.match(output.json.content_sha256, /^[a-f0-9]{64}$/);
  assert.match(output.json.stored_path, /^\/data\/certs\/2026\/07\/[a-f0-9]{64}\.pdf$/);
});

test('preflight rejects missing, non-PDF, oversized, and encrypted payloads', () => {
  assert.equal(preflight({ json: {} }).json.reason_code, 'EMPTY_ATTACHMENT');
  assert.equal(preflight({ json: {}, binary: { data: binary('notes.txt', Buffer.from('not a pdf')) } }).json.reason_code, 'NOT_A_PDF');
  const large = Buffer.concat([Buffer.from('%PDF-'), Buffer.alloc(25 * 1024 * 1024)]);
  assert.equal(preflight({ json: {}, binary: { data: binary('large.pdf', large) } }).json.reason_code, 'NOT_A_PDF');
  assert.equal(preflight({ json: {}, binary: { data: binary('locked.pdf', Buffer.from('%PDF-1.7\\ntrailer\\n/Encrypt')) } }).json.reason_code, 'PDF_ENCRYPTED');
});

test('Gmail splitter emits each PDF and does not fetch portal links', () => {
  const attachments = splitAttachments([{
    json: { id: 'mail-1', payload: { headers: [{ name: 'From', value: 'agent@example.test' }, { name: 'Subject', value: 'Certificates' }] } },
    binary: { attachment_0: binary('a.pdf'), attachment_1: binary('b.pdf'), image: { fileName: 'logo.png', mimeType: 'image/png', data: 'x' } },
  }]);
  const portal = splitAttachments([{ json: { id: 'mail-2', subject: 'Retrieve certificate', text: 'https://portal.vendorfiles.example/download' } }]);
  assert.equal(attachments.length, 2);
  assert.deepEqual(attachments.map((item) => item.json.original_filename), ['a.pdf', 'b.pdf']);
  assert.equal(portal[0].json.reason_code, 'NO_ATTACHMENT_PORTAL_LINK');
  assert.equal(portal[0].json.preflight_ok, false);
});
