"use strict";

// Render the actual dashboard Code node with illustrative synthetic rows.
// The local n8n stack is not required to reproduce this screenshot.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { chromium } = require("playwright");

const root = path.resolve(__dirname, "..");
const output = path.join(root, "tmp", "pdfs", "upwork-dashboard.png");
const workflow = JSON.parse(fs.readFileSync(path.join(root, "n8n-workflows", "stage-7-dashboard-demo-view.json"), "utf8"));
const buildNode = workflow.nodes.find((node) => node.name === "Build Stage 7 Dashboard HTML");
if (!buildNode) throw new Error("Dashboard renderer node missing from workflow export");

const rows = [
  { vendor_legal_name: "Vista Glass and Door LLC", trade: "Glazing", display_tone: "none", display_status: "No certificate on file", display_chase: "Request pending" },
  { vendor_legal_name: "Oakbend Tree Service LLC", trade: "Tree service", display_tone: "none", display_status: "No certificate on file", display_chase: "Not yet chased" },
  { vendor_legal_name: "Apex Plumbing Services LLC", trade: "Plumbing", certificate_id: 101, certificate_status: "ON_FILE", insurer_name: "North Coast Mutual", policy_number: "SYN-PL-1042", gl_each_occurrence: 1000000, expiration_date: "2027-05-15", display_tone: "good", display_status: "Current until May 15, 2027", display_chase: "Not yet chased", source_url_path: "#" },
  { vendor_legal_name: "Bright Hall Cleaning Co.", trade: "Cleaning", certificate_id: 102, certificate_status: "ON_FILE", insurer_name: "Cedar Bay Casualty", policy_number: "SYN-CL-1188", gl_each_occurrence: 1000000, expiration_date: "2026-10-18", days_to_expiry: 20, display_tone: "warning", display_status: "Expires in 20 days", display_chase: "Last request Sep 27", source_url_path: "#" },
  { vendor_legal_name: "Summit Roofing LLC", trade: "Roofing", certificate_id: 103, certificate_status: "NEEDS_REVIEW", insurer_name: "North Coast Mutual", policy_number: "SYN-RF-2045", gl_each_occurrence: 300000, expiration_date: "2027-02-10", display_tone: "critical", display_status: "Needs review", display_chase: "Paused for review", validation_flags: [{ code: "LIMIT_BELOW_MINIMUM" }], source_url_path: "#" },
  { vendor_legal_name: "Crestline HVAC LLC", trade: "HVAC", certificate_id: 104, certificate_status: "ON_FILE", insurer_name: "Cedar Bay Casualty", policy_number: "SYN-HV-3104", gl_each_occurrence: 1000000, expiration_date: "2026-08-20", display_tone: "critical", display_status: "Expired 39 days ago", display_chase: "Follow-up due", source_url_path: "#" },
];

const context = { $input: { all: () => rows.map((json) => ({ json })) } };
const result = vm.runInNewContext(`(function(){${buildNode.parameters.jsCode}\n})()`, context, { timeout: 1000 });
const html = result[0].json.html.replace('<meta http-equiv="refresh" content="5">', "");

(async () => {
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const browser = await chromium.launch({ headless: true, channel: "chrome" });
  const page = await browser.newPage({ viewport: { width: 1440, height: 880 }, deviceScaleFactor: 1.5 });
  await page.setContent(html, { waitUntil: "load" });
  await page.screenshot({ path: output, fullPage: true });
  await browser.close();
  console.log(output);
})().catch((error) => { console.error(error); process.exitCode = 1; });
