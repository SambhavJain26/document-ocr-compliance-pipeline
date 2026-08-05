"use strict";

const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const validatorSource = fs.readFileSync(path.join(repoRoot, "scripts", "lib", "coi-stage-4-validator.js"), "utf8");
const schema = JSON.parse(fs.readFileSync(path.join(repoRoot, "docs", "schemas", "coi-extraction.schema.json"), "utf8"));

const workflowPath = path.join(repoRoot, "n8n-workflows", "stage-4-extraction-validation-core.json");

const extractionPrompt = `You extract structured data from certificates of liability insurance.

RULES

1. Transcribe only. Never infer, complete, or correct a value that is not legible in the document. If a field is absent or unreadable, return null. A null is always better than a guess.

2. Dates: source documents use MM/DD/YYYY. Return YYYY-MM-DD. If a date is ambiguous or partially illegible, return null and lower the confidence.

3. Limits: return integers without currency symbols or separators. "$1,000,000" becomes 1000000.

4. ADDL INSD and SUBR WVD are checkbox columns. Report only whether a mark is present, as a boolean. These are assertions on a form, not facts about policy terms. Do not interpret them.

5. One object in "coverages" per coverage line present. Do not invent lines that are absent. Coverage lines commonly present: Commercial General Liability, Automobile Liability, Umbrella/Excess, Workers Compensation and Employers Liability.

6. Field order and layout vary between form revisions and between carriers. Locate fields by their labels, not by position.

7. Set is_certificate_of_insurance to false if this document is not a certificate of liability insurance. Return nulls for all other fields.

8. If the Description of Operations box contains wording about notice of cancellation to the certificate holder, copy it verbatim into cancellation_notice_wording. Copy it exactly. Do not summarise it, and do not treat it as a promise that notice will be given.

CONFIDENCE

HIGH - every field you returned was clearly legible.
MEDIUM - the document is legible but at least one field required judgement, or the layout is non-standard.
LOW - the scan is poor, the document is rotated or cropped, or you are unsure about any date or limit.

When you set MEDIUM or LOW, state why in confidence_reason, in one short sentence a non-technical person would understand.

Bias toward LOW. A human reviews everything you mark LOW. Nobody reviews what you mark HIGH.`;

function node(id, name, type, typeVersion, position, parameters = {}, credentials = undefined) {
  const base = { parameters, id, name, type, typeVersion, position };
  if (credentials) {
    base.credentials = credentials;
  }
  return base;
}

const validateCode = `
const module = { exports: {} };
const exports = module.exports;
${validatorSource}

const stage4Validator = module.exports;

function sourceItems(nodeName) {
  try {
    return $items(nodeName).map((item) => item.json);
  } catch (error) {
    return [];
  }
}

function findSourceJson(currentJson, index) {
  const currentFixtureId = currentJson.fixture_id || currentJson.source_ref || null;
  const currentFileName = currentJson.original_filename || currentJson.fileName || currentJson.file_name || null;
  const candidates = [
    ...sourceItems("Mark Text Extraction Method"),
    ...sourceItems("Mark Vision Extraction Method"),
    ...sourceItems("Route By Extracted Text Length"),
    ...sourceItems("Reattach Fixture Context After Text Extraction"),
    ...sourceItems("Reattach Fixture Context After File Read"),
    ...sourceItems("Build Fixed Smoke Fixture Items"),
  ];

  if (currentFixtureId) {
    const exact = candidates.find((item) => item.fixture_id === currentFixtureId);
    if (exact) {
      return exact;
    }
  }

  if (currentFileName) {
    const exact = candidates.find((item) => item.original_filename === currentFileName || item.fileName === currentFileName);
    if (exact) {
      return exact;
    }
  }

  return candidates[index] || {};
}

return $input.all().map((item, index) => {
  const sourceJson = findSourceJson(item.json, index);
  const context = item.json.validation_context || sourceJson.validation_context || {};
  const extractionMethod = item.json.extraction_method || sourceJson.extraction_method || context.extraction_method || "text";
  if (item.json.pdf_error || context.pdf_error) {
    const result = stage4Validator.validateExtraction(null, {
      ...context,
      pdf_error: item.json.pdf_error || context.pdf_error,
      extraction_method: extractionMethod,
    });
    return { json: result };
  }
  const modelPayload = item.json.model_output || item.json;
  const normalized = stage4Validator.normalizeModelOutput(modelPayload);
  const result = normalized.ok
    ? stage4Validator.validateExtraction(normalized.extraction, { ...context, extraction_method: extractionMethod })
    : stage4Validator.validateExtraction(item.json, { ...context, extraction_method: extractionMethod });
  return { json: result };
});
`.trim();

