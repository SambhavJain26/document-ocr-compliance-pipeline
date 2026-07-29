/** Convert Form Trigger file fields into the same intake shape as Gmail items. */
export function normaliseForm(item) {
  const j = item.json || {};
  const binary = item.binary || {};
  return Object.entries(binary).map(([key, attachment]) => ({
    json: {
      source: 'form',
      source_ref: j.submittedAt || j.submissionId || null,
      original_filename: attachment.fileName || 'certificate.pdf',
      binary_key: key,
    },
    binary: { data: attachment },
  }));
}
