"use strict";

const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const validatorSource = fs.readFileSync(path.join(repoRoot, "scripts", "lib", "coi-stage-4-validator.js"), "utf8");
const schema = JSON.parse(fs.readFileSync(path.join(repoRoot, "docs", "schemas", "coi-extraction.schema.json"), "utf8"));

const intakePath = path.join(repoRoot, "n8n-workflows", "stage-5-intake-workflow.json");
const sourcePath = path.join(repoRoot, "n8n-workflows", "stage-5-source-document-route.json");

const extractionPrompt = `You extract structured data from certificates of liability insurance.

RULES

1. Transcribe only. Never infer, complete, or correct a value that is not legible in the document. If a field is absent or unreadable, return null. A null is always better than a guess.

2. Dates: source documents use MM/DD/YYYY. Return YYYY-MM-DD. If a date is ambiguous or partially illegible, return null and lower the confidence.

3. Limits: return integers without currency symbols or separators. "$1,000,000" becomes 1000000.

4. ADDL INSD and SUBR WVD are checkbox columns. Report only whether a mark is present, as a boolean. These are assertions on a form, not facts about policy terms. Do not interpret them.

5. One object in "coverages" per coverage line present. Do not invent lines that are absent. Coverage lines commonly present: Commercial General Liability, Automobile Liability, Umbrella/Excess, Workers Compensation and Employers Liability.

6. Field order and layout vary between form revisions and between carriers. Locate fields by their labels, not by position.

7. Set is_certificate_of_insurance to false only when this is a different kind of document, for example a W-9, an invoice, a licence, a quote, or a letter. Judge the document by its structure and its fields, not by its styling or provenance. A watermark or label such as SPECIMEN, SAMPLE, DRAFT, COPY or TEST DOCUMENT describes the copy in front of you, not the kind of document it is; a watermarked certificate of liability insurance is still a certificate of liability insurance. If it carries insurer, policy number, coverage line, effective and expiration fields laid out as a certificate of liability insurance, it is one. When you do set it to false, return nulls for all other fields.

8. If the Description of Operations box contains wording about notice of cancellation to the certificate holder, copy it verbatim into cancellation_notice_wording. Copy it exactly. Do not summarise it, and do not treat it as a promise that notice will be given.

CONFIDENCE

HIGH - every field you returned was clearly legible.
MEDIUM - the document is legible but at least one field required judgement, or the layout is non-standard.
LOW - the scan is poor, the document is rotated or cropped, or you are unsure about any date or limit.

When you set MEDIUM or LOW, state why in confidence_reason, in one short sentence a non-technical person would understand.

Bias toward LOW. A human reviews everything you mark LOW. Nobody reviews what you mark HIGH.`;

function sticky(id, position, width, height, content, color = 5) {
  return {
    parameters: { content, height, width, color },
    id,
    name: `Note - ${id.slice(-4)}`,
    type: "n8n-nodes-base.stickyNote",
    typeVersion: 1,
    position,
  };
}

function node(id, name, type, typeVersion, position, parameters = {}, credentials = undefined) {
  const { __disabled, ...cleanParameters } = parameters;
  const base = { parameters: cleanParameters, id, name, type, typeVersion, position };
  if (credentials) {
    base.credentials = credentials;
  }
  if (__disabled) {
    base.disabled = true;
  }
  return base;
}

function postgresCreds() {
  return {
    postgres: {
      id: "Postgres account",
      name: "Postgres account",
    },
  };
}

function openAiCreds() {
  return {
    openAiApi: {
      id: "OpenAI account",
      name: "OpenAI account",
    },
  };
}

function loadContextQuery(sourceExpression) {
  return `SELECT json_build_object(
  'source', ${sourceExpression},
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
      ORDER BY c.certificate_date DESC NULLS LAST, c.received_at DESC, c.id DESC
      LIMIT 1
    ) c ON true
    LEFT JOIN LATERAL (
      SELECT json_agg(json_build_object('coverage_type', coverage_type, 'effective_date', effective_date, 'expiration_date', expiration_date)) AS coverages
      FROM coverages
      WHERE certificate_id = c.id
    ) cv ON true
  ),
  'model_id', (SELECT value FROM client_config WHERE key = 'model_id'),
  'smoke_fixture_set', (SELECT value FROM client_config WHERE key = 'stage_5_smoke_fixture_set'),
  'send_manager_notices', (SELECT value FROM client_config WHERE key = 'send_manager_notices'),
  'manager_notice_email', (SELECT value FROM client_config WHERE key = 'manager_notice_email')
) AS validation_context;`;
}

