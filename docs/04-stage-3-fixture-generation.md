# Stage 3 — Fixture generation

**Document 04 · Estimated time: 3–5 hours · Cost: $0**

Twenty synthetic certificates, generated from a declarative JSON spec by one Python script, regenerating in a single command. You have no client data, so the fixtures *are* your test suite — and because they are date-relative, "expires in 20 days" stays true whether you demo tomorrow or in September.

**Gate:** `make fixtures` produces 20 files in `fixtures/out/`, and fixture 2's GL expiry is exactly 20 days from today.

---

## 3.1 The copyright constraint — non-negotiable

ACORD forms are copyrighted and licensed rather than sold. Reading a certificate a vendor sent your client is not a licensed activity; **manufacturing replicas of the blank form is a different thing.**

| Do | Do not |
|---|---|
| Same field *names* and tabular structure | Pixel-accurate replica of the ACORD 25 layout |
| Your own visual design, fonts, and spacing | The ACORD logo, form number, or copyright notice |
| Visible `SPECIMEN — SYNTHETIC TEST DOCUMENT` watermark on every page | Anything that could be mistaken for a real certificate |
| Obviously fictional carriers and vendors (`.example` domains) | Real carrier names or NAIC numbers |
| Say "reads standard certificate of liability insurance forms" in writing | "ACORD 25", "ACORD certified", "ACORD integrated" in written marketing |

Saying "ACORD 25" out loud on a call is ordinary industry shorthand and is fine. Writing it on your website is a trademark problem stacked on a copyright one. The mitigation costs nothing, so take it.

This is a description of the risk shape, not legal advice.

---

## 3.2 The fixture set

Every date is expressed as an **offset from generation day**, so the set never goes stale.

| # | File | Tests | Vendor | Expected outcome |
|---|---|---|---|---|
| 1 | `f01-clean-current.pdf` | Happy path, 3 coverage lines | Vaughn Electric | `ON_FILE`, green, HIGH |
| 2 | `f02-expiring-20d.pdf` | Amber state — **demo hero** | Kessler HVAC | `ON_FILE`, amber, `D30` bucket |
| 3 | `f03-expired-34d.pdf` | Red state — **demo hero** | Mercer Plumbing | `ON_FILE`, red, `EXPIRED` |
| 4 | `f04-scanned.pdf` | Vision branch | Vaughn Electric (alt) | Vision path, correct dates, MEDIUM |
| 5 | `f05-inverted-dates.pdf` | Rule 1 | Calder Painting | `NEEDS_REVIEW` + `DATE_INVERTED` |
| 6 | `f06-wrong-holder.pdf` | Rule 4/12 | Bexley Cleaning | `ON_FILE` + `HOLDER_MISMATCH` |
| 7 | `f07-low-limits.pdf` | Rule 5/11 | Rowan Roofing | `ON_FILE` + `LIMIT_BELOW_MINIMUM` |
| 8 | `f08-four-expiries.pdf` | Earliest-expiry logic | Ashgrove GC | Dashboard shows earliest, not GL |
| 9 | `f09-no-gl.pdf` | Rule 3 | Thorne Pest | `ON_FILE` + `NO_GL_LINE` |
| 10a/b | `f10a-…`, `f10b-…` | Multi-attachment | Fenwick, Selby | Two independent certificates |
| 11 | `f11-not-a-coi.pdf` | Classification | — | Zero vendor rows, `dead_letter` `NOT_A_COI` |
| 12 | `f12-renewal.pdf` | Supersede, rule 8 | Kessler HVAC | Fixture 2 → `SUPERSEDED`, row green |
| 13 | `f13-coverage-gap.pdf` | Rule 9 — **sleeper moment** | Mercer Plumbing | `ON_FILE` + `COVERAGE_GAP` (14 days) |
| 14 | *(no file)* | `NEVER_RECEIVED` | Orme, Padstow, Quill | Enter chase queue on first run |
| 15 | `f15-sole-prop-no-wc.pdf` | Rule 10 suppression | Alder Landscaping | `ON_FILE`, **no** WC flag |
| 16 | `f16-owner-llc-holder.pdf` | Rule 12 | Linden Glass | `ON_FILE`, **no** holder mismatch |
| 17 | `f17-near-duplicate.pdf` | Rule 13 | "Mercer Plumbing & Heating" | Review item, **no** merge |
| 18 | `f18-encrypted.pdf` | Graceful failure | Draycott Tree | `dead_letter` `PDF_ENCRYPTED` |
| 19 | `f19-portal-link.eml` | Step 6.7 | Whitlock Gutter | Manager notice, no fetch |
| 20 | `f20-cancellation-wording.pdf` | Prompt rule 8 | Harrow Appliance | Wording captured verbatim |

