import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageEnhance
from pypdf import PdfReader, PdfWriter
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas


PAGE_WIDTH, PAGE_HEIGHT = letter
WATERMARK = "SPECIMEN - SYNTHETIC TEST DOCUMENT"
FORBIDDEN = ["ACORD", "compliant", "verified", "approved"]


def money(value):
    if value is None:
        return ""
    return "${:,.0f}".format(value)


def date_us(value):
    if not value:
        return ""
    y, m, d = value.split("-")
    return f"{m}/{d}/{y}"


def ensure_clean_dir(path):
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def draw_watermark(c):
    c.saveState()
    c.setFont("Helvetica-Bold", 30)
    c.setFillColor(colors.Color(0.72, 0.72, 0.72, alpha=0.28))
    c.translate(PAGE_WIDTH / 2, PAGE_HEIGHT / 2)
    c.rotate(32)
    c.drawCentredString(0, 0, WATERMARK)
    c.restoreState()


def draw_label_value(c, label, value, x, y, width, height=0.35 * inch):
    c.setStrokeColor(colors.HexColor("#9ca3af"))
    c.setFillColor(colors.HexColor("#f8fafc"))
    c.rect(x, y - height, width, height, stroke=1, fill=1)
    c.setFillColor(colors.HexColor("#334155"))
    c.setFont("Helvetica-Bold", 6.5)
    c.drawString(x + 5, y - 10, label.upper())
    c.setFillColor(colors.black)
    c.setFont("Helvetica", 8.5)
    c.drawString(x + 5, y - 23, str(value or ""))


def draw_wrapped(c, text, x, y, width, leading=10, font="Helvetica", size=8):
    c.setFont(font, size)
    words = str(text or "").split()
    lines = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if c.stringWidth(candidate, font, size) <= width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    for line in lines:
        c.drawString(x, y, line)
        y -= leading
    return y


def draw_certificate_pdf(fixture, output_path):
    c = canvas.Canvas(str(output_path), pagesize=letter, invariant=1)
    draw_watermark(c)

    margin = 0.45 * inch
    top = PAGE_HEIGHT - margin

    c.setFillColor(colors.HexColor("#0f172a"))
    c.rect(0, PAGE_HEIGHT - 0.75 * inch, PAGE_WIDTH, 0.75 * inch, stroke=0, fill=1)
    c.setFillColor(colors.white)
    c.setFont("Helvetica-Bold", 16)
    c.drawString(margin, PAGE_HEIGHT - 0.42 * inch, "Vendor Insurance Summary")
    c.setFont("Helvetica", 8)
    c.drawRightString(PAGE_WIDTH - margin, PAGE_HEIGHT - 0.30 * inch, "Synthetic certificate-like test document")
    c.drawRightString(PAGE_WIDTH - margin, PAGE_HEIGHT - 0.48 * inch, f"Fixture {fixture['number']:02d}: {fixture['title']}")

    y = top - 0.95 * inch
    col = (PAGE_WIDTH - 2 * margin - 0.18 * inch) / 2
    draw_label_value(c, "Producer", fixture.get("producer"), margin, y, col)
    draw_label_value(c, "Producer email", fixture.get("producer_email"), margin + col + 0.18 * inch, y, col)
    y -= 0.45 * inch
    draw_label_value(c, "Insured vendor", fixture.get("vendor"), margin, y, col)
    draw_label_value(c, "Trade", fixture.get("trade"), margin + col + 0.18 * inch, y, col)
    y -= 0.45 * inch
    draw_label_value(c, "Certificate date", date_us(fixture.get("certificate_date")), margin, y, col)
    draw_label_value(c, "Certificate holder", fixture.get("holder"), margin + col + 0.18 * inch, y, col)

    y -= 0.65 * inch
    c.setFillColor(colors.HexColor("#1f2937"))
    c.setFont("Helvetica-Bold", 10)
    c.drawString(margin, y, "Coverage lines")
    y -= 0.18 * inch

    columns = [
        ("Type", 0.95 * inch),
        ("Carrier", 1.05 * inch),
        ("Policy #", 0.95 * inch),
        ("Eff", 0.75 * inch),
        ("Exp", 0.75 * inch),
        ("Each", 0.72 * inch),
        ("Agg", 0.72 * inch),
        ("AI", 0.27 * inch),
        ("SW", 0.27 * inch),
    ]
    x = margin
    c.setFillColor(colors.HexColor("#e2e8f0"))
    c.rect(margin, y - 0.22 * inch, PAGE_WIDTH - 2 * margin, 0.22 * inch, stroke=0, fill=1)
    c.setFillColor(colors.HexColor("#111827"))
    c.setFont("Helvetica-Bold", 7)
    for header, width in columns:
        c.drawString(x + 2, y - 0.14 * inch, header)
        x += width
    y -= 0.22 * inch

    c.setFont("Helvetica", 7.4)
    for idx, cov in enumerate(fixture.get("coverages", [])):
        row_h = 0.30 * inch
        c.setFillColor(colors.white if idx % 2 == 0 else colors.HexColor("#f8fafc"))
        c.rect(margin, y - row_h, PAGE_WIDTH - 2 * margin, row_h, stroke=0, fill=1)
        c.setStrokeColor(colors.HexColor("#cbd5e1"))
        c.line(margin, y - row_h, PAGE_WIDTH - margin, y - row_h)
        x = margin
        values = [
            cov.get("type", ""),
            cov.get("carrier", ""),
            cov.get("policy", ""),
            date_us(cov.get("effective")),
            date_us(cov.get("expiration")),
            money(cov.get("each_occurrence")),
            money(cov.get("general_aggregate")),
            "Y" if cov.get("addl_insd_asserted") else "N",
            "Y" if cov.get("subr_wvd_asserted") else "N",
        ]
        for value, (_, width) in zip(values, columns):
            c.setFillColor(colors.black)
            c.drawString(x + 2, y - 0.17 * inch, value[:22])
            x += width
        y -= row_h

    y -= 0.28 * inch
    c.setFillColor(colors.HexColor("#1f2937"))
    c.setFont("Helvetica-Bold", 9)
    c.drawString(margin, y, "Description of operations / notes")
    y -= 0.18 * inch
    c.setFillColor(colors.black)
    y = draw_wrapped(c, fixture.get("description", ""), margin, y, PAGE_WIDTH - 2 * margin, leading=10, size=8)

    y -= 0.25 * inch
    c.setFont("Helvetica", 7)
    c.setFillColor(colors.HexColor("#475569"))
    c.drawString(margin, y, "This synthetic document is for automation testing only. It is not issued by an insurer, agent, or broker.")
    c.drawString(margin, y - 0.14 * inch, "Checkbox fields record assertions printed on a document; they are not independent proof of policy terms.")

    c.showPage()
    c.save()