const normalizeIntakeCode = `
function safeName(value) {
  return String(value || "attachment.pdf").replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "") || "attachment.pdf";
}

function isPdf(binary) {
  const fileName = String(binary?.fileName || "");
  const mimeType = String(binary?.mimeType || "");
  return mimeType === "application/pdf" || fileName.toLowerCase().endsWith(".pdf");
}

function bodyText(json) {
  return [json.text, json.html, json.body, json.snippet].filter(Boolean).join("\\n");
}

return $input.all().flatMap((item, itemIndex) => {
  const source = item.json.__stage5_source || "form";
  const binaryEntries = Object.entries(item.binary || {});
  const pdfEntries = binaryEntries.filter(([, binary]) => isPdf(binary));
  const nonPdfEntries = binaryEntries.filter(([, binary]) => !isPdf(binary));
  const baseRef = item.json.id || item.json.messageId || item.json.threadId || item.json.submittedAt || String(Date.now());
  const output = [];

  for (const [binaryKey, binary] of pdfEntries) {
    const fileName = safeName(binary.fileName || item.json.original_filename || "attachment.pdf");
    output.push({
      json: {
        item_kind: "pdf",
        source,
        source_ref: source + ":" + baseRef + ":" + binaryKey + ":" + fileName,
        original_filename: fileName,
        validation_context: {
          source,
          source_ref: source + ":" + baseRef + ":" + binaryKey + ":" + fileName,
          original_filename: fileName,
        },
      },
      binary: { data: binary },
    });
  }

  for (const [binaryKey, binary] of nonPdfEntries) {
    const fileName = safeName(binary.fileName || binaryKey);
    output.push({
      json: {
        item_kind: "notice",
        disposition: "NON_PDF_ATTACHMENT",
        source,
        source_ref: source + ":" + baseRef + ":" + binaryKey + ":" + fileName,
        original_filename: fileName,
        notice_code: "NON_PDF_ATTACHMENT",
        notice_message: "The intake item included a non-PDF attachment and was not processed.",
      },
    });
  }

  if (pdfEntries.length === 0 && nonPdfEntries.length === 0) {
    const text = bodyText(item.json);
    const hasPortalLink = /https?:\\/\\//i.test(text);
    output.push({
      json: {
        item_kind: "notice",
        disposition: hasPortalLink ? "PORTAL_LINK_NO_ATTACHMENT" : "NO_PDF_ATTACHMENT",
        source,
        source_ref: source + ":" + baseRef + ":no-pdf:" + itemIndex,
        original_filename: null,
        notice_code: hasPortalLink ? "PORTAL_LINK_NO_ATTACHMENT" : "NO_PDF_ATTACHMENT",
        notice_message: hasPortalLink
          ? "The intake item contained a portal link but no PDF attachment."
          : "The intake item did not include a PDF attachment.",
        details: { snippet: text.slice(0, 500) },
      },
    });
  }

  return output;
});
`.trim();

const attachContextCode = (sourceNodeName) => `
const sourceItems = $items("${sourceNodeName}");
const context = $input.first().json.validation_context;
return sourceItems.map((item) => ({
  json: {
    ...item.json,
    validation_context: {
      ...context,
      ...item.json.validation_context,
      source: item.json.source || context.source,
      source_ref: item.json.source_ref,
      original_filename: item.json.original_filename,
    },
    model_id: context.model_id,
  },
  binary: item.binary,
}));
`.trim();

const buildManualItemsCode = `
const context = $input.first().json.validation_context;
const requested = String(context.smoke_fixture_set || "f01-clean-current")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);

const pdfFixtures = new Set([
  "f01-clean-current",
  "f02-expiring-20-days",
  "f03-expired-34-days",
  "f04-scanned-clean-current",
  "f05-inverted-dates",
  "f06-wrong-holder",
  "f07-low-limits",
  "f08-multiple-expiry-dates",
  "f09-missing-gl",
  "f11-not-a-certificate",
  "f12-renewal-supersede",
  "f13-renewal-coverage-gap",
  "f15-wc-exempt",
  "f16-owner-llc-holder",
  "f17-near-duplicate-vendor",
  "f18-password-protected",
  "f20-cancellation-notice-wording",
]);

function pdfItem(fixtureId, sourceRef = fixtureId) {
  const original = fixtureId + ".pdf";
  return {
    json: {
      item_kind: "pdf",
      fixture_id: fixtureId,
      source: "form",
      source_ref: sourceRef,
      original_filename: original,
      fixture_path: "/home/node/.n8n-files/fixtures/pdfs/" + original,
      validation_context: {
        ...context,
        fixture_id: fixtureId,
        source: "form",
        source_ref: sourceRef,
        original_filename: original,
      },
      model_id: context.model_id,
    },
  };
}

function noticeItem(fixtureId, sourceRef, code, message, details = {}) {
  return {
    json: {
      item_kind: "notice",
      fixture_id: fixtureId,
      source: "email",
      source_ref: sourceRef,
      original_filename: null,
      disposition: code,
      notice_code: code,
      notice_message: message,
      details,
      validation_context: {
        ...context,
        fixture_id: fixtureId,
        source: "email",
        source_ref: sourceRef,
        original_filename: null,
      },
      model_id: context.model_id,
    },
  };
}

const items = [];
for (const fixtureId of requested) {
  if (fixtureId === "f10-two-certificates-email") {
    items.push(pdfItem("f01-clean-current", "f10-two-certificates-email:f01-clean-current.pdf"));
    items.push(pdfItem("f02-expiring-20-days", "f10-two-certificates-email:f02-expiring-20-days.pdf"));
  } else if (fixtureId === "f19-portal-link-email") {
    items.push(noticeItem(
      "f19-portal-link-email",
      "f19-portal-link-email:no-pdf",
      "PORTAL_LINK_NO_ATTACHMENT",
      "The intake item contained a portal link but no PDF attachment.",
      { portal_url: "https://portal.example.test/certificates/cedar-path" }
    ));
  } else if (pdfFixtures.has(fixtureId)) {
    items.push(pdfItem(fixtureId));
  } else {
    items.push(noticeItem(fixtureId, fixtureId + ":unknown", "UNKNOWN_FIXTURE", "The requested Stage 5 smoke fixture is not known.", {}));
  }
}

return items;
`.trim();

