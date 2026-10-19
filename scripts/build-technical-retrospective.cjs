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
const documentTitle = 'I built a follow-up process for vendor paperwork.';
const slides = [
 {
  title: `I built a follow-up<br>process for vendor<br><span class="pay">${under('paperwork.', 'gold')}</span>`,
  cover: true,
  copy: 'Collecting insurance certificates is one job. Keeping track of missing documents, expiration dates and follow-ups is another. I built a process to connect them.',
  visual: '',
  footer: 'Vendor paperwork · From arrival to follow-up',
  sources: 'build-plan.md scope; docs/how-the-system-works.md; Stage 5 intake, Stage 6 watch/chase and Stage 7 dashboard exports.'
 },
 {
  title: 'I started with the<br>questions someone<br>has to keep answering',
  visual: `<div class="rt-visual">${steps([
   ['What is missing?','Which vendors have no certificate on file.'],
   [hl('What expires next?'),'Which recorded dates need attention.'],
   ['Who needs a follow-up?','Which outstanding requests are due again.']
  ])}</div>`,
  copy: 'I wanted one view of the paperwork and a repeatable way to request updates, without relying on someone to remember every date.',
  footer: 'The problem · Keeping track after the document arrives',
  sources: 'docs/how-the-system-works.md problem statement; stage_6_actionable_vendors in 004-stage-6-watch-chase.sql; Stage 7 dashboard read model.'
 },
 {
  title: `I connected the document<br>to the ${hl('next action')}`,
  visual: `<div class="rt-visual">${lane('When a certificate arrives',['Receive the<br>document','Read + check<br>the details','Update the<br>record'])}<div class="rt-state-rail">${hl('One register')} · Documents, dates and request history</div>${lane('When an update is due',['Find missing or<br>expiring paperwork','Draft a<br>request',`${box('Person reviews')}<br>before sending`])}</div>`,
  copy: 'I connected intake, date tracking and follow-up. The register keeps the document history; each vendor-facing chase email waits for a person to approve it.',
  footer: 'The process · Receive, record, follow up',
  sources: 'Stage 5-7 current runtime workflows; certificate/outreach storage functions; per-vendor approval workflow and daily watch caller.'
 },
 {
  title: `AI helps with reading.<br>A person ${under('decides to send.')}`,
  visual: `<div class="rt-visual"><div class="rt-columns"><div><h3>AI helps with</h3><p>Reading printed details</p><p>Drafting request wording</p></div><div><h3>Checks + review</h3><p>Checking dates and names</p><p>Getting a person's approval</p></div></div><div class="rt-match"><div class="rt-label">When the vendor name does not match</div><p>Keep it for ${box('review', 'gold')} instead of guessing.</p></div></div>`,
  copy: 'I used AI where reading and writing help. I kept the checks separate, and gave the person reviewing each chase email control over whether it sends.',
  footer: 'A design choice · Assistance with a clear approval step',
  sources: 'Extraction/drafting prompts; coi-stage-4-validator.js; 003-stage-5-intake.sql exact-match linkage and VENDOR_NOT_FOUND review; Stage 6 individual approval/send.'
 },
 {
  title: `I kept the ${hl('original')}<br>one click away`,
  visual: `<div class="rt-visual">${chain(['See a date<br>or flagged detail','Open the<br>original PDF','Check what the<br>document says'])}<div class="rt-state-rail">Saved together: document + recorded details</div></div>`,
  copy: 'I kept the original certificate linked to its record. Someone checking a date or a flagged detail can return to the document it came from.',
  footer: 'A design choice · Make the recorded details checkable',
  sources: 'Stage 5 storage-before-extraction and source route; Stage 7 certificate source links; 2026-10-10 source retrieval byte match in progress-notes.md.'
 },
 {
  title: 'Only one request<br>reached the approver',
  visual: `<div class="rt-visual">${lane('What went wrong',['Several<br>reminders','One approval<br>request','Others marked<br>as declined'])}${lane('What I changed',['Each<br>reminder',box('Its own approval'),'Send<br>or hold'])}<div class="rt-proof">Checked: ${hl('two separate approvals and two sends')}</div></div>`,
  copy: 'I found several pending reminders but only one approval request. I gave each reminder its own approval step, then checked that each could be reviewed separately.',
  footer: 'A failure I fixed · Check the interaction, not just the list',
  sources: 'progress-notes.md 2026-08-08 approval defect, failed loop attempt, independent two-vendor waits/approvals/sends; current Stage 6 each-mode child workflow.'
 },
 {
  title: `More urgent shouldn't<br>mean ${hl('start over')}`,
  visual: `<div class="rt-visual">${lane('Before · A new urgency label reset the history',['15 days<br>until expiry','14 days<br>until expiry','Could ask<br>again'])}${lane('After · Keep the same outstanding request',['15 days<br>until expiry','14 days<br>until expiry',box('Wait until due', 'gold')])}<div class="rt-proof">The ${under('seven-day follow-up window')} stays in place.</div></div>`,
  copy: 'The system treated a new urgency label as a new problem. I kept the reminder history attached to the same outstanding document instead.',
  footer: 'A failure I fixed · Remember that we already asked',
  sources: '004-stage-6-watch-chase.sql issue key excludes bucket; progress-notes.md 2026-07-31 equal-key verification and 16 SQL checks. This describes possible repeated requests, not a claimed delivered duplicate.'
 },
 {
  title: 'An unreadable document<br>still needs a next step',
  dark: true,
  visual: `<div class="rt-visual"><div class="rt-story-route"><p>Original PDF saved</p><p class="rt-story-arrow">↓</p><p>Try to read the document</p><p class="rt-story-arrow">↓</p><p>Unreadable → ${hl('Review record kept')}</p></div><div class="rt-proof">Checked through the actual upload form.</div></div>`,
  copy: 'A locked PDF could stop intake. I added a route that records the problem for review, with the original document retained for investigation.',
  footer: 'A failure I fixed · Give unreadable documents a review route',
  sources: 'progress-notes.md 2026-08-07 form fix; Stage 5 storage-before-reading, encryption check, extract continueErrorOutput to password review; f18 multipart form produced NEEDS_REVIEW with no matched vendor. Review is stored; no claim of a new dashboard review queue or notification.'
 },
 {
  title: 'I checked what happened<br>after each step',
  visual: `<div class="rt-visual">${table(['Situation I checked','What the record showed'],[
   ['A replacement arrives','Earlier record replaced'],
   ['Wrong document','Notice instead of filing'],
   ['Locked PDF','Recorded for review'],
   ['Two reminders','Separate approval requests'],
   ['Open the original','Returned file matched<br>the stored PDF']
  ],'rt-results')}</div>`,
  copy: 'I checked the record, the approval request and the original file, alongside whether a run finished. Each check followed a specific step in the process.',
  footer: 'Recorded checks · Documents, requests and stored results',
  sources: 'docs/stage-8-fixture-results.md replacement/non-certificate cases; progress-notes.md 2026-08-07 protected form upload, 2026-08-08 two independent approvals, 2026-10-10 byte-matched retrieval. Results are from separate recorded checks, not a fresh combined run or general benchmark.'
 },
 {
  title: 'What I would<br>improve next',
  visual: `<div class="rt-visual">${steps([
   [hl('Show work that gets stuck'),'Make failed steps visible to the person responsible.'],
   ['Avoid repeating the same work','Recognize the same email or attachment arriving again.'],
   ['Make recovery easier','Check what happens after an interruption or a lost file.']
  ])}</div>`,
  copy: 'I would focus next on visible failures, repeat-message handling and recovery. A useful process needs a clear next step when something interrupts it.',
  footer: 'Next improvements · Visibility, repeat handling and recovery',
  sources: 'docs/stage-9-production-readiness-plan.md and implementation-backlog.md: visible dead letters, alerts, message/attachment idempotency, retry/backoff, backup/restore. Proposed improvements; source_ref checks alone do not establish full replay or crash safety.'
 }
];
const caption = `An insurance certificate arrives in the inbox. Someone still has to record the dates, notice when an update is due and remember who needs another request.

I built a process to connect those steps for vendor paperwork.

It reads incoming certificates, keeps the original document linked to the record, surfaces missing or expiring paperwork, and drafts requests for updates. Each vendor-facing chase email waits for a person's approval.

I started with three questions: What is missing? What expires next? Who needs a follow-up?

Those questions shaped the build more than the choice of software. AI helps read the document and draft the wording. Separate checks handle dates and matching names. A person controls whether each chase email sends.

The failures taught me where the process needed more attention.

One batch created a list of pending reminders, but only one approval request reached the approver. I separated each reminder's approval process and checked that they worked independently.

Another rule treated a change in urgency as a new problem. That could restart the chase even though we had already asked for the same update. I kept the reminder history attached to the outstanding document as the deadline approached.

I also added a review route for unreadable PDFs, then checked it through the upload form. The original file stays available so the problem can be investigated.

I checked the stored records, the individual approval requests and the retrieved documents. I wanted to see what happened after each step, rather than stop at a successful run.

Next I would focus on making failed steps easier to see, recognizing repeated emails and attachments, and recovering cleanly after interruptions.

The problem I set out to solve was keeping paperwork moving: knowing what is on file, what needs attention and what should happen next.`;
const base = fs.readFileSync(path.join(root,'docs/carousels/post-01-what-ai-should-touch.html'),'utf8');
const snap = base.match(/<script>[\s\S]*?<\/script>/)[0];
const head = `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${documentTitle}</title><link href="../../tmp/carousel-fonts/fonts.css" rel="stylesheet"><link href="carousel-template.css" rel="stylesheet"></head><body>`;
const flowArrow = '<svg class="rt-flow-arrow" viewBox="0 0 40 24" aria-label="then"><path d="M2 12 H36 M27 3 L36 12 L27 21"/></svg>';
const stateArrow = '<svg class="rt-flow-arrow rt-flow-arrow--state" viewBox="0 0 24 40" aria-label="shared state"><path d="M12 3 V37 M4 11 L12 3 L20 11 M4 29 L12 37 L20 29"/></svg>';
const downArrow = '<svg class="rt-flow-arrow rt-flow-arrow--state" viewBox="0 0 24 40" aria-label="then"><path d="M12 3 V37 M4 29 L12 37 L20 29"/></svg>';
fs.writeFileSync(out, (head + slides.map((s,i)=>`<section class="slide technical${s.dark?' slide--invert':''}" data-slide="${i+1}"><div class="eyebrow"><span>VENDOR PAPERWORK · A BUILD RETROSPECTIVE</span></div><div class="body"><${s.cover?'h1':'h2'} class="${s.cover?'display rt-cover':'rt-title'}">${s.title}</${s.cover?'h1':'h2'}>${s.cover?'':s.visual}<p class="rt-copy">${s.copy}</p>${s.cover?s.visual:''}</div><div class="footer"><span>${s.footer}</span><b>${String(i+1).padStart(2,'0')}</b></div></section>`).join('\n') + snap + '</body></html>').replaceAll('→',flowArrow).replaceAll('↕',stateArrow).replaceAll('↓',downArrow));
const plain = s => s.replace(/<svg[\s\S]*?<\/svg>/g,'').replace(/<br\s*\/?>(?!$)/g,' / ').replace(/<\/(p|div|h3|li|tr)>/g,'\n').replace(/<[^>]*>/g,' ').replace(/[ \t]+/g,' ').replace(/ *\n */g,'\n').trim();
const md = `# Build retrospective: vendor paperwork

Created: 2026-10-19. Status: rendered draft for review. Not published or queued.

Audience: property management decision-makers and buyers, plus hiring managers. Lead with the recurring paperwork problem, explain decisions in plain language, and demonstrate problem-solving through specific failures and checks. No technology-stack list, schema excerpts or internal configuration in public copy. The owner explicitly changed the earlier engineering-heavy direction on 2026-10-20.

Document title: **${documentTitle}**

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
- The unreadable-document slide covers the implemented intake error route and recorded form-path check. Public copy focuses on implementation and specific checked behavior, without demo or synthetic-data framing, per the owner's 2026-10-20 revision request. This wording does not introduce a client deployment, accuracy score or customer-result claim.
- Structured output constrains shape; it does not guarantee factual correctness or deterministic model behavior. LOW confidence and date failures route to review, but NOT_A_COI and older documents take notice dispositions first. Unknown names reach review in storage even if the core validator returned store_on_file.
- Duplicate source_ref checks exist. Message-plus-attachment identity, safe concurrent processing and send crash recovery are not established by those checks.
- Two distinct approval waits and sends establish the repaired per-vendor interaction in that test. They do not establish concurrency, repeated-button safety or exactly-once delivery.
- Reference sources inspected read-only: renewal-retention technical retrospective HTML/PDF/content document; maintenance-triage carousel kit HTML/CSS and rendered post 5. Cream ruled paper, grain, Switzer, restrained Zodiak and meaning-based blue/gold annotations follow those references.
- This draft introduces shared technical layouts in the existing stylesheet. Annotation colors are independent of shape and selection boxes may appear inside the deck, per the current user direction. No per-deck style block or inline presentation styling is used.
- PDF, contact sheet and page renders are ignored build output. Sources, caption, evidence map and QA scripts are committed.

## Review verification

Final review completed 2026-10-20. Ten pages at 810 x 1012.5 points; embedded Switzer/Zodiak faces, no fallback families; one shared grain bitmap. All public text runs and character counts survive extraction. Text bounds and privacy checks pass, including PDF metadata, absent links and attachments. Every page was rendered at approximately 1080 x 1350 and visually reviewed along with the contact sheet; final changed pages were rechecked. No clipping, overlaps, missing marks or diagram errors remain. QA details are regenerated to ignored \`docs/carousels/out/technical-retrospective-qa.json\`.

This task did not rerun the live n8n fixture suite or send email. Claims use the implementation and recorded results cited above. No publishing or queue action was taken.
`;
fs.writeFileSync(path.join(root,'docs/technical-retrospective-carousel.md'),md);
console.log(`Built ${slides.length} slides and caption.`);