### The five that separate a demo from a toy

**4 — the scan.** Half a prospect's vendors photograph certificates with a phone. Showing it work *and drop to MEDIUM with a plain-English reason* is more persuasive than showing it work silently.

**6 — wrong holder.** Certificates naming the wrong entity are common (an agent copied the previous job's template) and most managers have never thought about it. Flagging one shows them a problem they did not know they had.

**13 — the coverage gap.** A 14-day hole between an expiring policy and its replacement is invisible to a spreadsheet, invisible to Buildium's assignment warning, and invisible to a human comparing two PDFs six months apart. When the dashboard says *"14-day gap in March"*, you have shown something no process they own could have caught.

**14 — the absence.** Not a fixture at all. Three grey rows on an otherwise working register is the most common real-world state and the picture that sells.

**15 — the WC-exempt sole proprietor.** Proves the system does not cry wolf. Anyone who has used a compliance tool that flagged their reliable one-man handyman will care about this more than any feature.

---

## 3.3 `fixtures/spec/fixtures.json`

Abbreviated to four representative entries; the full file follows the same shape for all 20. Date offsets are integers in days from generation day.

```json
{
  "$schema_note": "Dates are day-offsets from generation day. Negative = past.",
  "defaults": {
    "holder": "Harbourline Property Management LLC",
    "holder_address": "1140 Ferngate Road, Suite 210\nCharlotte, NC 28210",
    "watermark": "SPECIMEN — SYNTHETIC TEST DOCUMENT",
    "insurers": {
      "A": { "name": "Northgate Mutual Insurance Co", "naic": "90001" },
      "B": { "name": "Cardinal Casualty Company",     "naic": "90002" },
      "C": { "name": "Ironvale Indemnity Group",      "naic": "90003" }
    }
  },
  "fixtures": [
    {
      "id": "f01-clean-current",
      "cert_date_offset": -14,
      "producer": {
        "name": "Kestrel Insurance Partners",
        "address": "88 Marlow Street\nRaleigh, NC 27601",
        "contact": "Dana Whitfield",
        "phone": "(919) 555-0142",
        "email": "certs@kestrelins.example"
      },
      "insured": {
        "name": "Vaughn Electric Co",
        "address": "412 Kestrel Way\nCharlotte, NC 28216"
      },
      "coverages": [
        { "letter": "A", "type": "GENERAL_LIABILITY", "policy": "NGM-GL-4482119",
          "eff_offset": -120, "exp_offset": 245,
          "addl_insd": true, "subr_wvd": true,
          "limits": { "each_occurrence": 1000000, "damage_rented": 100000,
                      "med_exp": 15000, "personal_adv": 1000000,
                      "general_aggregate": 2000000, "products_agg": 2000000 } },
        { "letter": "B", "type": "AUTO", "policy": "CCC-AU-771204",
          "eff_offset": -120, "exp_offset": 245,
          "addl_insd": true, "subr_wvd": false,
          "limits": { "combined_single": 1000000 } },
        { "letter": "C", "type": "WORKERS_COMP", "policy": "IIG-WC-330871",
          "eff_offset": -120, "exp_offset": 245,
          "addl_insd": false, "subr_wvd": true,
          "limits": { "el_each_accident": 1000000, "el_disease_employee": 1000000,
                      "el_disease_limit": 1000000 } }
      ],
      "description": "Harbourline Property Management LLC is included as additional insured with respect to general liability where required by written contract.",
      "expect": { "status": "ON_FILE", "confidence": "HIGH", "flags": [] }
    },

    {
      "id": "f02-expiring-20d",
      "cert_date_offset": -340,
      "producer": {
        "name": "Bramble & Co Insurance",
        "address": "2 Ridley Plaza\nCharlotte, NC 28202",
        "contact": "Marcus Ilori",
        "phone": "(704) 555-0119",
        "email": "certs@brambleco.example"
      },
      "insured": {
        "name": "Kessler Heating & Air Inc",
        "address": "77 Dunmore Ave\nCharlotte, NC 28205"
      },
      "coverages": [
        { "letter": "A", "type": "GENERAL_LIABILITY", "policy": "NGM-GL-5510882",
          "eff_offset": -345, "exp_offset": 20,
          "addl_insd": true, "subr_wvd": false,
          "limits": { "each_occurrence": 1000000, "damage_rented": 100000,
                      "med_exp": 10000, "personal_adv": 1000000,
                      "general_aggregate": 2000000, "products_agg": 2000000 } }
      ],
      "description": "Certificate holder is additional insured per written contract.",
      "expect": { "status": "ON_FILE", "confidence": "HIGH", "flags": [], "bucket": "D30" }
    },

    {
      "id": "f13-coverage-gap",
      "cert_date_offset": -18,
      "supersedes": "f03-expired-34d",
      "producer": {
        "name": "Kestrel Insurance Partners",
        "address": "88 Marlow Street\nRaleigh, NC 27601",
        "contact": "Dana Whitfield",
        "phone": "(919) 555-0142",
        "email": "certs@kestrelins.example"
      },
      "insured": {
        "name": "Mercer Plumbing LLC",
        "address": "930 Halloway Drive\nCharlotte, NC 28217"
      },
      "coverages": [
        { "letter": "A", "type": "GENERAL_LIABILITY", "policy": "NGM-GL-6620441",
          "eff_offset": -20, "exp_offset": 345,
          "addl_insd": true, "subr_wvd": true,
          "limits": { "each_occurrence": 1000000, "damage_rented": 100000,
                      "med_exp": 10000, "personal_adv": 1000000,
                      "general_aggregate": 2000000, "products_agg": 2000000 } }
      ],
      "description": "Replacement policy following non-renewal of prior term.",
      "expect": { "status": "ON_FILE", "flags": ["COVERAGE_GAP"], "gap_days": 14 }
    },

    {
      "id": "f20-cancellation-wording",
      "cert_date_offset": -30,
      "producer": {
        "name": "Pinecrest Agency",
        "address": "15 Bellhaven Court\nDurham, NC 27701",
        "contact": "Priya Raman",
        "phone": "(984) 555-0188",
        "email": "certs@pinecrest.example"
      },
      "insured": {
        "name": "Harrow Appliance Repair",
        "address": "220 Selwyn Lane\nCharlotte, NC 28209"
      },
      "coverages": [
        { "letter": "B", "type": "GENERAL_LIABILITY", "policy": "CCC-GL-118902",
          "eff_offset": -35, "exp_offset": 330,
          "addl_insd": false, "subr_wvd": false,
          "limits": { "each_occurrence": 500000, "damage_rented": 50000,
                      "med_exp": 5000, "personal_adv": 500000,
                      "general_aggregate": 1000000, "products_agg": 1000000 } }
      ],
      "description": "Should any of the above described policies be cancelled before the expiration date thereof, thirty (30) days written notice will be given to the certificate holder.",
      "expect": { "status": "ON_FILE", "captures": "cancellation_notice_wording" }
    }
  ]
}
```

---

## 3.4 `fixtures/generate.py`

Complete and runnable. Renders every fixture, then applies the two post-processing transforms (rasterise for fixture 4, encrypt for fixture 18).

```python
#!/usr/bin/env python3
"""
Vendor COI Chasing — synthetic fixture generator.

Renders layout-similar (NOT facsimile) certificate of liability insurance
documents from a declarative JSON spec. Every document carries a SPECIMEN
watermark, fictional carriers, and .example domains.

Usage:
    python generate.py --spec spec/fixtures.json --out out/
    python generate.py --spec spec/fixtures.json --out out/ --only f02-expiring-20d
"""

from __future__ import annotations

import argparse
import io
import json
import shutil
import sys
from datetime import date, timedelta
from pathlib import Path

from reportlab.lib.colors import Color, black, white
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas as rl_canvas

PAGE_W, PAGE_H = letter          # 612 x 792 pt
M = 24                           # page margin
LINE = 0.5                       # hairline weight
GREY = Color(0.45, 0.45, 0.45)
LIGHT = Color(0.92, 0.92, 0.92)

COVERAGE_LABELS = {
    "GENERAL_LIABILITY": "COMMERCIAL GENERAL LIABILITY",
    "AUTO":              "AUTOMOBILE LIABILITY",
    "UMBRELLA":          "UMBRELLA LIAB / EXCESS LIAB",
    "WORKERS_COMP":      "WORKERS COMPENSATION AND EMPLOYERS' LIABILITY",
    "OTHER":             "OTHER",
}

LIMIT_LABELS = [
    ("each_occurrence",      "EACH OCCURRENCE"),
    ("damage_rented",        "DAMAGE TO RENTED PREMISES"),
    ("med_exp",              "MED EXP (Any one person)"),
    ("personal_adv",         "PERSONAL & ADV INJURY"),
    ("general_aggregate",    "GENERAL AGGREGATE"),
    ("products_agg",         "PRODUCTS - COMP/OP AGG"),
    ("combined_single",      "COMBINED SINGLE LIMIT"),
    ("each_occurrence_umb",  "EACH OCCURRENCE"),
    ("aggregate_umb",        "AGGREGATE"),
    ("el_each_accident",     "E.L. EACH ACCIDENT"),
    ("el_disease_employee",  "E.L. DISEASE - EA EMPLOYEE"),
    ("el_disease_limit",     "E.L. DISEASE - POLICY LIMIT"),
]


# ───────────────────────── helpers ──────────────────────────

def offset_to_date(base: date, days: int | None) -> str:
    """Spec offsets are days from generation day. Output is MM/DD/YYYY."""
    if days is None:
        return ""
    return (base + timedelta(days=int(days))).strftime("%m/%d/%Y")


def money(v) -> str:
    if v is None:
        return ""
    return f"$ {int(v):,}"


def wrap(text: str, width: int) -> list[str]:
    """Crude greedy wrap. Adequate for fixed-width boxes at 7pt Helvetica."""
    out: list[str] = []
    for para in (text or "").split("\n"):
        line = ""
        for word in para.split():
            trial = f"{line} {word}".strip()
            if len(trial) <= width:
                line = trial
            else:
                out.append(line)
                line = word
        out.append(line)
    return out


# ───────────────────────── drawing ──────────────────────────

def box(c, x, y, w, h, label=None, label_size=5.5):
    c.setLineWidth(LINE)
    c.setStrokeColor(black)
    c.rect(x, y, w, h)
    if label:
        c.setFont("Helvetica", label_size)
        c.setFillColor(GREY)
        c.drawString(x + 3, y + h - 7, label)
        c.setFillColor(black)


def text_block(c, x, y, lines, size=7.5, leading=9):
    c.setFont("Helvetica", size)
    for i, ln in enumerate(lines):
        c.drawString(x, y - i * leading, ln)


def watermark(c, msg):
    c.saveState()
    c.setFillColor(Color(0.85, 0.30, 0.30, alpha=0.16))
    c.setFont("Helvetica-Bold", 34)
    c.translate(PAGE_W / 2, PAGE_H / 2)
    c.rotate(38)
    c.drawCentredString(0, 0, "SPECIMEN")
    c.setFont("Helvetica-Bold", 11)
    c.drawCentredString(0, -26, msg)
    c.restoreState()


def draw_certificate(c, spec: dict, defaults: dict, base: date):
    """Render one page. Layout-similar to a standard certificate, not a copy."""
    y = PAGE_H - M

    # ── Title ──
    c.setFont("Helvetica-Bold", 13)
    c.drawCentredString(PAGE_W / 2, y - 12, "CERTIFICATE OF LIABILITY INSURANCE")
    c.setFont("Helvetica", 6.5)
    c.setFillColor(GREY)
    c.drawRightString(PAGE_W - M, y - 12,
                      f"DATE: {offset_to_date(base, spec['cert_date_offset'])}")
    c.setFillColor(black)
    y -= 22

    # ── Disclaimer. This paragraph IS the product's honesty constraint,
    #    stated by the document itself. Keep it on every fixture. ──
    disclaimer = (
        "THIS CERTIFICATE IS ISSUED AS A MATTER OF INFORMATION ONLY AND CONFERS NO "
        "RIGHTS UPON THE CERTIFICATE HOLDER. THIS CERTIFICATE DOES NOT AFFIRMATIVELY "
        "OR NEGATIVELY AMEND, EXTEND OR ALTER THE COVERAGE AFFORDED BY THE POLICIES "
        "BELOW. THIS CERTIFICATE OF INSURANCE DOES NOT CONSTITUTE A CONTRACT BETWEEN "
        "THE ISSUING INSURER(S), AUTHORIZED REPRESENTATIVE OR PRODUCER, AND THE "
        "CERTIFICATE HOLDER."
    )
    c.setFillColor(LIGHT)
    c.rect(M, y - 30, PAGE_W - 2 * M, 30, fill=1, stroke=0)
    c.setFillColor(black)
    c.setFont("Helvetica-Bold", 5.6)
    for i, ln in enumerate(wrap(disclaimer, 150)):
        c.drawString(M + 4, y - 8 - i * 7, ln)
    y -= 38

    # ── PRODUCER | CONTACT ──
    half = (PAGE_W - 2 * M) / 2
    p = spec["producer"]
    box(c, M, y - 66, half, 66, "PRODUCER")
    text_block(c, M + 4, y - 18,
               [p["name"]] + p["address"].split("\n"))
    box(c, M + half, y - 66, half, 66, "CONTACT")
    text_block(c, M + half + 4, y - 18, [
        f"NAME:   {p['contact']}",
        f"PHONE:  {p['phone']}",
        f"E-MAIL: {p['email']}",
    ])
    y -= 70

    # ── INSURED | INSURERS ──
    ins = spec["insured"]
    insurers = spec.get("insurers", defaults["insurers"])
    ins_h = 20 + 10 * len(insurers)
    box(c, M, y - ins_h, half, ins_h, "INSURED")
    text_block(c, M + 4, y - 18, [ins["name"]] + ins["address"].split("\n"))
    box(c, M + half, y - ins_h, half, ins_h, "INSURER(S) AFFORDING COVERAGE      NAIC #")
    for i, (letter_, meta) in enumerate(sorted(insurers.items())):
        c.setFont("Helvetica", 7)
        c.drawString(M + half + 4, y - 18 - i * 10, f"INSURER {letter_}:  {meta['name']}")
        c.drawRightString(PAGE_W - M - 4, y - 18 - i * 10, meta["naic"])
    y -= ins_h + 6

    # ── COVERAGES table ──
    c.setFont("Helvetica-Bold", 7)
    c.drawString(M, y - 8, "COVERAGES")
    c.setFont("Helvetica", 6)
    c.drawString(M + 60, y - 8,
                 "THIS IS TO CERTIFY THAT THE POLICIES OF INSURANCE LISTED BELOW HAVE BEEN "
                 "ISSUED TO THE INSURED NAMED ABOVE FOR THE POLICY PERIOD INDICATED.")
    y -= 14

    # Column geometry
    cols = [M, M + 20, M + 168, M + 194, M + 220, M + 340, M + 396, M + 452, PAGE_W - M]
    headers = ["INSR\nLTR", "TYPE OF INSURANCE", "ADDL\nINSD", "SUBR\nWVD",
               "POLICY NUMBER", "POLICY EFF\n(MM/DD/YYYY)", "POLICY EXP\n(MM/DD/YYYY)", "LIMITS"]

    hdr_h = 16
    c.setFillColor(LIGHT)
    c.rect(M, y - hdr_h, PAGE_W - 2 * M, hdr_h, fill=1, stroke=0)
    c.setFillColor(black)
    c.setLineWidth(LINE)
    c.rect(M, y - hdr_h, PAGE_W - 2 * M, hdr_h)
    c.setFont("Helvetica-Bold", 5.2)
    for i, h in enumerate(headers):
        for j, part in enumerate(h.split("\n")):
            c.drawString(cols[i] + 2, y - 6 - j * 6, part)
    for x in cols[1:-1]:
        c.line(x, y - hdr_h, x, y - hdr_h)
    y -= hdr_h

    # Rows
    for cov in spec["coverages"]:
        limits = [(lbl, cov["limits"][k]) for k, lbl in LIMIT_LABELS if k in cov["limits"]]
        row_h = max(24, 5 + 8 * len(limits))

        c.setLineWidth(LINE)
        c.rect(M, y - row_h, PAGE_W - 2 * M, row_h)
        for x in cols[1:-1]:
            c.line(x, y - row_h, x, y)

        c.setFont("Helvetica-Bold", 7)
        c.drawCentredString((cols[0] + cols[1]) / 2, y - 12, cov["letter"])

        c.setFont("Helvetica", 6.4)
        for j, ln in enumerate(wrap(COVERAGE_LABELS[cov["type"]], 34)):
            c.drawString(cols[1] + 3, y - 10 - j * 7, ln)

        c.setFont("Helvetica-Bold", 8)
        c.drawCentredString((cols[2] + cols[3]) / 2, y - 12, "X" if cov.get("addl_insd") else "")
        c.drawCentredString((cols[3] + cols[4]) / 2, y - 12, "X" if cov.get("subr_wvd") else "")

        c.setFont("Helvetica", 6.6)
        c.drawString(cols[4] + 3, y - 12, cov["policy"])
        c.drawCentredString((cols[5] + cols[6]) / 2, y - 12, offset_to_date(base, cov.get("eff_offset")))
        c.drawCentredString((cols[6] + cols[7]) / 2, y - 12, offset_to_date(base, cov.get("exp_offset")))

        c.setFont("Helvetica", 5.8)
        for j, (lbl, val) in enumerate(limits):
            c.drawString(cols[7] + 3, y - 9 - j * 8, lbl)
            c.drawRightString(PAGE_W - M - 3, y - 9 - j * 8, money(val))

        y -= row_h

    # ── DESCRIPTION OF OPERATIONS ──
    desc_lines = wrap(spec.get("description", ""), 148)
    desc_h = max(34, 14 + 7 * len(desc_lines))
    box(c, M, y - desc_h, PAGE_W - 2 * M, desc_h,
        "DESCRIPTION OF OPERATIONS / LOCATIONS / VEHICLES")
    c.setFont("Helvetica", 6.4)
    for i, ln in enumerate(desc_lines):
        c.drawString(M + 4, y - 16 - i * 7, ln)
    y -= desc_h + 6

    # ── CERTIFICATE HOLDER | CANCELLATION ──
    holder = spec.get("holder", "")
    holder_addr = spec.get("holder_address", "")
    box(c, M, y - 62, half, 62, "CERTIFICATE HOLDER")
    text_block(c, M + 4, y - 18, [holder] + holder_addr.split("\n"))

    box(c, M + half, y - 62, half, 62, "CANCELLATION")
    c.setFont("Helvetica", 5.6)
    cancel = ("SHOULD ANY OF THE ABOVE DESCRIBED POLICIES BE CANCELLED BEFORE THE "
              "EXPIRATION DATE THEREOF, NOTICE WILL BE DELIVERED IN ACCORDANCE WITH "
              "THE POLICY PROVISIONS.")
    for i, ln in enumerate(wrap(cancel, 62)):
        c.drawString(M + half + 4, y - 16 - i * 7, ln)
    c.setFont("Helvetica", 6)
    c.drawString(M + half + 4, y - 52, "AUTHORIZED REPRESENTATIVE")
    c.setFont("Helvetica-Oblique", 8)
    c.drawString(M + half + 4, y - 42, spec["producer"]["contact"])

    watermark(c, spec.get("watermark", "SYNTHETIC TEST DOCUMENT"))


# ───────────────────────── post-processing ──────────────────────────

def rasterise(src: Path, dst: Path, dpi=150, rotate=1.5, quality=58):
    """Fixture 4: make a PDF that looks like a phone photo of a printout.

    Removes the text layer entirely, which is what forces the vision branch.
    Requires Poppler (`apt install poppler-utils` / `brew install poppler`).
    """
    from pdf2image import convert_from_path
    from PIL import Image, ImageEnhance

    pages = convert_from_path(str(src), dpi=dpi)
    processed = []
    for page in pages:
        img = page.convert("RGB")
        img = img.rotate(rotate, expand=True, fillcolor=(232, 230, 226))
        img = ImageEnhance.Contrast(img).enhance(0.88)
        img = ImageEnhance.Brightness(img).enhance(0.96)
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=quality)   # visible artefacting
        buf.seek(0)
        processed.append(Image.open(buf).convert("RGB"))

    c = rl_canvas.Canvas(str(dst), pagesize=letter)
    for img in processed:
        tmp = dst.with_suffix(".tmp.jpg")
        img.save(tmp, "JPEG", quality=quality)
        c.drawImage(str(tmp), 0, 0, width=PAGE_W, height=PAGE_H,
                    preserveAspectRatio=True, anchor="c")
        c.showPage()
        tmp.unlink(missing_ok=True)
    c.save()


def encrypt(src: Path, dst: Path, password="vendor2026"):
    """Fixture 18: password-protected PDF. Must dead-letter, not crash."""
    from pypdf import PdfReader, PdfWriter
    reader = PdfReader(str(src))
    writer = PdfWriter()
    for p in reader.pages:
        writer.add_page(p)
    writer.encrypt(user_password=password, owner_password=password + "-owner")
    with open(dst, "wb") as fh:
        writer.write(fh)


def write_portal_link_eml(dst: Path):
    """Fixture 19: an email with no attachment, only a download link.
    Larger agencies increasingly send these. The system must hand it to a
    human and must NOT attempt to fetch the link."""
    dst.write_text(
        "From: certs@brambleco.example\r\n"
        "To: coi@harbourline.example\r\n"
        "Subject: Certificate of Insurance - Whitlock Gutter & Drain\r\n"
        "MIME-Version: 1.0\r\n"
        "Content-Type: text/plain; charset=utf-8\r\n"
        "\r\n"
        "Hello,\r\n\r\n"
        "Your certificate for Whitlock Gutter & Drain is ready. Please download it "
        "from our secure portal:\r\n\r\n"
        "    https://portal.brambleco.example/d/8f42a1c9\r\n\r\n"
        "The link expires in 14 days.\r\n\r\n"
        "Bramble & Co Insurance\r\n",
        encoding="utf-8",
    )


# ───────────────────────── driver ──────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", default="spec/fixtures.json")
    ap.add_argument("--out",  default="out/")
    ap.add_argument("--only", help="Generate a single fixture id")
    ap.add_argument("--base-date", help="YYYY-MM-DD; defaults to today")
    args = ap.parse_args()

    spec_path = Path(args.spec)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    doc = json.loads(spec_path.read_text(encoding="utf-8"))
    defaults = doc["defaults"]
    base = date.fromisoformat(args.base_date) if args.base_date else date.today()

    manifest = []
    for fx in doc["fixtures"]:
        fid = fx["id"]
        if args.only and fid != args.only:
            continue

        merged = {**defaults, **fx}
        pdf = out_dir / f"{fid}.pdf"

        if fx.get("kind") == "portal_link_email":
            write_portal_link_eml(out_dir / f"{fid}.eml")
            manifest.append({"id": fid, "file": f"{fid}.eml", "kind": "eml"})
            print(f"  ✓ {fid}.eml")
            continue

        c = rl_canvas.Canvas(str(pdf), pagesize=letter)
        c.setTitle(f"Certificate of Liability Insurance — {merged['insured']['name']}")
        c.setAuthor("SYNTHETIC TEST DOCUMENT")
        c.setSubject("Synthetic fixture. Not a real certificate.")
        draw_certificate(c, merged, defaults, base)
        c.showPage()
        c.save()

        # Post-processing transforms
        post = fx.get("post")
        if post == "rasterise":
            tmp = out_dir / f"{fid}.src.pdf"
            shutil.move(str(pdf), str(tmp))
            rasterise(tmp, pdf)
            tmp.unlink(missing_ok=True)
        elif post == "encrypt":
            tmp = out_dir / f"{fid}.src.pdf"
            shutil.move(str(pdf), str(tmp))
            encrypt(tmp, pdf)
            tmp.unlink(missing_ok=True)

        manifest.append({
            "id": fid,
            "file": pdf.name,
            "vendor": merged["insured"]["name"],
            "base_date": base.isoformat(),
            "expect": fx.get("expect", {}),
            "resolved_dates": {
                cov["policy"]: {
                    "effective":  offset_to_date(base, cov.get("eff_offset")),
                    "expiration": offset_to_date(base, cov.get("exp_offset")),
                } for cov in merged.get("coverages", [])
            },
        })
        print(f"  ✓ {pdf.name}")

    (out_dir / "manifest.json").write_text(
        json.dumps({"generated_on": base.isoformat(), "fixtures": manifest}, indent=2),
        encoding="utf-8")
    print(f"\n{len(manifest)} fixtures written to {out_dir}/")
    print(f"manifest.json records the resolved dates — the test harness reads it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

---

## 3.5 The manifest is the contract

`fixtures/out/manifest.json` records, for each fixture, the **resolved** dates rather than the offsets. This matters more than it looks: the Stage 8 harness asserts that the extracted `expiration_date` equals the manifest's value. Without the manifest, the harness would have to re-derive dates from offsets and you would be testing your test.

```json
{
  "generated_on": "2026-07-29",
  "fixtures": [
    {
      "id": "f02-expiring-20d",
      "file": "f02-expiring-20d.pdf",
      "vendor": "Kessler Heating & Air Inc",
      "expect": { "status": "ON_FILE", "confidence": "HIGH", "bucket": "D30" },
      "resolved_dates": {
        "NGM-GL-5510882": { "effective": "08/18/2025", "expiration": "08/18/2026" }
      }
    }
  ]
}
```

---

## 3.6 Fixture 11 — the non-certificate

Fixture 11 is a W-9-style form, not a certificate. It matters because it is the honest answer to *"what if someone sends it junk?"*, and because you will hand the upload URL to the prospect and invite them to break it.

Add it to the spec with `"kind": "non_coi"` and give it its own tiny renderer:

```python
def draw_w9_like(c, base: date):
    """A tax-form-shaped document. Deliberately unlike a certificate:
    no coverage table, no policy dates, no insurer names."""
    c.setFont("Helvetica-Bold", 14)
    c.drawString(M, PAGE_H - 60, "Request for Taxpayer Identification Number")
    c.setFont("Helvetica", 9)
    rows = [
        "1  Name (as shown on your income tax return)",
        "     Fenwick Flooring",
        "2  Business name / disregarded entity name",
        "     Fenwick Flooring LLC",
        "3  Federal tax classification:   [X] LLC   [ ] Individual   [ ] C Corp",
        "5  Address:  601 Ashcombe Road",
        "6  City, state, ZIP:  Charlotte, NC 28211",
        "",
        "Part I   Taxpayer Identification Number (TIN)",
        "     Employer identification number:  XX-XXXXXXX",
        "",
        "Part II  Certification",
        "     Under penalties of perjury, I certify that the number shown",
        "     on this form is my correct taxpayer identification number.",
        "",
        "Signature: ____________________     Date: ____________",
    ]
    for i, r in enumerate(rows):
        c.drawString(M, PAGE_H - 92 - i * 15, r)
    watermark(c, "SYNTHETIC TEST DOCUMENT")
```

Wire it in `main()` with a `kind` check before the certificate renderer.

**Expected behaviour:** the model sets `is_certificate_of_insurance: false`, validation rule 7 fires `NOT_A_COI` as a hard reject, a `dead_letter` row is written, a manager notice goes out, and **zero vendor or certificate rows are created**. Showing a prospect the system decline to act is a trust-builder, not a weakness.

---

## 3.7 Generate and inspect

```bash
cd fixtures
source .venv/bin/activate      # or .venv\Scripts\activate on Windows
python generate.py --spec spec/fixtures.json --out out/
```

### Eyeball three of them before trusting the set

Open `f01`, `f04`, and `f08` in a PDF viewer:

| Fixture | Check |
|---|---|
| `f01` | Every field legible at 100%. Coverage table columns line up. Watermark visible but does not obscure dates. |
| `f04` | Looks like a photocopy. **Select-all in the viewer must select nothing** — if you can select text, the rasterise step did not remove the text layer and the vision branch will never be exercised. |
| `f08` | Four coverage rows, four different expiry dates, all readable. |

### Verify the text layer split

The intake workflow routes on extracted text length. Confirm the two branches will actually be hit:

```bash
python - <<'PY'
from pypdf import PdfReader
from pathlib import Path
for p in sorted(Path("out").glob("*.pdf")):
    try:
        n = len((PdfReader(str(p)).pages[0].extract_text() or "").strip())
        print(f"{p.name:34s} {n:6d} chars  →  {'text' if n > 200 else 'VISION'}")
    except Exception as e:
        print(f"{p.name:34s}  ERROR: {type(e).__name__}")
PY
```

Expected: every fixture over 200 characters except `f04-scanned.pdf` (near zero) and `f18-encrypted.pdf` (raises, which is the point).

> **The 200-character threshold is deliberate.** A PDF that is an image wrapped in a thin text layer — some scanners add a filename or a date stamp — would pass a `> 0` check and then extract garbage. 200 characters is comfortably below a real certificate (typically 1,500–2,500) and comfortably above a stray header. Do not lower it.

---

## Stage 3 exit checklist

- [ ] `make fixtures` regenerates the full set in one command
- [ ] `fixtures/out/manifest.json` exists with resolved dates for every fixture
- [ ] `f02` GL expiry is exactly **today + 20 days**
- [ ] `f03` GL expiry is exactly **today − 34 days**
- [ ] `f13` effective date is exactly **14 days after** `f03`'s expiry
- [ ] `f04` has **no selectable text**
- [ ] `f18` raises on open without a password
- [ ] `f19` exists as `.eml` with a link and no attachment
- [ ] Every PDF carries the SPECIMEN watermark
- [ ] No ACORD logo, form number, or copyright notice anywhere
- [ ] All carriers and domains are fictional (`.example`)

→ Continue to [Stage 4 — Extraction engine](05-stage-4-extraction-engine.md)
