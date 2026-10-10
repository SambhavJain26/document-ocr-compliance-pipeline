# Public work-sample evidence

The current PDF uses only flattened PNGs in `evidence/`. The older top-level canvas captures and `dashboard-illustrative.png` are historical assets and are excluded. `scripts/capture-upwork-work-sample.cjs` is a legacy illustration helper, not a source of genuine dashboard evidence.

## Rebuild and review

- `python scripts/render-upwork-work-sample.py` renders the current client PDF.
- `python scripts/verify-work-sample-pdf.py` checks privacy, structure, footers, text bounds and embedded image provenance.
- Render every page with Poppler and inspect at normal viewing size. Automated checks supplement visual review.
- Python dependencies: ReportLab, Pillow, fonttools, pypdf and pdfplumber. Fonts and their licenses are included in `fonts/`; the renderer instantiates static readable weights.

## Capture provenance

All editor and execution captures were made in the Codex in-app browser against the actual local n8n instance. Tidy Up was used on the six main workflows before canvas capture. Capture full native frames; perform final cropping and opaque redaction afterward. Do not recreate UI screens or substitute constructed dashboard rows.

Private originals and decoded execution data remain in ignored `tmp/work-sample-evidence/`. Canvas originals are under its `canvas-captures/` folder. `scripts/prepare-work-sample-images.py` documents the crop/redaction rectangles and writes flattened RGB PNGs. Those private files are deliberately not needed to rebuild the PDF from approved assets.

| Public evidence | Actual source | Observable result |
| --- | --- | --- |
| Intake and three-result form output | Preserved execution 4091, August 2026 | Certificate IDs 1, 2, 3; third result NEEDS_REVIEW |
| Fresh Apex result | Manual execution 4606, 10 October 2026 | Vendor 1, certificate 6, ON_FILE |
| Source document image | Live source webhook for certificate 6 | HTTP 200; PDF bytes equal stored original |
| Pending outreach | Preserved execution 4376 | 17 pending records; screenshot shows count and first rows |
| Northstar approval/send/log | Preserved execution 4397 | Approval true, Gmail SENT label, outreach 10 sent |
| Vista stop | Preserved execution 4403 | False response; outreach 15 declined; send node absent |
| No-PDF notices | Preserved execution 4407 | Ten approval messages from test mailbox recorded as notices |
| Dashboard, form | Actual running webhook/form pages | Apex current, Summit review; actual upload interface |

The original source PDF is an actual synthetic fixture, rendered from bytes delivered by the source route; its contact field is redacted. It is a document preview, not a fabricated application screenshot. Synthetic names and policy/record identifiers are retained to connect the journey. The no-PDF run must not be described as an actual vendor reply: its messages were approval emails received by the test mailbox. Real Gmail sends in these preserved runs used an owner-controlled test recipient.

Public layout retains the established landscape geometry, Geist 650 headings, Manrope 550/700, dark ink and green accents. Footer: `Vendor COI Chasing / Work Sample`, with page numbers. Disclosures appear in the overview and relevant captions; no public gaps or production-readiness checklist is included.
