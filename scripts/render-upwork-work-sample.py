"""Build the contact-free, two-page COI automation work sample PDF.

Run capture-upwork-work-sample.cjs first. The dashboard screenshot comes from
the real dashboard renderer with illustrative synthetic rows. The two n8n
screenshots are direct editor captures saved under tmp/pdfs/ for this sample.
"""

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "output" / "pdf" / "vendor-coi-automation-work-sample.pdf"
DASHBOARD = ROOT / "tmp" / "pdfs" / "upwork-dashboard.png"
SPECIMEN = ROOT / "tmp" / "pdfs" / "upwork-specimen.png"
DAILY_WATCH = ROOT / "tmp" / "pdfs" / "upwork-n8n-daily-watch.png"
APPROVAL = ROOT / "tmp" / "pdfs" / "upwork-n8n-approval.png"
FONT_DIR = ROOT / "concept-brief" / "assets" / "fonts"

PAGE_W, PAGE_H = 792, 612  # US Letter landscape
INK = colors.HexColor("#14233A")
MUTED = colors.HexColor("#5A6878")
PAPER = colors.HexColor("#F8F7F3")
LINE = colors.HexColor("#D9DFE4")
ACCENT = colors.HexColor("#0D7754")


def fonts():
    pdfmetrics.registerFont(TTFont("Geist", str(FONT_DIR / "geist-variable.ttf")))
    pdfmetrics.registerFont(TTFont("Manrope", str(FONT_DIR / "manrope-variable.ttf")))


def label(c, x, y, value, color=MUTED):
    c.setFillColor(color)
    c.setFont("Manrope", 8.2)
    c.drawString(x, y, value.upper())


def line(c, y):
    c.setStrokeColor(LINE)
    c.setLineWidth(0.8)
    c.line(42, y, PAGE_W - 42, y)


def draw_fit(c, image_path, x, y, w, h):
    image = ImageReader(str(image_path))
    iw, ih = image.getSize()
    scale = min(w / iw, h / ih)
    dw, dh = iw * scale, ih * scale
    c.drawImage(image, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh)


def page_base(c, page_number):
    c.setFillColor(PAPER)
    c.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    c.setFillColor(ACCENT)
    c.rect(42, PAGE_H - 30, 27, 3, fill=1, stroke=0)
    line(c, 38)
    c.setFillColor(MUTED)
    c.setFont("Manrope", 7.3)
    c.drawString(42, 23, "SYNTHETIC LOCAL DEMO  /  NO CLIENT DATA")
    c.drawRightString(PAGE_W - 42, 23, f"{page_number} / 2")


def page_one(c):
    page_base(c, 1)
    label(c, 42, 562, "Automation work sample  /  property management")
    c.setFillColor(INK)
    c.setFont("Geist", 23)
    c.drawString(42, 528, "Vendor COI chasing")
    c.setFont("Manrope", 10.2)
    c.setFillColor(MUTED)
    c.drawString(42, 507, "n8n workflows and Postgres state turn incoming certificates into a visible register and controlled follow-up.")

    c.setFillColor(colors.white)
    c.roundRect(42, 72, 708, 420, 8, fill=1, stroke=0)
    c.setStrokeColor(LINE)
    c.roundRect(42, 72, 708, 420, 8, fill=0, stroke=1)
    draw_fit(c, DASHBOARD, 47, 76, 698, 412)
    label(c, 42, 55, "Screen 01  /  vendor register rendered by the project workflow")
    c.setFillColor(MUTED)
    c.setFont("Manrope", 7.5)
    c.drawRightString(PAGE_W - 42, 55, "Illustrative synthetic rows")
    c.showPage()


def crop_specimen(c, x, y, w, h):
    """Show the coverage section without the test document's email field."""
    img = ImageReader(str(SPECIMEN))
    iw, ih = img.getSize()
    # Original source is 1105 x 1430. This viewport covers its coverage table
    # and notes, omitting the header fields containing a synthetic email address.
    source_top, source_bottom = 367, 730
    crop_h = source_bottom - source_top
    scale = min(w / iw, h / crop_h)
    dw, dh = iw * scale, crop_h * scale
    dx = x + (w - dw) / 2
    dy = y + (h - dh) / 2
    c.saveState()
    p = c.beginPath()
    p.rect(dx, dy, dw, dh)
    c.clipPath(p, stroke=0, fill=0)
    c.drawImage(img, dx, dy - (ih - source_bottom) * scale, iw * scale, ih * scale)
    c.restoreState()


def step(c, x, number, title, body1, body2):
    c.setFillColor(ACCENT)
    c.circle(x + 10, 155, 10, fill=1, stroke=0)
    c.setFillColor(colors.white)
    c.setFont("Geist", 9)
    c.drawCentredString(x + 10, 152, str(number))
    c.setFillColor(INK)
    c.setFont("Geist", 10.2)
    c.drawString(x + 26, 151, title)
    c.setFillColor(MUTED)
    c.setFont("Manrope", 8.0)
    c.drawString(x, 131, body1)
    c.drawString(x, 118, body2)