const prepareStorageCode = `
function safePart(value, fallback) {
  return String(value || fallback)
    .replace(/[^a-zA-Z0-9._:-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120) || fallback;
}

const now = new Date();
const yyyy = String(now.getUTCFullYear());
const mm = String(now.getUTCMonth() + 1).padStart(2, "0");
const dd = String(now.getUTCDate()).padStart(2, "0");

return $input.all().map((item) => {
  const sourceRef = item.json.source_ref || item.json.fixture_id || String(Date.now());
  const original = item.json.original_filename || item.binary?.data?.fileName || "attachment.pdf";
  const storedPath = "/home/node/.n8n-files/certificates/" + yyyy + "/" + mm + "/" + dd + "/" +
    safePart(sourceRef, "source") + "-" + safePart(original, "attachment.pdf");
  return {
    json: {
      ...item.json,
      stored_path: storedPath,
      validation_context: {
        ...item.json.validation_context,
        stored_path: storedPath,
        source_ref: sourceRef,
        original_filename: original,
      },
    },
    binary: item.binary,
  };
});
`.trim();

const reattachAfterFileReadCode = `
const sourceItems = $items("Build Manual Smoke Items").map((item) => item.json);
return $input.all().map((item, index) => {
  const fileName = item.json.fileName || item.binary?.data?.fileName;
  const source = sourceItems.find((candidate) => candidate.original_filename === fileName) || sourceItems[index] || {};
  return {
    json: {
      ...item.json,
      ...source,
      validation_context: source.validation_context,
      model_id: source.model_id,
    },
    binary: item.binary,
  };
});
`.trim();

const reattachAfterWriteCode = `
function sourceItems(nodeName) {
  try { return $items(nodeName); } catch (error) { return []; }
}

// Detect encryption from the document itself rather than from a fixture name.
// An encrypted PDF carries an /Encrypt entry in its trailer dictionary. The
// routing node downstream used to compare $json.fixture_id against a fixture
// ID, which meant two things: a real locked PDF arriving from a vendor was
// never detected, and form or Gmail intake had no fixture_id at all, so the
// comparison hit undefined and the run failed outright at that node.
function detectPasswordProtected(item) {
  try {
    const encoded = item.binary && item.binary.data && item.binary.data.data;
    if (typeof encoded === "string" && encoded.length > 0) {
      const buffer = Buffer.from(encoded, "base64");
      return /\\/Encrypt[\\s\\/<\\[]/.test(buffer.toString("latin1"));
    }
  } catch (error) {}
  // Binary was not inline, so fall back to the known fixture rather than
  // guessing. Returning false here would file a locked document as readable.
  return String((item.json && item.json.fixture_id) || "") === "f18-password-protected";
}

const candidates = [
  ...sourceItems("Prepare Stored PDF Metadata"),
  ...sourceItems("Reattach Manual Fixture After File Read"),
];
return $input.all().map((item, index) => {
  const source = candidates.find((candidate) => candidate.json.stored_path === item.json.fileName) || candidates[index] || item;
  const binary = source.binary || item.binary;
  return {
    json: {
      ...source.json,
      fileName: item.json.fileName,
      stored_path: source.json.stored_path || item.json.fileName,
      is_password_protected: detectPasswordProtected({ json: source.json, binary }),
      validation_context: {
        ...source.json.validation_context,
        stored_path: source.json.stored_path || item.json.fileName,
      },
    },
    binary,
  };
});
`.trim();

const reattachAfterTextExtractionCode = `
const sourceItems = $items("Reattach PDF Context After Storage");
return $input.all().map((item, index) => {
  const sourceItem = sourceItems[index] || {};
  const source = sourceItem.json || {};
  return {
    json: {
      ...item.json,
      fixture_id: source.fixture_id,
      source: source.source,
      source_ref: source.source_ref,
      original_filename: source.original_filename,
      stored_path: source.stored_path,
      validation_context: source.validation_context,
      model_id: source.model_id,
    },
    binary: sourceItem.binary || item.binary,
  };
});
`.trim();

