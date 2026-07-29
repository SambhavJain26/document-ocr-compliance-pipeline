import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';

const directory = join(process.cwd(), 'n8n', 'workflows');
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
let failed = false;
for (const file of (await readdir(directory)).filter((name) => name.endsWith('.json'))) {
  const text = await readFile(join(directory, file), 'utf8');
  let workflow;
  try {
    workflow = JSON.parse(text);
  } catch (error) {
    console.error(file + ': invalid JSON: ' + error.message);
    failed = true;
    continue;
  }
  if (!uuid.test(workflow.id || '')) {
    console.error(file + ': missing workflow UUID');
    failed = true;
  }
  for (const node of workflow.nodes || []) {
    if (!uuid.test(node.id || '')) {
      console.error(file + ': node without UUID');
      failed = true;
    }
    if (node.type?.endsWith('formTrigger') && !uuid.test(node.webhookId || '')) {
      console.error(file + ': form trigger without webhookId');
      failed = true;
    }
  }
  if (/(?:sk-[A-Za-z0-9_-]{16,}|Bearer[ ]+[A-Za-z0-9._-]+)/i.test(text)) {
    console.error(file + ': credential material detected');
    failed = true;
  }
  if (!failed) console.log('valid: ' + file);
}
process.exitCode = failed ? 1 : 0;
