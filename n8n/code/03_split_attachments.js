/**
 * Fan an unsimplified Gmail message into one item per PDF attachment.
 * Portal URLs are deliberately detected but never fetched.
 */
export function splitAttachments(items) {
  const out = [];
  for (const item of items) {
    const j = item.json || {};
    const binary = item.binary || {};
    const headers = j.payload?.headers || [];
    const header = (name) => headers.find((value) => value.name?.toLowerCase() === name)?.value || '';
    const meta = {
      source: 'email',
      source_ref: j.id || j.messageId || null,
      from_address: header('from') || j.from || null,
      subject: header('subject') || j.subject || '',
      body_text: j.snippet || j.text || '',
    };
    const pdfKeys = Object.keys(binary).filter((key) => {
      const attachment = binary[key];
      return attachment?.mimeType === 'application/pdf'
        || (attachment?.fileName || '').toLowerCase().endsWith('.pdf');
    });

    if (pdfKeys.length === 0) {
      const body = (meta.subject + ' ' + meta.body_text).toLowerCase();
      const portal = /(download|retrieve|access|view)\b[^.]{0,60}\b(certificate|coi|document)/.test(body)
        || /https?:\/\/[^\s]*(portal|secure|share|download|docs)/.test(body);
      out.push({
        json: {
          ...meta,
          preflight_ok: false,
          reason_code: portal ? 'NO_ATTACHMENT_PORTAL_LINK' : 'NO_ATTACHMENT_TEXT_REPLY',
          reason_detail: portal
            ? 'Email contains a download link and no attachment. Not fetched; needs a person.'
            : 'Email has no attachment. Likely a reply from the vendor or agent.',
        },
      });
      continue;
    }

    for (const key of pdfKeys) {
      out.push({
        json: { ...meta, original_filename: binary[key].fileName || 'certificate.pdf', binary_key: key },
        binary: { data: binary[key] },
      });
    }
  }
  return out;
}