def draw_non_certificate_pdf(fixture, output_path):
    c = canvas.Canvas(str(output_path), pagesize=letter, invariant=1)
    draw_watermark(c)
    margin = 0.7 * inch
    y = PAGE_HEIGHT - margin
    c.setFont("Helvetica-Bold", 18)
    c.drawString(margin, y, "Vendor Tax Information Request")
    y -= 0.35 * inch
    c.setFont("Helvetica", 10)
    c.drawString(margin, y, "Synthetic non-certificate fixture for rejection testing.")
    y -= 0.45 * inch
    fields = [
        ("Vendor name", fixture.get("vendor")),
        ("Tax classification", "Limited liability company"),
        ("Mailing address", "100 Example Way, Charlotte, NC 28202"),
        ("Requester", "Harbourline Property Management LLC"),
    ]
    for label, value in fields:
        draw_label_value(c, label, value, margin, y, PAGE_WIDTH - 2 * margin)
        y -= 0.5 * inch
    c.setFont("Helvetica", 8)
    c.drawString(margin, y, "This document intentionally contains no policy numbers, carriers, limits, or expiration dates.")
    c.showPage()
    c.save()


def encrypt_pdf(input_path, output_path, password):
    reader = PdfReader(str(input_path))
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    writer.encrypt(password)
    with output_path.open("wb") as stream:
        writer.write(stream)


def make_scanned_pdf(base_pdf, output_path, work_dir):
    pdftoppm = shutil.which("pdftoppm")
    env_pdftoppm = os.environ.get("PDFTOPPM")
    if env_pdftoppm:
        pdftoppm = env_pdftoppm
    if not pdftoppm:
        raise RuntimeError("pdftoppm not found on PATH")

    prefix = work_dir / "scan-source"
    subprocess.run([pdftoppm, "-r", "220", "-png", str(base_pdf), str(prefix)], check=True)
    source_image = work_dir / "scan-source-1.png"
    image = Image.open(source_image).convert("RGB")
    image = ImageEnhance.Contrast(image).enhance(1.05)
    image = ImageEnhance.Brightness(image).enhance(0.98)
    image = image.rotate(0.35, expand=True, fillcolor=(246, 246, 242))
    jpeg_path = work_dir / "scan-image.jpg"
    image.save(jpeg_path, "JPEG", quality=88)

    c = canvas.Canvas(str(output_path), pagesize=letter, invariant=1)
    c.setFillColor(colors.HexColor("#e7e5df"))
    c.rect(0, 0, PAGE_WIDTH, PAGE_HEIGHT, stroke=0, fill=1)
    c.drawImage(str(jpeg_path), 0.25 * inch, 0.25 * inch, width=PAGE_WIDTH - 0.5 * inch, height=PAGE_HEIGHT - 0.5 * inch, preserveAspectRatio=True, anchor="c")
    c.showPage()
    c.save()


