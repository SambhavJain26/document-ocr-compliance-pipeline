/**
 * Converts a Responses API result into a deterministic workflow outcome.
 * Retryable transport/model errors are distinct from document dead letters.
 */
export function parseResponse(response) {
  const status = Number(response?.statusCode || response?.status || 200);
  if (status === 429 || status >= 500) return { ok: false, error: 'MODEL_RETRYABLE' };
  if (status >= 400) return { ok: false, error: 'MODEL_REQUEST_FAILED' };

  let output = response?.body || response;
  if (typeof output === 'string') {
    try {
      output = JSON.parse(output);
    } catch {
      return { ok: false, error: 'MODEL_INVALID_RESPONSE' };
    }
  }

  if (output?.status === 'incomplete' || output?.incomplete_details) {
    return { ok: false, error: 'MODEL_INCOMPLETE' };
  }

  const content = Array.isArray(output?.output)
    ? output.output.flatMap((item) => item?.content || [])
    : [];
  const refusal = output?.refusal || content.find((part) => part?.type === 'refusal');
  if (refusal) return { ok: false, error: 'MODEL_REFUSED' };

  const text = output?.output_text
    || content.find((part) => part?.type === 'output_text')?.text
    || content.find((part) => part?.type === 'text')?.text;
  if (typeof text !== 'string' || !text.trim()) return { ok: false, error: 'MODEL_EMPTY' };

  try {
    return { ok: true, value: JSON.parse(text) };
  } catch {
    return { ok: false, error: 'JSON_PARSE_FAILED' };
  }
}
