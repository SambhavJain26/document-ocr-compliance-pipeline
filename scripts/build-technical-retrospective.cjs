/* Public copy and diagrams. Run from any directory; no service access. */
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'docs/carousels/technical-retrospective-vendor-coi.html');
const under = (s, color='blue') => `<span class="pen pen--under pen--${color}">${s}<svg viewBox="0 0 300 20" preserveAspectRatio="none"><path d="M4,12 C64,3 148,4 214,9 C250,12 274,12 296,7"/><path d="M12,18 C72,10 150,11 222,15" opacity=".55"/></svg></span>`;
const box = (s, color='blue') => `<span class="sel ${color==='gold'?'sel--gold':''}">${s}<i></i><i></i><i></i><i></i></span>`;
const hl = (s, color='gold') => `<span class="hl ${color==='blue'?'hl--blue':''}">${s}</span>`;
const strike = s => `<span class="pen pen--strike pen--gold">${s}<svg viewBox="0 0 300 12" preserveAspectRatio="none"><path d="M2,7 C74,3 168,10 298,4"/></svg></span>`;
const arrow = '<div class="rt-arrow">→</div>';
const chain = (labels) => `<div class="rt-chain rt-chain--${labels.length}">${labels.map(s=>`<div class="rt-node">${s}</div>`).join(arrow)}</div>`;
const lane = (label,labels) => `<div class="rt-lane"><div class="rt-label">${label}</div>${chain(labels)}</div>`;
const table = (headers, rows, cls='') => `<table class="rt-table ${cls}"><thead><tr>${headers.map(s=>`<th>${s}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${r.map(s=>`<td>${s}</td>`).join('')}</tr>`).join('')}</tbody></table>`;
const steps = rows => `<ol class="rt-steps">${rows.map(([h,p],i)=>`<li><b>${String(i+1).padStart(2,'0')}</b><h3>${h}</h3><p>${p}</p></li>`).join('')}</ol>`;
const slides = [
 {
  title: `I built a COI chaser.<br>One approval<br>wasn't<br><span class="pay">${under('enough.', 'gold')}</span>`,
  cover: true,
  copy: 'I automated certificate tracking and renewal reminders. Then a batch approval defect forced me to change the execution boundary.',
  visual: '<p class="rt-stack">n8n / OpenAI / Postgres / Gmail</p>',
  footer: 'Applied AI · Vendor certificate chasing',
  sources: 'progress-notes.md: 2026-08-08 per-vendor approval architecture fix; Stage 5/6 exports.'
 },
 {
  title: 'Track the paperwork.<br>Keep the source.',
  visual: `<div class="rt-visual">${lane('Intake', ['Gmail /<br>upload form','Save PDF +<br>extract facts','Validate +<br>file result'])}<div class="rt-state-rail">↕ &nbsp; ${hl('Postgres')} · Certificate facts + outreach history &nbsp; ↕</div>${lane('Daily chase', ['Select due<br>paperwork','Draft +<br>log pending',`${hl('Human approval')}<br>then Gmail`])}<div class="rt-label rt-bottom-label">Dashboard + original PDF links read the stored record</div></div>`,
  copy: "I built this to track contractors' certificates of insurance. n8n coordinates the steps; Postgres holds durable state for intake, reminders and the dashboard.",
  footer: 'Implemented · Six runtime workflows · Paperwork tracking only',
  sources: 'All six Stage 5-7 runtime exports; db/postgres/001-schema.sql, 003-stage-5-intake.sql, 004-stage-6-watch-chase.sql, 005-stage-7-dashboard.sql; docs/how-the-system-works.md.'
 },
 {
  title: `I give the model<br>a ${hl('narrow job')}`,
  visual: `<div class="rt-visual"><div class="rt-columns"><div><h3>Model</h3><p>Transcribe printed facts</p><p>Report self-confidence</p><p>Draft reminder wording</p></div><div><h3>Code + people</h3><p>Match vendor identity</p><p>Check dates and limits</p><p>Approve each chase email</p></div></div><div class="rt-match"><div class="rt-label">Deterministic identity</div><p>Normalized exact name → Link vendor</p><p>Near or unmatched → ${box('Review', 'gold')}</p></div></div>`,
  copy: 'I kept filing and chase decisions outside the model. A confidence label is self-report; it does not establish calibrated accuracy or insurance status.',
  footer: 'Implemented · Incoming documents never create vendors',
  sources: 'coi-stage-4-validator.js findVendorMatch; 003-stage-5-intake.sql exact-match link and VENDOR_NOT_FOUND; Stage 6 approval workflow; extraction and drafting prompts.'
 },
 {
  title: `Schema sets ${under('shape.')}<br>Code sets disposition.`,
  visual: `<div class="rt-visual"><div class="rt-label">Extraction contract · Selected fields</div>${table(['Field / rule','Configured constraint'],[['additionalProperties','false'],['extraction_confidence','HIGH | MEDIUM | LOW'],['addl_insd_asserted','boolean; checkbox assertion']],'rt-schema')}<div class="rt-routes"><p>Invalid dates / LOW confidence → ${hl('NEEDS_REVIEW')}</p><p>Matched + soft flags only → ON_FILE + flags</p><p>Not a COI / older document → Notice; no filing</p></div></div>`,
  copy: 'I preserve what the page asserts. A checked box cannot establish an endorsement. Soft flags remain visible on filed records; ON_FILE is a storage status.',
  footer: 'Configuration + implemented rules · No coverage judgment',
  sources: 'docs/schemas/coi-extraction.schema.json; coi-stage-4-validator.js validateExtraction/buildResult; 003-stage-5-intake.sql notice dispositions.'
 },
 {
  title: `One validator.<br>${box('Reproducible', 'gold')} exports.`,
  visual: `<div class="rt-visual">${steps([
   ['Shared JavaScript + JSON Schema','One validator feeds the core harness and live intake.'],
   ['Generators → workflow JSON','I change source, then regenerate reviewable exports.'],
   [under('Import + verify'),'Credentials bind in n8n. Real routes and stored outputs matter.']
  ])}</div>`,
  copy: 'I keep rules in source because editing embedded workflow code would fork the logic until the next rebuild. Generated exports make the deployed graph inspectable.',
  footer: 'Implemented build pipeline · Credential secrets stay outside Git',
  sources: 'scripts/generate-stage-4-workflow.js and generate-stage-5-workflows.js read validatorSource/schema; Stage 5-7 generators and verify scripts; workflow credential references.'
 },
 {
  title: 'The approval gate<br>only paused once',
  visual: `<div class="rt-visual">${lane('Before · One execution for the whole batch',['Many vendors','One Gmail wait','Missing results<br>read as declined'])}<div class="rt-cause">Looping back into the same wait also failed.</div>${lane('Fix · One child execution per vendor',['Execute Workflow<br>mode: each',box('Own wait'),'Own approval<br>then send'])}<div class="rt-proof">Recorded check: ${hl('2 waits → 2 approvals → 2 sends')}</div></div>`,
  copy: 'I found pending rows for everyone but only one real approval request. In this n8n setup, a Wait node could pause each execution only once.',
  footer: 'Recorded fix · Independent approval executions',
  sources: 'progress-notes.md 2026-08-08: decoded flatted execution data, failed Split In Batches attempt, two independent waits and approvals eight seconds apart; generate-stage-6-workflows.js mode each; stage-6-vendor-approval-request.json.'
 },
 {
  title: 'A new bucket<br>bypassed the cooldown',
  visual: `<div class="rt-visual"><div class="rt-label">Before · Issue identity included urgency</div><div class="rt-key">vendor + certificate + ${strike('bucket')} + expiry</div>${chain(['15 days left<br>30d bucket','14 days left<br>14d bucket','New key<br>Cooldown lost'])}<div class="rt-key rt-key--after"><div class="rt-label">After · Stable issue identity</div>vendor + certificate + expiry</div><div class="rt-proof">Checked: ${hl('same key across buckets', 'blue')}</div></div>`,
  copy: 'I removed the bucket from the issue key and checked equality across buckets. The seven-day follow-up window and ignored-request count now survive urgency changes.',
  footer: 'Recorded fix · Key equality checked · Existing 16 SQL checks passed',
  sources: '004-stage-6-watch-chase.sql stage_6_vendor_issue_key; progress-notes.md 2026-07-31 fix and equality verification. Existing tests derive keys through the function, not independent literal expectations.'
 },
 {
  title: 'My intake checks used<br>the wrong context',
  dark: true,
  visual: `<div class="rt-visual"><div class="rt-signal"><div><span class="rt-label">Before · Unreadable PDF</span><strong>FAIL</strong></div><div><span class="rt-label">After · Error output</span><strong>${under('REVIEW', 'gold')}</strong></div></div><div class="rt-routes rt-routes--dark"><p>Form / Gmail → Missing internal field → Routing error</p><p>Fix: inspect PDF bytes + catch extraction failures</p><p>Byte checks alone miss filesystem-backed binary</p></div><div class="rt-proof">Form checks: ${hl('filing, review and notice routes')}</div></div>`,
  copy: 'I replaced an internal-field comparison with an encryption check and an extraction-error route. Then I verified the fix through the actual upload form.',
  footer: 'Recorded fix · Unreadable documents reach review',
  sources: 'progress-notes.md 2026-08-07 form intake fix: undefined fixture_id on form/Gmail, byte-level /Encrypt fast path, filesystem-binary limitation, continueErrorOutput guard; multipart form checks f01/f03 ON_FILE, f18 NEEDS_REVIEW, f11 notice. Current Stage 5 generator and export.'
 },
 {
  title: 'What the recorded<br>checks establish',
  visual: `<div class="rt-visual">${table(['Evidence','Recorded result'],[
   ['Intake checks','Filing, review, notice<br>and renewals passed'],
   ['Watch + storage','18 + 8 checks passed'],
   ['Approval repair','2 waits; 2 approvals;<br>2 sends'],
   ['October intake','ON_FILE + byte-matched PDF'],
   ['Unreadable PDF',hl('NEEDS_REVIEW')]
  ],'rt-results')}</div>`,
  copy: 'I checked stored rows, independent approvals and retrieved PDF bytes. The checks cover filing, review, notices and renewals across the connected workflows.',
  footer: 'Recorded workflow, SQL and source-document checks',
  sources: 'docs/stage-8-fixture-results.md 2026-07-30 original suite; progress-notes.md 2026-08-05 18/8 checks, 2026-08-08 approval repair, 2026-10-10 fresh manual intake and byte-identical source route. No new service execution for this carousel.'
 },
 {
  title: 'What I would<br>improve next',
  visual: `<div class="rt-visual">${steps([
   ['Expand document evaluation','Held-out documents; repeat runs; field and routing errors.'],
   [hl('Make failures visible'),'Bounded backoff, dead letters, alerts, heartbeat and canary.'],
   ['Protect state and recovery','Message + attachment identity; concurrent runs; uncertain sends.']
  ])}</div>`,
  copy: 'I would protect public routes and test storage and restore. Source-reference checks exist; full mailbox replay protection, retries and monitoring remain unbuilt.',
  footer: 'Next changes · Evaluation, recovery and operational visibility',
  sources: '003-stage-5-intake.sql source_ref checks; docs/stage-9-production-readiness-plan.md and implementation-backlog.md; 004-stage-6-watch-chase.sql test-mode defaults; progress-notes.md current boundaries. Held-out evaluation and concurrency tests are proposed here, not recorded implemented work.'
 }
];
const caption = `I built an AI workflow for a recurring administrative job: collecting contractor insurance certificates, recording their dates, surfacing missing or expiring paperwork, and drafting renewal reminders.

I used n8n for orchestration and Postgres for durable state. OpenAI transcribes printed facts and drafts wording. JavaScript and SQL control identity matching, validation, filing and chase eligibility. Each vendor-facing chase email requires its own human approval.

Three failures made the engineering interesting.

The batch approval step created pending rows for many vendors but sent only one real approval request. Looping through the same Wait node did not fix it. I moved approval and sending into a separate execution per vendor, then checked two independent waits, approvals and sends.

My reminder issue key included the urgency bucket. Moving from 15 days before expiry to 14 changed the key, bypassing the follow-up window and resetting the ignored-request count. I removed the bucket so the issue keeps its history as urgency changes.

My intake routing depended on a field only the manual entry path supplied. Form and Gmail uploads failed because that field was missing. I replaced the comparison with an encryption check and routed extraction errors to review. Then I checked the actual upload form, including filing, unreadable-document and non-certificate paths.

The carousel covers the architecture, output contract, reproducible exports, these defects and the evidence behind the fixes. A filed certificate is paperwork on record, not confirmation of insurance coverage. The additional-insured checkbox stays an assertion in the schema.

I checked the connected behavior through SQL checks, separate Gmail approval executions, form uploads and byte-matched PDF retrieval. I looked at stored and delivered outputs alongside execution status.

Next I would expand document evaluation and add durable message and attachment identity, bounded retries, visible failure handling, monitoring, protected public routes, and tested recovery. The engineering lesson I took from this build: define what the model may decide, preserve the state that future actions depend on, and verify the output a person actually receives.`;
const base = fs.readFileSync(path.join(root,'docs/carousels/post-01-what-ai-should-touch.html'),'utf8');
const snap = base.match(/<script>[\s\S]*?<\/script>/)[0];
const head = `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>I built a COI chaser. One approval wasn't enough.</title><link href="../../tmp/carousel-fonts/fonts.css" rel="stylesheet"><link href="carousel-template.css" rel="stylesheet"></head><body>`;
const flowArrow = '<svg class="rt-flow-arrow" viewBox="0 0 40 24" aria-label="then"><path d="M2 12 H36 M27 3 L36 12 L27 21"/></svg>';
const stateArrow = '<svg class="rt-flow-arrow rt-flow-arrow--state" viewBox="0 0 24 40" aria-label="shared state"><path d="M12 3 V37 M4 11 L12 3 L20 11 M4 29 L12 37 L20 29"/></svg>';
fs.writeFileSync(out, (head + slides.map((s,i)=>`<section class="slide technical${s.dark?' slide--invert':''}" data-slide="${i+1}"><div class="eyebrow"><span>APPLIED AI · VENDOR CERTIFICATE CHASING</span></div><div class="body"><${s.cover?'h1':'h2'} class="${s.cover?'display rt-cover':'rt-title'}">${s.title}</${s.cover?'h1':'h2'}>${s.cover?'':s.visual}<p class="rt-copy">${s.copy}</p>${s.cover?s.visual:''}</div><div class="footer"><span>${s.footer}</span><b>${String(i+1).padStart(2,'0')}</b></div></section>`).join('\n') + snap + '</body></html>').replaceAll('→',flowArrow).replaceAll('↕',stateArrow));
const plain = s => s.replace(/<svg[\s\S]*?<\/svg>/g,'').replace(/<br\s*\/?>(?!$)/g,' / ').replace(/<\/(p|div|h3|li|tr)>/g,'\n').replace(/<[^>]*>/g,' ').replace(/[ \t]+/g,' ').replace(/ *\n */g,'\n').trim();
const md = `# Technical retrospective: vendor COI chasing

Created: 2026-10-19. Status: rendered draft for review. Not published or queued.

Audience: people hiring AI engineers and applied AI engineers. This task intentionally expands COI as certificate of insurance and explains vendor paperwork for readers outside property management. It overrides the older buyer-only audience and glossary guidance for this artifact.

Document title: **I built a COI chaser. One approval wasn't enough.**

Editable source: \`docs/carousels/technical-retrospective-vendor-coi.html\`.
Copy + build source: \`scripts/build-technical-retrospective.cjs\`.
Review PDF: \`docs/carousels/out/technical-retrospective-vendor-coi.pdf\`.
Contact sheet: \`docs/carousels/out/technical-retrospective-preview.png\`.

Prepare fonts once: bundled Python, \`scripts/prepare-carousel-fonts.py\` (fonttools; downloads official Fontshare faces to ignored tmp/ and repairs their internal family names for reliable PDF embedding).
Build: \`node scripts/build-technical-retrospective.cjs\`.
Render: \`.\\scripts\\generate-linkedin-carousel.ps1 -Name technical-retrospective-vendor-coi\`.
Verify + preview: bundled Python, \`scripts/verify-technical-retrospective.py\`.

## LinkedIn caption

${caption}

## Slide copy and diagrams

The diagram text below is public content. Evidence references are internal notes and do not appear in the PDF. Diagrams explain implementation; none imitates a screenshot or claims to be an observed model response.

${slides.map((s,i)=>`### Slide ${i+1}\n\n**Title:** ${plain(s.title)}\n\n**Body:** ${s.copy}\n\n**Diagram / labels:**\n\n${plain(s.visual)}\n\n**Footer:** ${s.footer}\n\n**Evidence:** ${s.sources}`).join('\n\n')}

