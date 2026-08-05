"use strict";

const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const dailyPath = path.join(repoRoot, "n8n-workflows", "stage-6-daily-watch-chase.json");
const replyPath = path.join(repoRoot, "n8n-workflows", "stage-6-non-pdf-reply-notice.json");

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
  const { __alwaysOutputData, ...cleanParameters } = parameters;
  const base = { parameters: cleanParameters, id, name, type, typeVersion, position };
  if (__alwaysOutputData) {
    base.alwaysOutputData = true;
  }
  if (credentials) {
    base.credentials = credentials;
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

function gmailCreds() {
  return {
    gmailOAuth2: {
      id: "Gmail account",
      name: "Gmail account",
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

const draftSchema = {
  type: "object",
  additionalProperties: false,
  required: ["subject", "body"],
  properties: {
    subject: { type: "string" },
    body: { type: "string" },
  },
};

const draftInstructions = `You draft short certificate paperwork request emails for a US residential property management company.

Rules:
- Return only JSON matching the schema.
- Keep body under 120 words.
- Be polite, direct, and specific.
- Ask for an updated certificate of liability insurance naming the configured certificate holder.
- Reference the vendor name, policy number when present, and expiration date when present.
- Never say or imply the vendor is compliant, verified, covered, approved, insured, uninsured, safe, or unsafe.
- This is an administrative paperwork request only.`;

const prepareDraftPayloadCode = `
// The Responses API returns { output: [ { content: [ { text } ] } ] }, and that
// text arrives already parsed as an object rather than as a JSON string. Two
// bugs used to live here: arrays satisfied "typeof x === 'object'" and were
// returned raw before the array branch could run, and the array branch then
// called JSON.parse on something that was already an object. The result was
// that a perfectly good model draft was silently discarded and every chase
// email fell back to the fixed template. Check arrays first, and accept the
// payload whether it arrives as an object or as a JSON string.
function normalizeModelOutput(value) {
  function asDraft(candidate) {
    if (candidate && typeof candidate === "object" && !Array.isArray(candidate)) {
      if (typeof candidate.subject === "string" || typeof candidate.body === "string") return candidate;
      return null;
    }
    if (typeof candidate === "string") {
      try { return asDraft(JSON.parse(candidate)); } catch (error) { return null; }
    }
    return null;
  }

  function fromResponses(list) {
    if (!Array.isArray(list)) return null;
    for (const entry of list) {
      const content = entry && entry.content;
      if (!Array.isArray(content)) continue;
      for (const part of content) {
        const found = asDraft(part && part.text);
        if (found) return found;
      }
    }
    return null;
  }

  if (Array.isArray(value)) return fromResponses(value) || {};

  if (value && typeof value === "object") {
    const fromOutput = fromResponses(value.output);
    if (fromOutput) return fromOutput;
    const direct = asDraft(value.output);
    if (direct) return direct;
    const fromText = asDraft(value.text);
    if (fromText) return fromText;
    return value;
  }

  return asDraft(value) || {};
}

function wordCount(text) {
  return String(text || "").trim().split(/\\s+/).filter(Boolean).length;
}

function containsForbidden(text) {
  return /\\b(compliant|verified|covered|approved)\\b/i.test(String(text || ""));
}

function escapeHtml(value) {
  return String(value == null ? "" : value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Postgres hands dates back as full ISO timestamps, not YYYY-MM-DD. Appending
// a time component to one of those produced an invalid date, and the guard
// below then returned the raw value, so vendor-facing emails read
// "expires 2026-06-26T00:00:00.000Z". Only add the time part when it is absent.
function formatDate(value) {
  if (!value) return null;
  const raw = String(value);
  const iso = /^\\d{4}-\\d{2}-\\d{2}$/.test(raw) ? raw + "T00:00:00Z" : raw;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return raw;
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" });
}

function fallbackDraft(item) {
  const vendor = item.vendor_legal_name;
  const holder = item.primary_holder || "Harbourline Property Management LLC";
  const policy = item.policy_number ? " for policy " + item.policy_number : "";
  const expiry = item.expiration_date ? " The current certificate date on file expires " + formatDate(item.expiration_date) + "." : "";
  if (item.bucket === "NEVER_RECEIVED") {
    return {
      subject: "Certificate request for " + vendor,
      body: "Hello,\\n\\nCould you please send a current certificate of liability insurance for " + vendor + " naming " + holder + " as certificate holder? We do not have a certificate on file for this vendor paperwork record.\\n\\nThank you."
    };
  }
  if (item.bucket === "RE_ATTEST") {
    return {
      subject: "Certificate confirmation request for " + vendor,
      body: "Hello,\\n\\nCould you please confirm whether the certificate paperwork" + policy + " is still current, or send an updated certificate naming " + holder + " as certificate holder if anything has changed?\\n\\nThank you."
    };
  }
  return {
    subject: "Updated certificate request for " + vendor,
    body: "Hello,\\n\\nCould you please send an updated certificate of liability insurance for " + vendor + " naming " + holder + " as certificate holder?" + expiry + "\\n\\nThank you."
  };
}

const sourceItems = $items("Load Stage 6 Actionable Vendors").map((item) => item.json);

return $input.all().map((item, index) => {
  const source = sourceItems[index] || item.json;
  const parsed = normalizeModelOutput(item.json);
  let subject = String(parsed.subject || "").trim();
  let body = String(parsed.body || "").trim();
  const invalid = !subject || !body || wordCount(body) > 120 || containsForbidden(subject + " " + body);
  if (invalid) {
    const fallback = fallbackDraft(source);
    subject = fallback.subject;
    body = fallback.body;
  }

  // The upload link is appended after validation rather than asked of the model.
  // The model must not invent URLs, and the boilerplate line should not count
  // against the 120-word limit applied to the drafted body.
  const uploadUrl = String(source.upload_form_url || "").trim();
  const bodyHtml = escapeHtml(body).replace(/\\n/g, "<br>")
    + (uploadUrl
      ? '<br><br>You can send it back as a reply with the PDF attached, or use our <a href="'
        + escapeHtml(uploadUrl) + '">certificate upload link</a>.'
      : "");

  return {
    json: {
      ...source,
      drafted_subject: subject,
      drafted_body: body,
      drafted_body_html: bodyHtml,
      upload_form_url: uploadUrl || null,
      draft_source: invalid ? "fallback_template" : "openai",
    },
  };
});
`.trim();

const prepareApprovalCode = `
const pendingItems = $items("Record Pending Outreach");
const draftItems = $items("Prepare Stage 6 Draft Payload");

return pendingItems.map((item, index) => {
  const draft = draftItems[index]?.json || {};
  const result = item.json.stage_6_record_pending_outreach || item.json.record_result || item.json;
  const outreachId = result.outreach_id || result.id;
  return {
    json: {
      ...draft,
      outreach_id: outreachId,
      approval_subject: "Approve certificate request: " + draft.vendor_legal_name,
      approval_message: [
        "Vendor: " + draft.vendor_legal_name,
        "Bucket: " + draft.bucket,
        "Intended recipient: " + draft.intended_recipient,
        draft.cc_recipient ? "CC: " + draft.cc_recipient : "CC: none",
        "Actual recipient: " + (draft.actual_recipient || "(not configured)"),
        "",
        // The approver sees the raw URL on purpose. They are reviewing what is
        // about to be sent, so the destination must be checkable here even
        // though the vendor-facing email hides it behind anchor text.
        "Upload link: " + (draft.upload_form_url || "(not configured)"),
        "",
        "Subject: " + draft.drafted_subject,
        "",
        draft.drafted_body,
      ].join("\\n"),
    },
  };
});
`.trim();

const recoverApprovalCode = `
const approvalItems = $input.all();
const contextItems = $items("Prepare Approval Email Payload");

return contextItems.map((item, index) => {
  const approval = approvalItems[index]?.json || {};
  const approved = approval?.data?.approved === true || approval?.approved === true || approval?.data?.approved === "true";
  return {
    json: {
      ...item.json,
      approval_response: approval,
      approved,
    },
  };
});
`.trim();

const buildSentLogPayloadCode = `
const sendItems = $input.all();
const approvalItems = $items("Recover Approval Result Context");

return approvalItems.map((item, index) => ({
  json: {
    outreach_id: item.json.outreach_id,
    actual_recipient: item.json.actual_recipient,
    follow_up_days: item.json.follow_up_days,
    approval_response: item.json.approval_response || {},
    send_response: sendItems[index]?.json || {},
  },
}));
`.trim();

const buildDeclinePayloadCode = `
return $input.all().map((item) => ({
  json: {
    outreach_id: item.json.outreach_id,
    approval_response: item.json.approval_response || {},
  },
}));
`.trim();

const buildConfigNoticeCode = `
return $input.all().map((item) => ({
  json: {
    source: "email",
    source_ref: "stage-6-config:" + item.json.issue_key,
    original_filename: null,
    notice_code: "STAGE_6_CONFIG_NOTICE",
    severity: "hard",
    message: item.json.approval_channel === "telegram"
      ? "Stage 6 Telegram approval was requested, but Telegram approval is not configured in the demo workflow."
      : "Stage 6 email approval cannot run until approver and actual recipient addresses are configured.",
    details: {
      vendor_id: item.json.vendor_id,
      vendor_legal_name: item.json.vendor_legal_name,
      approval_channel: item.json.approval_channel,
      approver_email: item.json.approver_email,
      actual_recipient: item.json.actual_recipient,
    },
    raw_payload: item.json,
  },
}));
`.trim();

const normalizeReplyCode = `
function bodyText(json) {
  return [json.text, json.html, json.body, json.snippet].filter(Boolean).join("\\n");
}

return $input.all().flatMap((item, index) => {
  const binaryEntries = Object.entries(item.binary || {});
  const pdfEntries = binaryEntries.filter(([, binary]) => {
    const fileName = String(binary?.fileName || "");
    const mimeType = String(binary?.mimeType || "");
    return mimeType === "application/pdf" || fileName.toLowerCase().endsWith(".pdf");
  });

  if (pdfEntries.length > 0) {
    return [];
  }

  const text = bodyText(item.json);
  const baseRef = item.json.id || item.json.messageId || item.json.threadId || String(Date.now()) + ":" + index;
  return [{
    json: {
      source: "email",
      source_ref: "email:" + baseRef + ":stage-6-no-pdf",
      from: item.json.from || item.json.sender || null,
      subject: item.json.subject || null,
      text,
      snippet: text.slice(0, 500),
    },
  }];
});
`.trim();

function openAiDraftNode(id, name, position) {
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
        values: [
          {
            type: "text",
            role: "user",
            content: `=Draft the certificate paperwork request.

Vendor: {{ $json.vendor_legal_name }}
Trade: {{ $json.trade || "Unknown" }}
Producer: {{ $json.producer_name || "Unknown" }}
Policy number: {{ $json.policy_number || "not on file" }}
Expiration date: {{ $json.expiration_date || "not on file" }}
Bucket: {{ $json.bucket }}
Certificate holder: Harbourline Property Management LLC
Recipient: {{ $json.intended_recipient }}`
          },
        ],
      },
      simplify: true,
      builtInTools: {},
      options: {
        instructions: draftInstructions,
        maxTokens: 350,
        // No temperature. Some models reject this parameter outright with a
        // bad request, which fails the whole run. The draft is bounded by the
        // word limit, the forbidden-word check and the fallback template.
        store: false,
        textFormat: {
          textOptions: {
            type: "json_schema",
            name: "coi_chase_email_draft",
            schema: JSON.stringify(draftSchema),
            strict: true,
          },
        },
      },
    },
    openAiCreds(),
  );
}

const dailyWorkflow = {
  id: "stage-6-daily-watch-chase",
  name: "Daily Watch and Chase",
  nodes: [
    sticky(
      "bb000000-0000-4600-8600-000000000001",
      [-80, -320],
      900,
      700,
      [
        "## Runs once a day at 08:00",
        "",
        "This is the half of the system that notices **nothing happening**. An inbox trigger only ever fires on arrivals; it cannot detect an absence, and absence is the actual failure this product exists to catch.",
        "",
        "Escalation runs **first**, so a vendor who has already ignored two requests is taken out of the loop before any new chase is considered.",
        "",
        "Then vendors are sorted into buckets: never received, expired, 14d, 30d, 60d, re-attestation. Vendors with no certificate come first, because they have no date to remind anyone.",
      ].join("\n"),
    ),
    sticky(
      "bb000000-0000-4600-8600-000000000002",
      [860, -320],
      880,
      700,
      [
        "## Draft, then log before sending",
        "",
        "The model writes a short request naming the vendor, policy number and expiry date. If it comes back empty, over 120 words, or containing a forbidden word, it is discarded and a fixed template is used instead.",
        "",
        "The upload link is appended **after** those checks, so the model cannot invent a destination.",
        "",
        "**Record Pending Outreach** writes the row before anything is sent, so a reminder can never go out without a record of it existing.",
      ].join("\n"),
    ),
    sticky(
      "bb000000-0000-4600-8600-000000000003",
      [1760, -400],
      1480,
      880,
      [
        "## The approval gate",
        "",
        "No approver address configured, so the run stores a config notice and emails nobody. That is a deliberate refusal, not a fallback.",
        "",
        "Otherwise the execution **pauses here** until a person clicks. The approver sees the vendor, the reason, the intended recipient, the upload destination, and the exact draft.",
        "",
        "**No response in 24 hours means it expires rather than sends.** Silence never results in mail going out.",
        "",
        "Clicking approve releases one specific email. It is not an approval of the vendor.",
      ].join("\n"),
      4,
    ),
    sticky(
      "bb000000-0000-4600-8600-000000000004",
      [3260, -360],
      860,
      700,
      [
        "## Logged either way",
        "",
        "**Approved**, so sent from the office's own mailbox, then send time, recipient, body and follow-up date are recorded.",
        "**Declined**, so logged and nothing is sent.",
        "",
        "After two ignored requests the escalation pre-pass hands the vendor to a person and pauses automated chasing. It will not email a vendor indefinitely.",
        "",
        "Note: `stage_6_outbound_test_mode` redirects real sends to a test address while it is true. Switch it off deliberately before live use.",
      ].join("\n"),
    ),
    node("71000000-0000-4600-8600-000000000001", "Manual Trigger - Run Stage 6 Watch", "n8n-nodes-base.manualTrigger", 1, [0, -120]),
    node("71000000-0000-4600-8600-000000000002", "Schedule Trigger - Daily Watch 08:00", "n8n-nodes-base.scheduleTrigger", 1.2, [0, 120], {
      rule: {
        interval: [
          {
            field: "cronExpression",
            expression: "0 8 * * *",
          },
        ],
      },
    }),
    node("72000000-0000-4600-8600-000000000001", "Escalate Stage 6 Overdue Outreach", "n8n-nodes-base.postgres", 2.6, [300, 0], {
      __alwaysOutputData: true,
      operation: "executeQuery",
      query: "SELECT * FROM stage_6_escalate_overdue(stage_6_parse_date(stage_6_config_value('stage_6_watch_as_of_date', ''), CURRENT_DATE));",
      options: {},
    }, postgresCreds()),
    node("72000000-0000-4600-8600-000000000002", "Load Stage 6 Actionable Vendors", "n8n-nodes-base.postgres", 2.6, [600, 0], {
      operation: "executeQuery",
      query: "SELECT * FROM stage_6_actionable_vendors(stage_6_parse_date(stage_6_config_value('stage_6_watch_as_of_date', ''), CURRENT_DATE));",
      options: {},
    }, postgresCreds()),
    openAiDraftNode("73000000-0000-4600-8600-000000000001", "OpenAI Draft Stage 6 Chase Email", [900, 0]),
    node("73000000-0000-4600-8600-000000000002", "Prepare Stage 6 Draft Payload", "n8n-nodes-base.code", 2, [1200, 0], { jsCode: prepareDraftPayloadCode }),
    node("73000000-0000-4600-8600-000000000003", "Record Pending Outreach", "n8n-nodes-base.postgres", 2.6, [1500, 0], {
      operation: "executeQuery",
      query: "SELECT stage_6_record_pending_outreach($1::jsonb) AS record_result;",
      options: {
        queryReplacement: "={{ JSON.stringify($json) }}",
      },
    }, postgresCreds()),
    node("73000000-0000-4600-8600-000000000004", "Prepare Approval Email Payload", "n8n-nodes-base.code", 2, [1800, 0], { jsCode: prepareApprovalCode }),
    node("73000000-0000-4600-8600-000000000005", "Route Email Approval Configured", "n8n-nodes-base.if", 2.2, [2100, 0], {
      conditions: {
        options: { caseSensitive: true, leftValue: "", typeValidation: "strict" },
        conditions: [
          {
            id: "approval-channel-email",
            leftValue: "={{ $json.approval_channel }}",
            rightValue: "email",
            operator: { type: "string", operation: "equals" },
          },
          {
            id: "approver-configured",
            leftValue: "={{ Boolean($json.approver_email) }}",
            rightValue: true,
            operator: { type: "boolean", operation: "true", singleValue: true },
          },
          {
            id: "actual-recipient-configured",
            leftValue: "={{ Boolean($json.actual_recipient) }}",
            rightValue: true,
            operator: { type: "boolean", operation: "true", singleValue: true },
          },
        ],
        combinator: "and",
      },
      options: {},
    }),
    node("73000000-0000-4600-8600-000000000006", "Store Stage 6 Config Notice Payload", "n8n-nodes-base.code", 2, [2400, 260], { jsCode: buildConfigNoticeCode }),
    node("73000000-0000-4600-8600-000000000007", "Store Stage 6 Config Notice", "n8n-nodes-base.postgres", 2.6, [2700, 260], {
      operation: "executeQuery",
      query: "SELECT stage_6_store_config_notice($1::jsonb) AS config_notice_result;",
      options: {
        queryReplacement: "={{ JSON.stringify($json) }}",
      },
    }, postgresCreds()),
    node("74000000-0000-4600-8600-000000000001", "Gmail Approval - Send and Wait", "n8n-nodes-base.gmail", 2.1, [2400, -80], {
      resource: "message",
      operation: "sendAndWait",
      sendTo: "={{ $json.approver_email }}",
      subject: "={{ $json.approval_subject }}",
      message: "={{ $json.approval_message }}",
      responseType: "approval",
      approvalOptions: {
        values: {
          approvalType: "double",
          approveLabel: "Approve",
          disapproveLabel: "Decline",
          buttonApprovalStyle: "primary",
          buttonDisapprovalStyle: "secondary",
        },
      },
      options: {
        limitWaitTime: {
          values: {
            limitType: "afterTimeInterval",
            resumeAmount: 24,
            resumeUnit: "hours",
          },
        },
        appendAttribution: false,
      },
    }, gmailCreds()),
    node("74000000-0000-4600-8600-000000000002", "Recover Approval Result Context", "n8n-nodes-base.code", 2, [2700, -80], { jsCode: recoverApprovalCode }),
    node("74000000-0000-4600-8600-000000000003", "Route Approved Stage 6 Email", "n8n-nodes-base.if", 2.2, [3000, -80], {
      conditions: {
        options: { caseSensitive: true, leftValue: "", typeValidation: "strict" },
        conditions: [
          {
            id: "approval-result-approved",
            leftValue: "={{ $json.approved }}",
            rightValue: true,
            operator: { type: "boolean", operation: "true", singleValue: true },
          },
        ],
        combinator: "and",
      },
      options: {},
    }),
    node("74000000-0000-4600-8600-000000000004", "Gmail Send Approved Stage 6 Chase", "n8n-nodes-base.gmail", 2.1, [3300, -200], {
      resource: "message",
      operation: "send",
      sendTo: "={{ $json.actual_recipient }}",
      subject: "={{ $json.drafted_subject }}",
      emailType: "html",
      message: "={{ $json.drafted_body_html }}",
      options: {
        ccList: "={{ $json.send_mode === 'test_override' ? '' : ($json.cc_recipient || '') }}",
        appendAttribution: false,
      },
    }, gmailCreds()),
    node("74000000-0000-4600-8600-000000000005", "Build Sent Outreach Log Payload", "n8n-nodes-base.code", 2, [3600, -200], { jsCode: buildSentLogPayloadCode }),
    node("74000000-0000-4600-8600-000000000006", "Mark Outreach Sent", "n8n-nodes-base.postgres", 2.6, [3900, -200], {
      operation: "executeQuery",
      query: "SELECT stage_6_mark_outreach_sent($1::jsonb) AS sent_result;",
      options: {
        queryReplacement: "={{ JSON.stringify($json) }}",
      },
    }, postgresCreds()),
    node("74000000-0000-4600-8600-000000000007", "Build Declined Outreach Log Payload", "n8n-nodes-base.code", 2, [3300, 60], { jsCode: buildDeclinePayloadCode }),
    node("74000000-0000-4600-8600-000000000008", "Mark Outreach Declined", "n8n-nodes-base.postgres", 2.6, [3600, 60], {
      operation: "executeQuery",
      query: "SELECT stage_6_mark_outreach_declined($1::jsonb) AS decline_result;",
      options: {
        queryReplacement: "={{ JSON.stringify($json) }}",
      },
    }, postgresCreds()),
  ],
  connections: {
    "Manual Trigger - Run Stage 6 Watch": { main: [[{ node: "Escalate Stage 6 Overdue Outreach", type: "main", index: 0 }]] },
    "Schedule Trigger - Daily Watch 08:00": { main: [[{ node: "Escalate Stage 6 Overdue Outreach", type: "main", index: 0 }]] },
    "Escalate Stage 6 Overdue Outreach": { main: [[{ node: "Load Stage 6 Actionable Vendors", type: "main", index: 0 }]] },
    "Load Stage 6 Actionable Vendors": { main: [[{ node: "OpenAI Draft Stage 6 Chase Email", type: "main", index: 0 }]] },
    "OpenAI Draft Stage 6 Chase Email": { main: [[{ node: "Prepare Stage 6 Draft Payload", type: "main", index: 0 }]] },
    "Prepare Stage 6 Draft Payload": { main: [[{ node: "Record Pending Outreach", type: "main", index: 0 }]] },
    "Record Pending Outreach": { main: [[{ node: "Prepare Approval Email Payload", type: "main", index: 0 }]] },
    "Prepare Approval Email Payload": { main: [[{ node: "Route Email Approval Configured", type: "main", index: 0 }]] },
    "Route Email Approval Configured": {
      main: [
        [{ node: "Gmail Approval - Send and Wait", type: "main", index: 0 }],
        [{ node: "Store Stage 6 Config Notice Payload", type: "main", index: 0 }],
      ],
    },
    "Store Stage 6 Config Notice Payload": { main: [[{ node: "Store Stage 6 Config Notice", type: "main", index: 0 }]] },
    "Gmail Approval - Send and Wait": { main: [[{ node: "Recover Approval Result Context", type: "main", index: 0 }]] },
    "Recover Approval Result Context": { main: [[{ node: "Route Approved Stage 6 Email", type: "main", index: 0 }]] },
    "Route Approved Stage 6 Email": {
      main: [
        [{ node: "Gmail Send Approved Stage 6 Chase", type: "main", index: 0 }],
        [{ node: "Build Declined Outreach Log Payload", type: "main", index: 0 }],
      ],
    },
    "Gmail Send Approved Stage 6 Chase": { main: [[{ node: "Build Sent Outreach Log Payload", type: "main", index: 0 }]] },
    "Build Sent Outreach Log Payload": { main: [[{ node: "Mark Outreach Sent", type: "main", index: 0 }]] },
    "Build Declined Outreach Log Payload": { main: [[{ node: "Mark Outreach Declined", type: "main", index: 0 }]] },
  },
  settings: { executionOrder: "v1" },
  staticData: null,
  pinData: {},
  tags: [],
  triggerCount: 1,
  updatedAt: "2026-07-30T00:00:00.000Z",
  versionId: "stage-6-generated",
};

const replyWorkflow = {
  id: "stage-6-non-pdf-reply-notice",
  name: "Non-PDF Reply Notice",
  nodes: [
    sticky(
      "bb000000-0000-4600-8600-000000000011",
      [-80, -320],
      920,
      600,
      [
        "## Replies that are not certificates",
        "",
        "The most common reply to a certificate request is not a certificate. It is \"my agent will send it Monday\", a link to a carrier portal, or a question.",
        "",
        "Without this workflow those replies sit unread in a mailbox nobody watches, and the vendor gets chased again a week later as though they had ignored you. That is the fastest way to sour a working relationship with a tradesperson you depend on.",
        "",
        "A reply that **does** carry a PDF is picked up by **COI Intake** instead, through its own Gmail trigger.",
      ].join("\n"),
    ),
    node("81000000-0000-4600-8600-000000000001", "Gmail Trigger - Stage 6 Replies", "n8n-nodes-base.gmailTrigger", 1.4, [0, 0], {
      authentication: "oAuth2",
      event: "messageReceived",
      simple: false,
      maxResults: 10,
      filters: {
        q: "-has:attachment",
        readStatus: "unread",
      },
      options: {
        downloadAttachments: true,
        dataPropertyAttachmentsPrefixName: "attachment_",
      },
    }, gmailCreds()),
    node("81000000-0000-4600-8600-000000000002", "Normalize Stage 6 Reply Notice", "n8n-nodes-base.code", 2, [300, 0], { jsCode: normalizeReplyCode }),
    node("81000000-0000-4600-8600-000000000003", "Store Stage 6 Reply Notice", "n8n-nodes-base.postgres", 2.6, [600, 0], {
      operation: "executeQuery",
      query: "SELECT stage_6_store_reply_notice($1::jsonb) AS reply_notice_result;",
      options: {
        queryReplacement: "={{ JSON.stringify($json) }}",
      },
    }, postgresCreds()),
  ],
  connections: {
    "Gmail Trigger - Stage 6 Replies": { main: [[{ node: "Normalize Stage 6 Reply Notice", type: "main", index: 0 }]] },
    "Normalize Stage 6 Reply Notice": { main: [[{ node: "Store Stage 6 Reply Notice", type: "main", index: 0 }]] },
  },
  settings: { executionOrder: "v1" },
  staticData: null,
  pinData: {},
  tags: [],
  triggerCount: 1,
  updatedAt: "2026-07-30T00:00:00.000Z",
  versionId: "stage-6-generated",
};

fs.mkdirSync(path.dirname(dailyPath), { recursive: true });
fs.writeFileSync(dailyPath, `${JSON.stringify(dailyWorkflow, null, 2)}\n`, "utf8");
fs.writeFileSync(replyPath, `${JSON.stringify(replyWorkflow, null, 2)}\n`, "utf8");
console.log(`Generated ${path.relative(repoRoot, dailyPath)}`);
console.log(`Generated ${path.relative(repoRoot, replyPath)}`);