const markMethodCode = (method) => `
return $input.all().map((item) => ({
  json: {
    ...item.json,
    extraction_method: "${method}",
    validation_context: {
      ...item.json.validation_context,
      extraction_method: "${method}",
    },
  },
  binary: item.binary,
}));
`.trim();

const attachModelOutputCode = (sourceNodeName, method) => `
const sourceItems = $items("${sourceNodeName}");
return $input.all().map((item, index) => {
  const source = sourceItems[index]?.json || {};
  return {
    json: {
      fixture_id: source.fixture_id,
      source: source.source,
      source_ref: source.source_ref,
      original_filename: source.original_filename,
      stored_path: source.stored_path,
      extraction_method: "${method}",
      validation_context: source.validation_context,
      model_output: item.json,
    },
  };
});
`.trim();

const directNoticePayloadCode = `
return $input.all().map((item) => ({
  json: {
    fixture_id: item.json.fixture_id || null,
    disposition: item.json.disposition || item.json.notice_code || "INTAKE_NOTICE",
    status: null,
    validation_flags: [{
      code: item.json.notice_code || item.json.disposition || "INTAKE_NOTICE",
      severity: item.json.severity || "note",
      message: item.json.notice_message || "The intake item did not produce a storage-ready certificate.",
      details: item.json.details || {},
    }],
    certificate: {
      source: item.json.source || "form",
      source_ref: item.json.source_ref,
      original_filename: item.json.original_filename || null,
      stored_path: item.json.stored_path || null,
    },
    coverages: [],
    raw_extraction: null,
  },
}));
`.trim();

const validateCode = `
const module = { exports: {} };
const exports = module.exports;
${validatorSource}

const stage4Validator = module.exports;

return $input.all().map((item) => {
  const context = item.json.validation_context || {};
  const extractionMethod = item.json.extraction_method || context.extraction_method || "text";
  if (item.json.pdf_error || context.pdf_error) {
    const result = stage4Validator.validateExtraction(null, {
      ...context,
      pdf_error: item.json.pdf_error || context.pdf_error,
      extraction_method: extractionMethod,
    });
    return { json: result };
  }
  const normalized = stage4Validator.normalizeModelOutput(item.json.model_output || item.json);
  const result = normalized.ok
    ? stage4Validator.validateExtraction(normalized.extraction, { ...context, extraction_method: extractionMethod })
    : stage4Validator.validateExtraction(item.json, { ...context, extraction_method: extractionMethod });
  return { json: result };
});
`.trim();

const passwordReviewCode = `
return $input.all().map((item) => ({
  json: {
    ...item.json,
    pdf_error: "PDF_PASSWORD_PROTECTED",
    extraction_method: "vision",
    validation_context: {
      ...item.json.validation_context,
      pdf_error: "PDF_PASSWORD_PROTECTED",
      extraction_method: "vision",
    },
  },
}));
`.trim();