## Evidence boundaries and design review

- Stage 8's original report predates later approval, model and intake repairs. Its all-pass status is historical; this draft does not claim the full suite was rerun after those repairs.
- The third defect now covers the recorded intake-context failure and its verified form-path repair. Public copy focuses on implementation and specific checked behavior, without demo or synthetic-data framing, per the owner's 2026-10-20 revision request. This wording does not introduce a client deployment, accuracy score or customer-result claim.
- Structured output constrains shape; it does not guarantee factual correctness or deterministic model behavior. LOW confidence and date failures route to review, but NOT_A_COI and older documents take notice dispositions first. Unknown names reach review in storage even if the core validator returned store_on_file.
- Duplicate source_ref checks exist. Message-plus-attachment identity, safe concurrent processing and send crash recovery are not established by those checks.
- Two distinct approval waits and sends establish the repaired per-vendor interaction in that test. They do not establish concurrency, repeated-button safety or exactly-once delivery.
- Reference sources inspected read-only: renewal-retention technical retrospective HTML/PDF/content document; maintenance-triage carousel kit HTML/CSS and rendered post 5. Cream ruled paper, grain, Switzer, restrained Zodiak and meaning-based blue/gold annotations follow those references.
- This draft introduces shared technical layouts in the existing stylesheet. Annotation colors are independent of shape and selection boxes may appear inside the deck, per the current user direction. No per-deck style block or inline presentation styling is used.
- PDF, contact sheet and page renders are ignored build output. Sources, caption, evidence map and QA scripts are committed.

## Review verification

Final review completed 2026-10-20. Ten pages at 810 x 1012.5 points; seven embedded Switzer/Zodiak faces, no fallback families; one shared grain bitmap. All public text runs and character counts survive extraction. Text bounds and privacy checks pass, including PDF metadata, absent links and attachments. Every page was rendered at approximately 1080 x 1350 and visually reviewed along with the contact sheet; final changed pages were rechecked. No clipping, overlaps, missing marks or diagram errors remain. QA details are regenerated to ignored \`docs/carousels/out/technical-retrospective-qa.json\`.

This task did not rerun the live n8n fixture suite or send email. Claims use the implementation and recorded results cited above. No publishing or queue action was taken.
`;
fs.writeFileSync(path.join(root,'docs/technical-retrospective-carousel.md'),md);
console.log(`Built ${slides.length} slides and caption.`);