def crop_capture(c, image_path, crop, x, y, w, h):
    """Frame a captured n8n canvas band without changing the screenshot."""
    img = ImageReader(str(image_path))
    iw, ih = img.getSize()
    sx, sy, sw, sh = crop  # source coordinates from the top left
    scale = min(w / sw, h / sh)
    dw, dh = sw * scale, sh * scale
    dx = x + (w - dw) / 2
    dy = y + (h - dh) / 2
    c.saveState()
    p = c.beginPath()
    p.rect(dx, dy, dw, dh)
    c.clipPath(p, stroke=0, fill=0)
    c.drawImage(img, dx - sx * scale, dy - (ih - sy - sh) * scale, iw * scale, ih * scale)
    c.restoreState()


def page_two(c):
    page_base(c, 2)
    label(c, 42, 562, "Screens 02-03  /  actual n8n editor captures")
    c.setFillColor(INK)
    c.setFont("Geist", 22)
    c.drawString(42, 528, "Two workflows. One human release gate.")
    c.setFillColor(MUTED)
    c.setFont("Manrope", 10)
    c.drawString(42, 508, "Direct screenshots from the local n8n editor. Every node in each captured workflow is visible.")

    c.setFillColor(colors.white)
    c.roundRect(42, 307, 708, 185, 8, fill=1, stroke=0)
    c.setStrokeColor(LINE)
    c.roundRect(42, 307, 708, 185, 8, fill=0, stroke=1)
    crop_capture(c, DAILY_WATCH, (170, 500, 1930, 380), 49, 313, 694, 173)
    label(c, 42, 290, "Daily Watch and Chase  /  9 nodes  /  schedules, drafts and records pending outreach")

    c.setFillColor(colors.white)
    c.roundRect(42, 65, 708, 210, 8, fill=1, stroke=0)
    c.setStrokeColor(LINE)
    c.roundRect(42, 65, 708, 210, 8, fill=0, stroke=1)
    crop_capture(c, APPROVAL, (180, 420, 1930, 520), 49, 71, 694, 198)
    label(c, 42, 48, "Vendor Approval Request  /  12 nodes  /  one separate wait and send decision per vendor")
    c.showPage()


def page_three(c):
    page_base(c, 3)
    label(c, 42, 562, "Screen 04  /  source document detail")
    c.setFillColor(INK)
    c.setFont("Geist", 22)
    c.drawString(42, 528, "The document stays one click away")
    c.setFillColor(MUTED)
    c.setFont("Manrope", 10)
    c.drawString(42, 508, "The original PDF is saved before extraction. The register shows date facts and notes, with a link back to the source.")

    c.setFillColor(colors.white)
    c.roundRect(42, 208, 708, 286, 8, fill=1, stroke=0)
    c.setStrokeColor(LINE)
    c.roundRect(42, 208, 708, 286, 8, fill=0, stroke=1)
    crop_specimen(c, 53, 223, 686, 256)
    label(c, 42, 190, "Synthetic certificate fixture  /  coverage table and document notes")

    step(c, 42, 1, "Receive", "Gmail attachment or", "upload form")
    step(c, 218, 2, "Read", "Text first; PDF visual", "path for scans")
    step(c, 394, 3, "Check", "Fixed date, holder and", "limit rules")
    step(c, 570, 4, "Chase", "Draft waits for a", "manager's click")

    line(c, 102)
    c.setFillColor(INK)
    c.setFont("Geist", 9.5)
    c.drawString(42, 84, "Local verification")
    c.setFillColor(MUTED)
    c.setFont("Manrope", 8.2)
    c.drawString(42, 68, "18 seeded vendors. The Stage 8 fixture suite passed for scans, renewals, missing lines, locked files and two-PDF intake.")
    c.drawString(42, 55, "A two-vendor test produced separate approval waits and sends. This demo does not determine actual policy status.")
    c.showPage()


def main():
    for path in (DASHBOARD, DAILY_WATCH, APPROVAL):
        if not path.exists():
            raise FileNotFoundError(f"Required screenshot missing: {path}")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    fonts()
    c = canvas.Canvas(str(OUTPUT), pagesize=(PAGE_W, PAGE_H), pageCompression=1)
    c.setTitle("Vendor COI Chasing - Automation Work Sample")
    c.setAuthor("Automation work sample")
    c.setSubject("Synthetic local demo of an n8n vendor COI automation")
    page_one(c)
    page_two(c)
    c.save()
    print(OUTPUT)


if __name__ == "__main__":
    main()
