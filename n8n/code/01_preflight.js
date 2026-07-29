import { createHash } from 'node:crypto';

const MAX_BYTES = 25 * 1024 * 1024;

/**
 * Validate a normalized intake item before PDF extraction or an API request.
 * The n8n Code node uses the same logic inline because Code nodes cannot
 * import repository modules at runtime.
 */
export function preflight(item, now = new Date(), binaryBuffer = null) {
  const j = item.json || {};
  if (j.preflight_ok === false) return { ...item, json: { ...j } };

  const binary = item.binary?.data;
  if (!binary?.data) return reject(item, 'EMPTY_ATTACHMENT', 'No binary payload on the item.');

  // Unit callers provide the inline Base64 representation used by n8n's
  // memory mode. The filesystem-backed production runner supplies the actual
  // bytes via `this.helpers.getBinaryDataBuffer()` instead.
  const bytes = binaryBuffer || Buffer.from(binary.data, 'base64');
  if (bytes.length === 0) return reject(item, 'EMPTY_ATTACHMENT', 'Attachment is zero bytes.');
  if (bytes.length > MAX_BYTES) {
    return reject(item, 'NOT_A_PDF', 'Attachment exceeds the 25 MB intake limit.');
  }
  if (bytes.subarray(0, 5).toString('latin1') !== '%PDF-') {
    return reject(item, 'NOT_A_PDF', 'File does not begin with the PDF signature.');
  }

  const head = bytes.subarray(0, Math.min(bytes.length, 4096)).toString('latin1');
  const tail = bytes.subarray(Math.max(0, bytes.length - 4096)).toString('latin1');
  if (/\/Encrypt\b/.test(head) || /\/Encrypt\b/.test(tail)) {
    return reject(item, 'PDF_ENCRYPTED', 'PDF is password-protected. Ask the sender for an unlocked copy.');
  }

  const hash = createHash('sha256').update(bytes).digest('hex');
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  return {
    ...item,
    json: {
      ...j,
      preflight_ok: true,
      content_sha256: hash,
      byte_size: bytes.length,
      pdf_base64: binary.data,
      stored_path: '/data/certs/' + year + '/' + month + '/' + hash + '.pdf',
    },
  };
}

function reject(item, reason_code, reason_detail) {
  return {
    ...item,
    json: { ...(item.json || {}), preflight_ok: false, reason_code, reason_detail },
  };
}
