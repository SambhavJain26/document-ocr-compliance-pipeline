"use strict";

const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const dashboardPath = path.join(repoRoot, "n8n-workflows", "stage-7-dashboard-demo-view.json");

function node(id, name, type, typeVersion, position, parameters = {}, credentials = undefined) {
  const base = { parameters, id, name, type, typeVersion, position };
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

const buildHtmlCode = `
const rows = $input.all().map((item) => item.json);
const blockedTerms = ["com" + "pliant", "veri" + "fied", "cov" + "ered", "appro" + "ved"];

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function money(value) {
  if (value === null || value === undefined || value === "") return "-";
  const amount = Number(value);
  if (!Number.isFinite(amount)) return "-";
  if (amount >= 1000000 && amount % 1000000 === 0) return "$" + (amount / 1000000) + "M";
  if (amount >= 1000 && amount % 1000 === 0) return "$" + (amount / 1000) + "k";
  return "$" + amount.toLocaleString("en-US");
}

function formatDate(value) {
  if (!value) return "-";
  const date = new Date(String(value) + "T00:00:00Z");
  if (Number.isNaN(date.getTime())) return escapeHtml(value);
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" });
}

function normalizeFlags(value) {
  if (Array.isArray(value)) return value;
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      return [];
    }
  }
  return [];
}

function flagLabel(flag) {
  const code = flag && typeof flag === "object" ? flag.code : String(flag || "");
  const details = flag && typeof flag === "object" && flag.details ? flag.details : {};
  if (code === "COVERAGE_GAP") {
    const days = Number(details.gap_days);
    if (Number.isFinite(days) && days > 0) return days + "-day paperwork gap";
    return "Paperwork gap";
  }
  if (code === "HOLDER_MISMATCH") return "Holder name needs review";
  if (code === "LIMIT_BELOW_MINIMUM") return "Limit below configured minimum";
  if (code === "POSSIBLE_DUPLICATE_VENDOR") return "Possible duplicate vendor";
  if (code === "NO_GL_LINE") return "No general liability line found";
  if (code === "PDF_PASSWORD_PROTECTED") return "Password-protected PDF";
  if (code === "LOW_CONFIDENCE") return "Low extraction confidence";
  return code ? code.toLowerCase().replace(/_/g, " ") : "";
}

function rowNotes(row) {
  const flags = normalizeFlags(row.validation_flags)
    .map(flagLabel)
    .filter(Boolean);
  const notes = flags.map((label) => '<span class="note note-warning">' + escapeHtml(label) + '</span>');
  if (row.cancellation_notice_wording) {
    notes.push('<span class="note note-neutral">Certificate states cancellation notice wording.</span>');
  }
  if (row.status_note) {
    notes.push('<span class="note note-critical">' + escapeHtml(row.status_note) + '</span>');
  }
  return notes.length ? '<div class="notes">' + notes.join("") + '</div>' : "";
}

function toneLabel(tone) {
  if (tone === "good") return "Current";
  if (tone === "warning") return "Watch";
  if (tone === "critical") return "Review";
  return "No file";
}

function sourceCell(row) {
  if (!row.source_url_path) return '<span class="source-muted">-</span>';
  return '<a class="source-link" href="' + escapeHtml(row.source_url_path) + '" target="_blank" rel="noreferrer">Open PDF</a>';
}

function countRows(predicate) {
  return rows.filter(predicate).length;
}

const counts = {
  total: rows.length,
  noFile: countRows((row) => !row.certificate_id),
  red: countRows((row) => row.display_tone === "critical"),
  expiring: countRows((row) => row.display_tone === "warning" && Number(row.days_to_expiry) >= 0 && Number(row.days_to_expiry) <= 30),
  review: countRows((row) => row.certificate_status === "NEEDS_REVIEW"),
  gaps: countRows((row) => Number(row.coverage_gap_count_marker || 0) > 0),
};

const tableRows = rows.map((row) => {
  const tone = escapeHtml(row.display_tone || "none");
  return '<tr class="row-' + tone + '">'
    + '<td><div class="vendor-cell"><span class="status-dot"></span><div><strong>' + escapeHtml(row.vendor_legal_name) + '</strong>' + rowNotes(row) + '</div></div></td>'
    + '<td>' + escapeHtml(row.trade || "-") + '</td>'
    + '<td>' + escapeHtml(row.insurer_name || "-") + '</td>'
    + '<td>' + escapeHtml(row.policy_number || "-") + '</td>'
    + '<td>' + escapeHtml(money(row.gl_each_occurrence)) + '</td>'
    + '<td>' + escapeHtml(formatDate(row.expiration_date)) + '</td>'
    + '<td><span class="status-pill">' + escapeHtml(row.display_status || "Needs review") + '</span></td>'
    + '<td class="chase-cell">' + escapeHtml(row.display_chase || "Not yet chased") + '</td>'
    + '<td>' + sourceCell(row) + '</td>'
    + '</tr>';
}).join("\\n");

const css = String.raw\`
:root {
  color-scheme: light;
  --bg: #f7f4ef;
  --surface: #fffdf8;
  --surface-2: #f0ece4;
  --text: #1f2933;
  --muted: #667085;
  --line: rgba(31, 41, 51, 0.12);
  --good: #16784f;
  --good-bg: #e6f4ec;
  --warn: #a15c00;
  --warn-bg: #fff1d6;
  --critical: #b42318;
  --critical-bg: #ffe4df;
  --none: #6b7280;
  --none-bg: #edf0f2;
  --link: #1d4ed8;
}
* { box-sizing: border-box; }
html { background: var(--bg); }
body {
  margin: 0;
  color: var(--text);
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  font-size: 16px;
  line-height: 1.5;
}
.skip-link {
  position: absolute;
  left: 16px;
  top: -48px;
  background: var(--text);
  color: #fff;
  padding: 8px 12px;
  border-radius: 6px;
  z-index: 10;
}
.skip-link:focus { top: 16px; }
.shell {
  width: min(100% - 32px, 1240px);
  margin: 0 auto;
  padding: 32px 0 40px;
}
header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 24px;
  padding: 4px 0 24px;
}
.eyebrow {
  margin: 0 0 4px;
  color: var(--muted);
  font-size: 13px;
  font-weight: 650;
}
h1 {
  margin: 0;
  font-size: 32px;
  line-height: 1.15;
  letter-spacing: 0;
}
.refresh {
  color: var(--muted);
  font-size: 14px;
  white-space: nowrap;
}
.summary {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 18px;
}
.metric {
  min-height: 80px;
  padding: 14px 16px;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 8px;
}
.metric span {
  display: block;
  color: var(--muted);
  font-size: 12px;
  font-weight: 650;
}
.metric strong {
  display: block;
  margin-top: 6px;
  font-size: 28px;
  line-height: 1.1;
}
.metric-critical strong { color: var(--critical); }
.metric-warning strong { color: var(--warn); }
.metric-none strong { color: var(--none); }
.table-wrap {
  overflow-x: auto;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 8px;
}
table {
  width: 100%;
  min-width: 980px;
  border-collapse: collapse;
}
caption {
  text-align: left;
  padding: 16px 18px;
  color: var(--muted);
  font-size: 14px;
  border-bottom: 1px solid var(--line);
}
th, td {
  padding: 14px 16px;
  border-bottom: 1px solid var(--line);
  text-align: left;
  vertical-align: top;
}
th {
  background: var(--surface-2);
  color: #3a4651;
  font-size: 12px;
  font-weight: 750;
  text-transform: uppercase;
}
tbody tr:last-child td { border-bottom: 0; }
.vendor-cell {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  min-width: 230px;
}
.status-dot {
  flex: 0 0 auto;
  width: 10px;
  height: 10px;
  margin-top: 7px;
  border-radius: 999px;
  background: var(--none);
}
.row-good .status-dot { background: var(--good); }
.row-warning .status-dot { background: var(--warn); }
.row-critical .status-dot { background: var(--critical); }
.row-none .status-dot { background: var(--none); }
.status-pill {
  display: inline-flex;
  max-width: 100%;
  padding: 5px 9px;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 650;
  background: var(--none-bg);
  color: var(--none);
  white-space: nowrap;
}
.chase-cell {
  color: var(--muted);
  font-size: 13px;
  white-space: nowrap;
}
.row-good .status-pill { background: var(--good-bg); color: var(--good); }
.row-warning .status-pill { background: var(--warn-bg); color: var(--warn); }
.row-critical .status-pill { background: var(--critical-bg); color: var(--critical); }
.notes {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 7px;
}
.note {
  display: inline-flex;
  max-width: 100%;
  padding: 3px 7px;
  border-radius: 6px;
  font-size: 12px;
  line-height: 1.3;
}
.note-warning { color: var(--warn); background: var(--warn-bg); }
.note-neutral { color: var(--muted); background: var(--none-bg); }
.note-critical { color: var(--critical); background: var(--critical-bg); }
.source-link {
  color: var(--link);
  font-weight: 650;
  text-decoration: none;
}
.source-link:hover { text-decoration: underline; }
.source-link:focus-visible, .skip-link:focus-visible {
  outline: 3px solid rgba(29, 78, 216, 0.35);
  outline-offset: 2px;
}
.source-muted { color: var(--muted); }
.mobile-list { display: none; }
@media (max-width: 780px) {
  .shell { width: min(100% - 24px, 1240px); padding-top: 24px; }
  header { display: block; }
  h1 { font-size: 26px; }
  .refresh { margin-top: 8px; white-space: normal; }
  .summary { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .table-wrap { display: none; }
  .mobile-list {
    display: grid;
    gap: 10px;
  }
  .mobile-card {
    background: var(--surface);
    border: 1px solid var(--line);
    border-left: 5px solid var(--none);
    border-radius: 8px;
    padding: 14px;
  }
  .mobile-card.row-good { border-left-color: var(--good); }
  .mobile-card.row-warning { border-left-color: var(--warn); }
  .mobile-card.row-critical { border-left-color: var(--critical); }
  .mobile-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin-top: 12px;
  }
  .mobile-label {
    display: block;
    color: var(--muted);
    font-size: 12px;
    font-weight: 650;
  }
}
\`;

const mobileRows = rows.map((row) => {
  const tone = escapeHtml(row.display_tone || "none");
  return '<article class="mobile-card row-' + tone + '">'
    + '<div class="vendor-cell"><span class="status-dot"></span><div><strong>' + escapeHtml(row.vendor_legal_name) + '</strong><br><span class="status-pill">' + escapeHtml(row.display_status || "Needs review") + '</span>' + rowNotes(row) + '</div></div>'
    + '<div class="mobile-grid">'
    + '<div><span class="mobile-label">Trade</span>' + escapeHtml(row.trade || "-") + '</div>'
    + '<div><span class="mobile-label">Carrier</span>' + escapeHtml(row.insurer_name || "-") + '</div>'
    + '<div><span class="mobile-label">Policy #</span>' + escapeHtml(row.policy_number || "-") + '</div>'
    + '<div><span class="mobile-label">GL Limit</span>' + escapeHtml(money(row.gl_each_occurrence)) + '</div>'
    + '<div><span class="mobile-label">Expires</span>' + escapeHtml(formatDate(row.expiration_date)) + '</div>'
    + '<div><span class="mobile-label">Chase</span>' + escapeHtml(row.display_chase || "Not yet chased") + '</div>'
    + '<div><span class="mobile-label">Source</span>' + sourceCell(row) + '</div>'
    + '</div></article>';
}).join("\\n");

let html = '<!doctype html><html lang="en"><head>'
  + '<meta charset="utf-8">'
  + '<meta name="viewport" content="width=device-width, initial-scale=1">'
  + '<meta http-equiv="refresh" content="5">'
  + '<title>Vendor Insurance Register</title>'
  + '<style>' + css + '</style>'
  + '</head><body>'
  + '<a class="skip-link" href="#register">Skip to register</a>'
  + '<main class="shell">'
  + '<header><div><p class="eyebrow">Harbourline Property Management LLC</p><h1>Vendor Insurance Register</h1></div><div class="refresh">Auto-refreshes every 5 seconds</div></header>'
  + '<section class="summary" aria-label="Register counts">'
  + '<div class="metric"><span>Total vendors</span><strong>' + counts.total + '</strong></div>'
  + '<div class="metric metric-none"><span>No certificate</span><strong>' + counts.noFile + '</strong></div>'
  + '<div class="metric metric-critical"><span>Expired or review</span><strong>' + counts.red + '</strong></div>'
  + '<div class="metric metric-warning"><span>Expiring in 30 days</span><strong>' + counts.expiring + '</strong></div>'
  + '<div class="metric metric-critical"><span>Needs review</span><strong>' + counts.review + '</strong></div>'
  + '<div class="metric metric-warning"><span>Paperwork gaps</span><strong>' + counts.gaps + '</strong></div>'
  + '</section>'
  + '<section id="register" class="table-wrap" aria-label="Vendor register"><table>'
  + '<caption>Rows show certificate dates and document notes from the local demo database.</caption>'
  + '<thead><tr><th scope="col">Vendor</th><th scope="col">Trade</th><th scope="col">Carrier</th><th scope="col">Policy #</th><th scope="col">GL Limit</th><th scope="col">Expires</th><th scope="col">Status</th><th scope="col">Chase</th><th scope="col">Source</th></tr></thead>'
  + '<tbody>' + tableRows + '</tbody></table></section>'
  + '<section class="mobile-list" aria-label="Vendor register mobile">' + mobileRows + '</section>'
  + '</main></body></html>';

const lower = html.toLowerCase();
for (const term of blockedTerms) {
  if (lower.includes(term)) {
    throw new Error("Dashboard HTML contained a blocked term.");
  }
}

return [{ json: { html } }];
`.trim();

const dashboardWorkflow = {
  id: "stage-7-dashboard-demo-view",
  name: "Stage 7 - Dashboard Demo View",
  nodes: [
    node("91000000-0000-4700-8700-000000000001", "Webhook - COI Dashboard", "n8n-nodes-base.webhook", 2.1, [0, 0], {
      httpMethod: "GET",
      path: "coi",
      authentication: "none",
      responseMode: "responseNode",
      options: {},
    }),
    node("91000000-0000-4700-8700-000000000002", "Webhook - COI Dashboard Stable URL", "n8n-nodes-base.webhook", 2.1, [0, 160], {
      httpMethod: "GET",
      path: "stage-7-dashboard-webhook/coi",
      authentication: "none",
      responseMode: "responseNode",
      options: {},
    }),
    node("92000000-0000-4700-8700-000000000001", "Load Stage 7 Dashboard Rows", "n8n-nodes-base.postgres", 2.6, [300, 80], {
      operation: "executeQuery",
      query: "SELECT * FROM stage_7_dashboard_rows(stage_6_parse_date(stage_6_config_value('stage_7_dashboard_as_of_date', ''), CURRENT_DATE));",
      options: {},
    }, postgresCreds()),
    node("93000000-0000-4700-8700-000000000001", "Build Stage 7 Dashboard HTML", "n8n-nodes-base.code", 2, [600, 80], {
      jsCode: buildHtmlCode,
    }),
    node("94000000-0000-4700-8700-000000000001", "Respond With Stage 7 Dashboard", "n8n-nodes-base.respondToWebhook", 1.5, [900, 80], {
      respondWith: "text",
      responseBody: "={{ $json.html }}",
      options: {
        responseHeaders: {
          entries: [
            { name: "Content-Type", value: "text/html; charset=utf-8" },
          ],
        },
      },
    }),
  ],
  connections: {
    "Webhook - COI Dashboard": { main: [[{ node: "Load Stage 7 Dashboard Rows", type: "main", index: 0 }]] },
    "Webhook - COI Dashboard Stable URL": { main: [[{ node: "Load Stage 7 Dashboard Rows", type: "main", index: 0 }]] },
    "Load Stage 7 Dashboard Rows": { main: [[{ node: "Build Stage 7 Dashboard HTML", type: "main", index: 0 }]] },
    "Build Stage 7 Dashboard HTML": { main: [[{ node: "Respond With Stage 7 Dashboard", type: "main", index: 0 }]] },
  },
  settings: { executionOrder: "v1" },
  staticData: null,
  pinData: {},
  tags: [],
  triggerCount: 1,
  updatedAt: "2026-07-30T00:00:00.000Z",
  versionId: "stage-7-generated",
};

dashboardWorkflow.nodes[0].webhookId = "stage-7-dashboard-webhook";
dashboardWorkflow.nodes[1].webhookId = "stage-7-dashboard-stable-url-webhook";

fs.mkdirSync(path.dirname(dashboardPath), { recursive: true });
fs.writeFileSync(dashboardPath, `${JSON.stringify(dashboardWorkflow, null, 2)}\n`, "utf8");
console.log(`Generated ${path.relative(repoRoot, dashboardPath)}`);