def create_email_payload(fixture, pdf_dir, email_dir):
    attachments = []
    for attachment_id in fixture.get("attachments", []):
        attachments.append({
            "fixture_id": attachment_id,
            "filename": f"{attachment_id}.pdf",
            "path": f"../pdfs/{attachment_id}.pdf"
        })
    payload = {
        "fixture_id": fixture["id"],
        "subject": f"Fixture {fixture['number']:02d}: {fixture['title']}",
        "from": "producer@example.test",
        "to": "demo+intake@example.test",
        "body": fixture.get("body", "Attached are the requested synthetic certificate documents for local automation testing."),
        "attachments": attachments,
        "expected": fixture["expected"],
    }
    path = email_dir / f"{fixture['id']}.json"
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return path


def validate_spec_text(spec):
    raw = json.dumps(spec)
    upper = raw.upper()
    for forbidden in FORBIDDEN:
        if forbidden.upper() in upper:
            raise ValueError(f"Forbidden term in fixture spec: {forbidden}")


def main():
    repo_root = Path(__file__).resolve().parents[1]
    spec_path = repo_root / "fixtures" / "spec" / "stage-3-fixtures.json"
    pdf_dir = repo_root / "fixtures" / "pdfs"
    email_dir = repo_root / "fixtures" / "emails"
    expected_dir = repo_root / "fixtures" / "expected"
    work_dir = repo_root / "tmp" / "stage-3-generation"

    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    validate_spec_text(spec)

    ensure_clean_dir(pdf_dir)
    ensure_clean_dir(email_dir)
    ensure_clean_dir(expected_dir)
    ensure_clean_dir(work_dir)

    expected = {
        "generated_at": spec["fixture_date"],
        "watermark": spec["watermark"],
        "fixtures": []
    }
    generated_pdf_by_id = {}

    for fixture in spec["fixtures"]:
        fixture_id = fixture["id"]
        fixture_type = fixture["type"]
        record = {
            "id": fixture_id,
            "number": fixture["number"],
            "title": fixture["title"],
            "type": fixture_type,
            "expected": fixture["expected"],
            "artifacts": []
        }

        if fixture_type == "certificate":
            out = pdf_dir / f"{fixture_id}.pdf"
            draw_certificate_pdf(fixture, out)
            generated_pdf_by_id[fixture_id] = out
            record["artifacts"].append(f"../pdfs/{out.name}")
        elif fixture_type == "password_certificate":
            plain = work_dir / f"{fixture_id}-plain.pdf"
            out = pdf_dir / f"{fixture_id}.pdf"
            draw_certificate_pdf(fixture, plain)
            encrypt_pdf(plain, out, fixture["password"])
            generated_pdf_by_id[fixture_id] = out
            record["password"] = fixture["password"]
            record["artifacts"].append(f"../pdfs/{out.name}")
        elif fixture_type == "scanned_certificate":
            base = generated_pdf_by_id.get(fixture["base_fixture"])
            if not base:
                raise ValueError(f"Base fixture must be generated before scanned fixture: {fixture['base_fixture']}")
            out = pdf_dir / f"{fixture_id}.pdf"
            make_scanned_pdf(base, out, work_dir)
            generated_pdf_by_id[fixture_id] = out
            record["base_fixture"] = fixture["base_fixture"]
            record["artifacts"].append(f"../pdfs/{out.name}")
        elif fixture_type == "non_certificate_pdf":
            out = pdf_dir / f"{fixture_id}.pdf"
            draw_non_certificate_pdf(fixture, out)
            generated_pdf_by_id[fixture_id] = out
            record["artifacts"].append(f"../pdfs/{out.name}")
        elif fixture_type == "email":
            out = create_email_payload(fixture, pdf_dir, email_dir)
            record["artifacts"].append(f"../emails/{out.name}")
        elif fixture_type == "metadata_only":
            record["vendors"] = fixture["vendors"]
        else:
            raise ValueError(f"Unknown fixture type: {fixture_type}")

        expected["fixtures"].append(record)

    expected_path = expected_dir / "stage-3-expected.json"
    expected_path.write_text(json.dumps(expected, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(expected['fixtures'])} fixture records.")
    print(f"PDFs: {len(list(pdf_dir.glob('*.pdf')))}")
    print(f"Email payloads: {len(list(email_dir.glob('*.json')))}")
    print(f"Expected metadata: {expected_path}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Fixture generation failed: {exc}", file=sys.stderr)
        raise
