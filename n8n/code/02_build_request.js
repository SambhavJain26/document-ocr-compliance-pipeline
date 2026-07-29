/**
 * Build the body for an n8n HTTP Request node using its native OpenAI API
 * credential. The caller supplies either document_text or a file_id, never
 * the API key. input_file needs a file previously uploaded to OpenAI.
 */
export function buildRequest(item) {
  const j = item.json || item;
  const content = j.document_text
    ? [{
        type: 'input_text',
        text: 'Extract the certificate data from the following document text.\\n\\n--- BEGIN DOCUMENT ---\\n' + j.document_text + '\\n--- END DOCUMENT ---',
      }]
    : [{ type: 'input_file', file_id: j.file_id }];

  if (!j.document_text && !j.file_id) {
    throw new Error('buildRequest requires document_text or file_id');
  }

  return {
    method: 'POST',
    url: j.openai_endpoint || 'https://api.openai.com/v1/responses',
    headers: { 'Content-Type': 'application/json' },
    body: {
      model: j.model_id,
      instructions: j.system_prompt,
      input: [{ role: 'user', content }],
      reasoning: { effort: j.is_scanned ? 'medium' : 'low' },
      text: {
        format: {
          type: 'json_schema',
          name: 'coi_extraction',
          strict: true,
          schema: j.schema,
        },
      },
      max_output_tokens: 3000,
      store: false,
    },
  };
}