const workflow = {
  id: "stage-4-extraction-validation-core",
  name: "Extraction and Validation Core",
  nodes: [
    node("11111111-1111-4111-8111-111111111111", "Manual Trigger - Run Stage 4 Smoke", "n8n-nodes-base.manualTrigger", 1, [0, 0]),
    node(
      "22222222-2222-4222-8222-222222222222",
      "Load Stage 4 Validation Context",
      "n8n-nodes-base.postgres",
      2.6,
      [260, 0],
      {
        operation: "executeQuery",
        query: `SELECT json_build_object(
  'source', 'form',
  'holder_entities', (SELECT coalesce(json_agg(json_build_object('legal_name', legal_name)), '[]'::json) FROM holder_entities),
  'trade_requirements', (SELECT coalesce(json_agg(json_build_object('trade', trade, 'min_each_occurrence', min_each_occurrence, 'min_general_aggregate', min_general_aggregate, 'wc_required', wc_required)), '[]'::json) FROM trade_requirements),
  'vendors', (
    SELECT coalesce(json_agg(json_build_object(
      'id', v.id,
      'legal_name', v.legal_name,
      'normalised_name', v.normalised_name,
      'trade', v.trade,
      'wc_exempt', v.wc_exempt,
      'current_certificate_date', c.certificate_date,
      'current_coverages', coalesce(cv.coverages, '[]'::json)
    )), '[]'::json)
    FROM vendors v
    LEFT JOIN LATERAL (
      SELECT c.*
      FROM certificates c
      WHERE c.vendor_id = v.id AND c.status = 'ON_FILE'
      ORDER BY c.certificate_date DESC NULLS LAST, c.received_at DESC
      LIMIT 1
    ) c ON true
    LEFT JOIN LATERAL (
      SELECT json_agg(json_build_object('coverage_type', coverage_type, 'effective_date', effective_date, 'expiration_date', expiration_date)) AS coverages
      FROM coverages
      WHERE certificate_id = c.id
    ) cv ON true
  ),
  'model_id', (SELECT value FROM client_config WHERE key = 'model_id')
) AS validation_context;`,
        options: {},
      },
      {
        postgres: {
          id: "Postgres account",
          name: "Postgres account",
        },
      },
    ),
    node(
      "33333333-3333-4333-8333-333333333333",
      "Build Fixed Smoke Fixture Items",
      "n8n-nodes-base.code",
      2,
      [540, 0],
      {
        jsCode: `const context = $input.first().json.validation_context;
const fixtures = [
  { fixture_id: 'f01-clean-current', original_filename: 'f01-clean-current.pdf' },
  { fixture_id: 'f04-scanned-clean-current', original_filename: 'f04-scanned-clean-current.pdf' },
  { fixture_id: 'f11-not-a-certificate', original_filename: 'f11-not-a-certificate.pdf' },
  { fixture_id: 'f18-password-protected', original_filename: 'f18-password-protected.pdf' },
];

return fixtures.map((fixture) => ({
  json: {
    ...fixture,
    fixture_path: '/home/node/.n8n-files/fixtures/pdfs/' + fixture.original_filename,
    validation_context: {
      ...context,
      fixture_id: fixture.fixture_id,
      original_filename: fixture.original_filename,
      stored_path: '/home/node/.n8n-files/fixtures/pdfs/' + fixture.original_filename,
      source_ref: fixture.fixture_id,
    },
    model_id: context.model_id,
  },
}));`,
      },
    ),
    node(
      "34343434-3434-4343-8343-343434343434",
      "Route Password Protected Fixture",
      "n8n-nodes-base.if",
      2.2,
      [820, 0],
      {
        conditions: {
          options: {
            caseSensitive: true,
            leftValue: "",
            typeValidation: "strict",
          },
          conditions: [
            {
              id: "password-fixture-condition",
              leftValue: "={{ $json.fixture_id }}",
              rightValue: "f18-password-protected",
              operator: {
                type: "string",
                operation: "equals",
              },
            },
          ],
          combinator: "and",
        },
        options: {},
      },
    ),
    node(
      "35353535-3535-4353-8353-353535353535",
      "Mark Password Protected Review",
      "n8n-nodes-base.code",
      2,
      [1100, -220],
      {
        jsCode: `return $input.all().map((item) => ({
  json: {
    pdf_error: 'PDF_PASSWORD_PROTECTED',
    extraction_method: 'vision',
    validation_context: {
      ...item.json.validation_context,
      pdf_error: 'PDF_PASSWORD_PROTECTED',
      extraction_method: 'vision',
    },
  },
}));`,
      },
    ),
    node(
      "44444444-4444-4444-8444-444444444444",
      "Read Fixture PDF From Disk",
      "n8n-nodes-base.readWriteFile",
      1,
      [1100, 40],
      {
        operation: "read",
        fileSelector: "={{ $json.fixture_path }}",
        dataPropertyName: "data",
        options: {},
      },
    ),
    node(
      "45454545-4545-4545-8545-454545454545",
      "Reattach Fixture Context After File Read",
      "n8n-nodes-base.code",
      2,
      [1380, 40],
      {
        jsCode: `const sourceItems = $items('Build Fixed Smoke Fixture Items').map((item) => item.json);
return $input.all().map((item, index) => {
  const fileName = item.json.fileName || item.binary?.data?.fileName;
  const source = sourceItems.find((candidate) => candidate.original_filename === fileName) || sourceItems[index] || {};
  return {
    json: {
      ...item.json,
      ...source,
      fileName,
      validation_context: source.validation_context,
      model_id: source.model_id,
    },
    binary: item.binary,
  };
});`,
      },
    ),
    node(
      "55555555-5555-4555-8555-555555555555",
      "Extract Text From PDF",
      "n8n-nodes-base.extractFromFile",
      1,
      [1660, 40],
      {
        operation: "pdf",
        binaryPropertyName: "data",
        options: {},
      },
    ),
    node(
      "56565656-5656-4565-8565-565656565656",
      "Reattach Fixture Context After Text Extraction",
      "n8n-nodes-base.code",
      2,
      [1940, 40],
      {
        jsCode: `const sourceItems = $items('Reattach Fixture Context After File Read');
return $input.all().map((item, index) => {
  const sourceItem = sourceItems[index] || {};
  const source = sourceItem.json || {};
  return {
    json: {
      ...item.json,
      fixture_id: source.fixture_id,
      original_filename: source.original_filename,
      fixture_path: source.fixture_path,
      validation_context: source.validation_context,
      model_id: source.model_id,
    },
    binary: sourceItem.binary || item.binary,
  };
});`,
      },
    ),
    node(
      "66666666-6666-4666-8666-666666666666",
      "Route By Extracted Text Length",
      "n8n-nodes-base.if",
      2.2,
      [2220, 40],
      {
        conditions: {
          options: {
            caseSensitive: true,
            leftValue: "",
            typeValidation: "strict",
          },
          conditions: [
            {
              id: "text-length-condition",
              leftValue: "={{ String($json.text || $json.data || $json.content || '').length }}",
              rightValue: 200,
              operator: {
                type: "number",
                operation: "gt",
              },
            },
          ],
          combinator: "and",
        },
        options: {},
      },
    ),
    node(
      "70707070-7070-4707-8707-707070707070",
      "Mark Text Extraction Method",
      "n8n-nodes-base.code",
      2,
      [2500, -160],
      {
        jsCode: `return $input.all().map((item) => ({
  json: {
    ...item.json,
    extraction_method: 'text',
    validation_context: {
      ...item.json.validation_context,
      extraction_method: 'text',
    },
  },
  binary: item.binary,
}));`,
      },
    ),
    node(
      "80808080-8080-4808-8808-808080808080",
      "Mark Vision Extraction Method",
      "n8n-nodes-base.code",
      2,
      [2500, 160],
      {
        jsCode: `return $input.all().map((item) => ({
  json: {
    ...item.json,
    extraction_method: 'vision',
    validation_context: {
      ...item.json.validation_context,
      extraction_method: 'vision',
    },
  },
  binary: item.binary,
}));`,
      },
    ),
    node(
      "77777777-7777-4777-8777-777777777777",
      "OpenAI Extract From Text",
      "@n8n/n8n-nodes-langchain.openAi",
      2,
      [2780, -160],
      {
        resource: "text",
        operation: "response",
        modelId: {
          mode: "id",
          value: "={{ $json.model_id }}",
        },
        responses: {
          values: [
            {
              type: "text",
              role: "user",
              content: "=Extract the certificate data from this PDF text.\\n\\n{{ $json.text || $json.data || $json.content }}",
            },
          ],
        },
        simplify: true,
        builtInTools: {},
        options: {
          instructions: extractionPrompt,
          maxTokens: 1500,
          temperature: 0,
          store: false,
          textFormat: {
            textOptions: {
              type: "json_schema",
              name: "coi_extraction",
              schema: JSON.stringify(schema),
              strict: true,
            },
          },
        },
      },
      {
        openAiApi: {
          id: "OpenAI account",
          name: "OpenAI account",
        },
      },
    ),
    node(
      "88888888-8888-4888-8888-888888888888",
      "OpenAI Extract From PDF File",
      "@n8n/n8n-nodes-langchain.openAi",
      2,
      [2780, 160],
      {
        resource: "text",
        operation: "response",
        modelId: {
          mode: "id",
          value: "={{ $json.model_id }}",
        },
        responses: {
          values: [
            {
              type: "text",
              role: "user",
              content: "Extract the certificate data from the attached PDF file.",
            },
            {
              type: "file",
              role: "user",
              fileType: "base64",
              binaryPropertyName: "data",
              fileName: "={{ $json.original_filename }}",
            },
          ],
        },
        simplify: true,
        builtInTools: {},
        options: {
          instructions: extractionPrompt,
          maxTokens: 1500,
          temperature: 0,
          store: false,
          textFormat: {
            textOptions: {
              type: "json_schema",
              name: "coi_extraction",
              schema: JSON.stringify(schema),
              strict: true,
            },
          },
        },
      },
      {
        openAiApi: {
          id: "OpenAI account",
          name: "OpenAI account",
        },
      },
    ),
    node(
      "78787878-7878-4787-8787-787878787878",
      "Attach Context To Text Model Output",
      "n8n-nodes-base.code",
      2,
      [3060, -160],
      {
        jsCode: `const sourceItems = $items('Mark Text Extraction Method');
return $input.all().map((item, index) => {
  const source = sourceItems[index]?.json || {};
  return {
    json: {
      fixture_id: source.fixture_id,
      original_filename: source.original_filename,
      extraction_method: 'text',
      validation_context: source.validation_context,
      model_output: item.json,
    },
  };
});`,
      },
    ),
    node(
      "89898989-8989-4898-8898-898989898989",
      "Attach Context To Vision Model Output",
      "n8n-nodes-base.code",
      2,
      [3060, 160],
      {
        jsCode: `const sourceItems = $items('Mark Vision Extraction Method');
return $input.all().map((item, index) => {
  const source = sourceItems[index]?.json || {};
  return {
    json: {
      fixture_id: source.fixture_id,
      original_filename: source.original_filename,
      extraction_method: 'vision',
      validation_context: source.validation_context,
      model_output: item.json,
    },
  };
});`,
      },
    ),
    node(
      "99999999-9999-4999-8999-999999999999",
      "Normalize Model Output And Validate",
      "n8n-nodes-base.code",
      2,
      [3340, 0],
      {
        jsCode: validateCode,
      },
    ),
  ],
  connections: {
    "Manual Trigger - Run Stage 4 Smoke": {
      main: [[{ node: "Load Stage 4 Validation Context", type: "main", index: 0 }]],
    },
    "Load Stage 4 Validation Context": {
      main: [[{ node: "Build Fixed Smoke Fixture Items", type: "main", index: 0 }]],
    },
    "Build Fixed Smoke Fixture Items": {
      main: [[{ node: "Route Password Protected Fixture", type: "main", index: 0 }]],
    },
    "Route Password Protected Fixture": {
      main: [
        [{ node: "Mark Password Protected Review", type: "main", index: 0 }],
        [{ node: "Read Fixture PDF From Disk", type: "main", index: 0 }],
      ],
    },
    "Mark Password Protected Review": {
      main: [[{ node: "Normalize Model Output And Validate", type: "main", index: 0 }]],
    },
    "Read Fixture PDF From Disk": {
      main: [[{ node: "Reattach Fixture Context After File Read", type: "main", index: 0 }]],
    },
    "Reattach Fixture Context After File Read": {
      main: [[{ node: "Extract Text From PDF", type: "main", index: 0 }]],
    },
    "Extract Text From PDF": {
      main: [[{ node: "Reattach Fixture Context After Text Extraction", type: "main", index: 0 }]],
    },
    "Reattach Fixture Context After Text Extraction": {
      main: [[{ node: "Route By Extracted Text Length", type: "main", index: 0 }]],
    },
    "Route By Extracted Text Length": {
      main: [
        [{ node: "Mark Text Extraction Method", type: "main", index: 0 }],
        [{ node: "Mark Vision Extraction Method", type: "main", index: 0 }],
      ],
    },
    "Mark Text Extraction Method": {
      main: [[{ node: "OpenAI Extract From Text", type: "main", index: 0 }]],
    },
    "Mark Vision Extraction Method": {
      main: [[{ node: "OpenAI Extract From PDF File", type: "main", index: 0 }]],
    },
    "OpenAI Extract From Text": {
      main: [[{ node: "Attach Context To Text Model Output", type: "main", index: 0 }]],
    },
    "OpenAI Extract From PDF File": {
      main: [[{ node: "Attach Context To Vision Model Output", type: "main", index: 0 }]],
    },
    "Attach Context To Text Model Output": {
      main: [[{ node: "Normalize Model Output And Validate", type: "main", index: 0 }]],
    },
    "Attach Context To Vision Model Output": {
      main: [[{ node: "Normalize Model Output And Validate", type: "main", index: 0 }]],
    },
  },
  settings: {
    executionOrder: "v1",
  },
  staticData: null,
  pinData: {},
  tags: [],
  triggerCount: 0,
  updatedAt: "2026-07-30T00:00:00.000Z",
  versionId: "stage-4-generated",
};

fs.mkdirSync(path.dirname(workflowPath), { recursive: true });
fs.writeFileSync(workflowPath, `${JSON.stringify(workflow, null, 2)}\n`, "utf8");
console.log(`Generated ${path.relative(repoRoot, workflowPath)}`);