function openAiNode(id, name, position, branch) {
  const isVision = branch === "vision";
  return node(
    id,
    name,
    "@n8n/n8n-nodes-langchain.openAi",
    2,
    position,
    {
      resource: "text",
      operation: "response",
      modelId: {
        mode: "id",
        value: "={{ $json.model_id }}",
      },
      responses: {
        values: isVision
          ? [
              { type: "text", role: "user", content: "Extract the certificate data from the attached PDF file." },
              { type: "file", role: "user", fileType: "base64", binaryPropertyName: "data", fileName: "={{ $json.original_filename }}" },
            ]
          : [
              { type: "text", role: "user", content: "=Extract the certificate data from this PDF text.\\n\\n{{ $json.text || $json.data || $json.content }}" },
            ],
      },
      simplify: true,
      builtInTools: {},
      options: {
        instructions: extractionPrompt,
        maxTokens: 1500,
        // No temperature. The model ID is a runtime setting in client_config,
        // and some models reject this parameter outright with a bad request,
        // which fails the whole run. Determinism here comes from the JSON
        // schema and the transcribe-only prompt, not from a sampling knob.
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
    openAiCreds(),
  );
}

// Sticky notes removed by request. The sticky() helper stays defined above
// for any generator that reintroduces canvas notes later; keep using it
// rather than hand-adding notes to the generated JSON.
const intakeStickies = [];

const intakeWorkflow = {
  id: "stage-5-intake-workflow",
  name: "COI Intake",
  nodes: [
    ...intakeStickies,
    node("11000000-0000-4500-8500-000000000001", "Manual Trigger - Run Stage 5 Smoke", "n8n-nodes-base.manualTrigger", 1, [0, -220]),
    node("11000000-0000-4500-8500-000000000002", "Form Trigger - Certificate Upload", "n8n-nodes-base.formTrigger", 2.6, [0, 120], {
      authentication: "none",
      formTitle: "COI Intake",
      formDescription: "Upload one certificate PDF for local Stage 5 testing.",
      formFields: {
        values: [
          {
            fieldLabel: "Certificate PDF",
            fieldName: "certificate_pdf",
            fieldType: "file",
            requiredField: true,
            acceptFileTypes: ".pdf,application/pdf",
          },
        ],
      },
      responseMode: "lastNode",
      options: {
        path: "coi-intake",
        buttonLabel: "Submit",
        appendAttribution: false,
      },
    }),
    node("11000000-0000-4500-8500-000000000003", "Gmail Trigger - COI Intake", "n8n-nodes-base.gmailTrigger", 1.4, [0, 420], {
      authentication: "oAuth2",
      event: "messageReceived",
      simple: false,
      maxResults: 10,
      filters: {
        q: "has:attachment",
        readStatus: "unread",
      },
      options: {
        downloadAttachments: true,
        dataPropertyAttachmentsPrefixName: "attachment_",
      },
    }, { gmailOAuth2: { id: "Gmail account", name: "Gmail account" } }),
    node("11000000-0000-4500-8500-000000000004", "IMAP Trigger - Disabled Fallback", "n8n-nodes-base.emailReadImap", 2, [0, 700], {
      __disabled: true,
      options: {
        downloadAttachments: true,
      },
    }),

    node("22000000-0000-4500-8500-000000000001", "Load Stage 5 Manual Context", "n8n-nodes-base.postgres", 2.6, [280, -220], {
      operation: "executeQuery",
      query: loadContextQuery("'form'"),
      options: {},
    }, postgresCreds()),
    node("22000000-0000-4500-8500-000000000002", "Build Manual Smoke Items", "n8n-nodes-base.code", 2, [560, -220], { jsCode: buildManualItemsCode }),

    node("22000000-0000-4500-8500-000000000003", "Mark Form Intake Source", "n8n-nodes-base.code", 2, [280, 120], {
      jsCode: "return $input.all().map((item) => ({ json: { ...item.json, __stage5_source: 'form' }, binary: item.binary }));",
    }),
    node("22000000-0000-4500-8500-000000000004", "Normalize Form Intake Items", "n8n-nodes-base.code", 2, [560, 120], { jsCode: normalizeIntakeCode }),
    node("22000000-0000-4500-8500-000000000005", "Load Stage 5 Form Context", "n8n-nodes-base.postgres", 2.6, [840, 120], {
      operation: "executeQuery",
      query: loadContextQuery("'form'"),
      options: {},
    }, postgresCreds()),
    node("22000000-0000-4500-8500-000000000006", "Attach Context To Form Items", "n8n-nodes-base.code", 2, [1120, 120], { jsCode: attachContextCode("Normalize Form Intake Items") }),

    node("22000000-0000-4500-8500-000000000007", "Mark Gmail Intake Source", "n8n-nodes-base.code", 2, [280, 420], {
      jsCode: "return $input.all().map((item) => ({ json: { ...item.json, __stage5_source: 'email' }, binary: item.binary }));",
    }),
    node("22000000-0000-4500-8500-000000000008", "Normalize Gmail Intake Items", "n8n-nodes-base.code", 2, [560, 420], { jsCode: normalizeIntakeCode }),
    node("22000000-0000-4500-8500-000000000009", "Load Stage 5 Gmail Context", "n8n-nodes-base.postgres", 2.6, [840, 420], {
      operation: "executeQuery",
      query: loadContextQuery("'email'"),
      options: {},
    }, postgresCreds()),
    node("22000000-0000-4500-8500-000000000010", "Attach Context To Gmail Items", "n8n-nodes-base.code", 2, [1120, 420], { jsCode: attachContextCode("Normalize Gmail Intake Items") }),

    node("33000000-0000-4500-8500-000000000001", "Route Intake Item Type", "n8n-nodes-base.if", 2.2, [1400, 0], {
      conditions: {
        options: { caseSensitive: true, leftValue: "", typeValidation: "strict" },
        conditions: [
          {
            id: "notice-item-condition",
            leftValue: "={{ $json.item_kind }}",
            rightValue: "notice",
            operator: { type: "string", operation: "equals" },
          },
        ],
        combinator: "and",
      },
      options: {},
    }),
    node("33000000-0000-4500-8500-000000000002", "Build Direct Intake Notice Payload", "n8n-nodes-base.code", 2, [1680, -220], { jsCode: directNoticePayloadCode }),
    node("33000000-0000-4500-8500-000000000003", "Route Manual Fixture File Read", "n8n-nodes-base.if", 2.2, [1680, 80], {
      conditions: {
        options: { caseSensitive: true, leftValue: "", typeValidation: "strict" },
        conditions: [
          {
            id: "fixture-path-exists",
            leftValue: "={{ Boolean($json.fixture_path) }}",
            rightValue: true,
            operator: { type: "boolean", operation: "true", singleValue: true },
          },
        ],
        combinator: "and",
      },
      options: {},
    }),
    node("33000000-0000-4500-8500-000000000004", "Read Manual Fixture PDF From Disk", "n8n-nodes-base.readWriteFile", 1.1, [1960, -20], {
      operation: "read",
      fileSelector: "={{ $json.fixture_path }}",
      options: { dataPropertyName: "data" },
    }),
    node("33000000-0000-4500-8500-000000000005", "Reattach Manual Fixture After File Read", "n8n-nodes-base.code", 2, [2240, -20], { jsCode: reattachAfterFileReadCode }),
    node("33000000-0000-4500-8500-000000000006", "Prepare Stored PDF Metadata", "n8n-nodes-base.code", 2, [2520, 80], { jsCode: prepareStorageCode }),
    node("33000000-0000-4500-8500-000000000007", "Write Original PDF To Storage", "n8n-nodes-base.readWriteFile", 1.1, [2800, 80], {
      operation: "write",
      fileName: "={{ $json.stored_path }}",
      dataPropertyName: "data",
      options: {},
    }),
    node("33000000-0000-4500-8500-000000000008", "Reattach PDF Context After Storage", "n8n-nodes-base.code", 2, [3080, 80], { jsCode: reattachAfterWriteCode }),
    node("33000000-0000-4500-8500-000000000009", "Route Password Protected PDF", "n8n-nodes-base.if", 2.2, [3360, 80], {
      // Boolean set upstream from the document's own bytes, with loose type
      // validation. Strict validation against an undefined fixture_id was
      // failing the whole run on the form and Gmail paths, which are the two
      // paths a real certificate actually arrives on.
      conditions: {
        options: { caseSensitive: true, leftValue: "", typeValidation: "loose" },
        conditions: [
          {
            id: "password-protected-condition",
            leftValue: "={{ $json.is_password_protected }}",
            rightValue: "={{ true }}",
            operator: { type: "boolean", operation: "true", singleValue: true },
          },
        ],
        combinator: "and",
      },
      options: {},
    }),
    node("33000000-0000-4500-8500-000000000010", "Mark Password Protected Review Result", "n8n-nodes-base.code", 2, [3640, -160], { jsCode: passwordReviewCode }),
    // Extraction aborts on an encrypted or corrupt PDF. Sending that to a
    // second output rather than failing the run is what makes a locked file
    // land in review instead of killing the execution. The upstream boolean
    // check is a fast path only; it cannot see the bytes when n8n stores
    // binary on the filesystem rather than inline, so this is the real guard.
    {
      ...node("33000000-0000-4500-8500-000000000011", "Extract Text From Stored PDF", "n8n-nodes-base.extractFromFile", 1, [3640, 180], {
        operation: "pdf",
        binaryPropertyName: "data",
        options: {},
      }),
      onError: "continueErrorOutput",
    },
    node("33000000-0000-4500-8500-000000000012", "Reattach Context After Text Extraction", "n8n-nodes-base.code", 2, [3920, 180], { jsCode: reattachAfterTextExtractionCode }),
    node("33000000-0000-4500-8500-000000000013", "Route By Extracted Text Length", "n8n-nodes-base.if", 2.2, [4200, 180], {
      conditions: {
        options: { caseSensitive: true, leftValue: "", typeValidation: "strict" },
        conditions: [
          {
            id: "text-length-condition",
            leftValue: "={{ String($json.text || $json.data || $json.content || '').length }}",
            rightValue: 200,
            operator: { type: "number", operation: "gt" },
          },
        ],
        combinator: "and",
      },
      options: {},
    }),
    node("44000000-0000-4500-8500-000000000001", "Mark Text Extraction Method", "n8n-nodes-base.code", 2, [4480, 40], { jsCode: markMethodCode("text") }),
    node("44000000-0000-4500-8500-000000000002", "Mark Vision Extraction Method", "n8n-nodes-base.code", 2, [4480, 320], { jsCode: markMethodCode("vision") }),
    openAiNode("44000000-0000-4500-8500-000000000003", "OpenAI Extract Stage 5 Text", [4760, 40], "text"),
    openAiNode("44000000-0000-4500-8500-000000000004", "OpenAI Extract Stage 5 PDF File", [4760, 320], "vision"),
    node("44000000-0000-4500-8500-000000000005", "Attach Context To Text Output", "n8n-nodes-base.code", 2, [5040, 40], { jsCode: attachModelOutputCode("Mark Text Extraction Method", "text") }),
    node("44000000-0000-4500-8500-000000000006", "Attach Context To Vision Output", "n8n-nodes-base.code", 2, [5040, 320], { jsCode: attachModelOutputCode("Mark Vision Extraction Method", "vision") }),
    node("55000000-0000-4500-8500-000000000001", "Normalize Validate Stage 5 Result", "n8n-nodes-base.code", 2, [5320, 120], { jsCode: validateCode }),
    node("55000000-0000-4500-8500-000000000002", "Store Stage 5 Intake Result", "n8n-nodes-base.postgres", 2.6, [5600, 120], {
      operation: "executeQuery",
      query: "SELECT store_stage_5_intake_result($1::jsonb) AS storage_result;",
      options: {
        queryReplacement: "={{ JSON.stringify($json) }}",
      },
    }, postgresCreds()),
  ],
  connections: {
    "Manual Trigger - Run Stage 5 Smoke": { main: [[{ node: "Load Stage 5 Manual Context", type: "main", index: 0 }]] },
    "Load Stage 5 Manual Context": { main: [[{ node: "Build Manual Smoke Items", type: "main", index: 0 }]] },
    "Build Manual Smoke Items": { main: [[{ node: "Route Intake Item Type", type: "main", index: 0 }]] },
    "Form Trigger - Certificate Upload": { main: [[{ node: "Mark Form Intake Source", type: "main", index: 0 }]] },
    "Mark Form Intake Source": { main: [[{ node: "Normalize Form Intake Items", type: "main", index: 0 }]] },
    "Normalize Form Intake Items": { main: [[{ node: "Load Stage 5 Form Context", type: "main", index: 0 }]] },
    "Load Stage 5 Form Context": { main: [[{ node: "Attach Context To Form Items", type: "main", index: 0 }]] },
    "Attach Context To Form Items": { main: [[{ node: "Route Intake Item Type", type: "main", index: 0 }]] },
    "Gmail Trigger - COI Intake": { main: [[{ node: "Mark Gmail Intake Source", type: "main", index: 0 }]] },
    "Mark Gmail Intake Source": { main: [[{ node: "Normalize Gmail Intake Items", type: "main", index: 0 }]] },
    "Normalize Gmail Intake Items": { main: [[{ node: "Load Stage 5 Gmail Context", type: "main", index: 0 }]] },
    "Load Stage 5 Gmail Context": { main: [[{ node: "Attach Context To Gmail Items", type: "main", index: 0 }]] },
    "Attach Context To Gmail Items": { main: [[{ node: "Route Intake Item Type", type: "main", index: 0 }]] },
    "Route Intake Item Type": {
      main: [
        [{ node: "Build Direct Intake Notice Payload", type: "main", index: 0 }],
        [{ node: "Route Manual Fixture File Read", type: "main", index: 0 }],
      ],
    },
    "Build Direct Intake Notice Payload": { main: [[{ node: "Store Stage 5 Intake Result", type: "main", index: 0 }]] },
    "Route Manual Fixture File Read": {
      main: [
        [{ node: "Read Manual Fixture PDF From Disk", type: "main", index: 0 }],
        [{ node: "Prepare Stored PDF Metadata", type: "main", index: 0 }],
      ],
    },
    "Read Manual Fixture PDF From Disk": { main: [[{ node: "Reattach Manual Fixture After File Read", type: "main", index: 0 }]] },
    "Reattach Manual Fixture After File Read": { main: [[{ node: "Prepare Stored PDF Metadata", type: "main", index: 0 }]] },
    "Prepare Stored PDF Metadata": { main: [[{ node: "Write Original PDF To Storage", type: "main", index: 0 }]] },
    "Write Original PDF To Storage": { main: [[{ node: "Reattach PDF Context After Storage", type: "main", index: 0 }]] },
    "Reattach PDF Context After Storage": { main: [[{ node: "Route Password Protected PDF", type: "main", index: 0 }]] },
    "Route Password Protected PDF": {
      main: [
        [{ node: "Mark Password Protected Review Result", type: "main", index: 0 }],
        [{ node: "Extract Text From Stored PDF", type: "main", index: 0 }],
      ],
    },
    "Mark Password Protected Review Result": { main: [[{ node: "Normalize Validate Stage 5 Result", type: "main", index: 0 }]] },
    "Extract Text From Stored PDF": {
      main: [
        [{ node: "Reattach Context After Text Extraction", type: "main", index: 0 }],
        [{ node: "Mark Password Protected Review Result", type: "main", index: 0 }],
      ],
    },
    "Reattach Context After Text Extraction": { main: [[{ node: "Route By Extracted Text Length", type: "main", index: 0 }]] },
    "Route By Extracted Text Length": {
      main: [
        [{ node: "Mark Text Extraction Method", type: "main", index: 0 }],
        [{ node: "Mark Vision Extraction Method", type: "main", index: 0 }],
      ],
    },
    "Mark Text Extraction Method": { main: [[{ node: "OpenAI Extract Stage 5 Text", type: "main", index: 0 }]] },
    "Mark Vision Extraction Method": { main: [[{ node: "OpenAI Extract Stage 5 PDF File", type: "main", index: 0 }]] },
    "OpenAI Extract Stage 5 Text": { main: [[{ node: "Attach Context To Text Output", type: "main", index: 0 }]] },
    "OpenAI Extract Stage 5 PDF File": { main: [[{ node: "Attach Context To Vision Output", type: "main", index: 0 }]] },
    "Attach Context To Text Output": { main: [[{ node: "Normalize Validate Stage 5 Result", type: "main", index: 0 }]] },
    "Attach Context To Vision Output": { main: [[{ node: "Normalize Validate Stage 5 Result", type: "main", index: 0 }]] },
    "Normalize Validate Stage 5 Result": { main: [[{ node: "Store Stage 5 Intake Result", type: "main", index: 0 }]] },
  },
  settings: { executionOrder: "v1" },
  staticData: null,
  pinData: {},
  tags: [],
  triggerCount: 1,
  updatedAt: "2026-07-30T00:00:00.000Z",
  versionId: "stage-5-generated",
};

const sourceWorkflow = {
  id: "stage-5-source-document-route",
  name: "Source Document Route",
  nodes: [
    node("66000000-0000-4500-8500-000000000001", "Webhook - Source PDF", "n8n-nodes-base.webhook", 2.1, [0, 0], {
      httpMethod: "GET",
      path: "coi-source/:certificate_id",
      authentication: "none",
      responseMode: "responseNode",
      options: {},
    }),
    node("66000000-0000-4500-8500-000000000002", "Load Certificate Source Path", "n8n-nodes-base.postgres", 2.6, [280, 0], {
      operation: "executeQuery",
      query: `SELECT
  c.id,
  c.original_filename,
  c.stored_path,
  (c.stored_path LIKE '/home/node/.n8n-files/certificates/%') AS safe_path
FROM (SELECT $1::int AS certificate_id) req
LEFT JOIN certificates c ON c.id = req.certificate_id;`,
      options: {
        queryReplacement: "={{ $json.params.certificate_id }}",
      },
    }, postgresCreds()),
    node("66000000-0000-4500-8500-000000000003", "Route Safe Stored PDF", "n8n-nodes-base.if", 2.2, [560, 0], {
      conditions: {
        options: { caseSensitive: true, leftValue: "", typeValidation: "strict" },
        conditions: [
          {
            id: "safe-path-condition",
            leftValue: "={{ Boolean($json.id && $json.stored_path && $json.safe_path) }}",
            rightValue: true,
            operator: { type: "boolean", operation: "true", singleValue: true },
          },
        ],
        combinator: "and",
      },
      options: {},
    }),
    node("66000000-0000-4500-8500-000000000004", "Read Stored Source PDF", "n8n-nodes-base.readWriteFile", 1.1, [840, -100], {
      operation: "read",
      fileSelector: "={{ $json.stored_path }}",
      options: {
        dataPropertyName: "data",
        fileName: "={{ $json.original_filename || 'certificate.pdf' }}",
        mimeType: "application/pdf",
      },
    }),
    node("66000000-0000-4500-8500-000000000005", "Respond With Stored PDF", "n8n-nodes-base.respondToWebhook", 1.5, [1120, -100], {
      respondWith: "binary",
      responseDataSource: "set",
      inputFieldName: "data",
      options: {
        responseHeaders: {
          entries: [
            { name: "Content-Type", value: "application/pdf" },
          ],
        },
      },
    }),
    node("66000000-0000-4500-8500-000000000006", "Respond Source PDF Not Found", "n8n-nodes-base.respondToWebhook", 1.5, [840, 140], {
      respondWith: "text",
      responseBody: "Source document not found.",
      options: {
        responseCode: 404,
      },
    }),
  ],
  connections: {
    "Webhook - Source PDF": { main: [[{ node: "Load Certificate Source Path", type: "main", index: 0 }]] },
    "Load Certificate Source Path": { main: [[{ node: "Route Safe Stored PDF", type: "main", index: 0 }]] },
    "Route Safe Stored PDF": {
      main: [
        [{ node: "Read Stored Source PDF", type: "main", index: 0 }],
        [{ node: "Respond Source PDF Not Found", type: "main", index: 0 }],
      ],
    },
    "Read Stored Source PDF": { main: [[{ node: "Respond With Stored PDF", type: "main", index: 0 }]] },
  },
  settings: { executionOrder: "v1" },
  staticData: null,
  pinData: {},
  tags: [],
  triggerCount: 1,
  updatedAt: "2026-07-30T00:00:00.000Z",
  versionId: "stage-5-generated",
};

// Assign by node name, never by array index. Index-based assignment broke once
// already: adding sticky notes to the front of the nodes array shifted every
// index, so the webhook IDs landed on the sticky notes and the routes 404'd
// while the workflows still reported active.
function setWebhookId(workflow, nodeName, webhookId) {
  const target = workflow.nodes.find((n) => n.name === nodeName);
  if (!target) {
    throw new Error(`Cannot set webhookId, node not found: ${nodeName}`);
  }
  target.webhookId = webhookId;
}

setWebhookId(sourceWorkflow, "Webhook - Source PDF", "stage-5-source-document-webhook");
setWebhookId(intakeWorkflow, "Form Trigger - Certificate Upload", "stage-5-coi-intake-form");

fs.mkdirSync(path.dirname(intakePath), { recursive: true });
fs.writeFileSync(intakePath, `${JSON.stringify(intakeWorkflow, null, 2)}\n`, "utf8");
fs.writeFileSync(sourcePath, `${JSON.stringify(sourceWorkflow, null, 2)}\n`, "utf8");
console.log(`Generated ${path.relative(repoRoot, intakePath)}`);
console.log(`Generated ${path.relative(repoRoot, sourcePath)}`);
