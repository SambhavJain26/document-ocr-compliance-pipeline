"""Render a contact-free, legible nine-page COI automation work sample."""

from pathlib import Path
from PIL import Image
from fontTools.ttLib import TTFont as FontToolsTTFont
from fontTools.varLib.instancer import instantiateVariableFont
from reportlab.lib import colors
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "docs" / "work-sample-assets"
OUTPUT = ROOT / "output" / "pdf" / "vendor-coi-automation-work-sample.pdf"
FONTS = ROOT / "concept-brief" / "assets" / "fonts"
W, H = 792, 612
INK = colors.HexColor("#101D2B")
MUTED = colors.HexColor("#2C3B49")
PAPER = colors.HexColor("#FFFFFF")
LINE = colors.HexColor("#B8C8C2")
GREEN = colors.HexColor("#075B42")
PALE = colors.HexColor("#E9F2ED")


def fonts():
    static_dir = ROOT / "tmp" / "pdfs" / "work-sample-fonts"
    static_dir.mkdir(parents=True, exist_ok=True)
    for source, name, weight in (
        ("geist-variable.ttf", "Geist", 650),
        ("manrope-variable.ttf", "Manrope", 550),
        ("manrope-variable.ttf", "ManropeBold", 700),
    ):
        target = static_dir / f"{name}-{weight}.ttf"
        if not target.exists():
            variable = FontToolsTTFont(FONTS / source)
            instantiateVariableFont(variable, {"wght": weight}, inplace=True).save(target)
        pdfmetrics.registerFont(TTFont(name, str(target)))


def text(c, x, y, value, size=10, color=INK, font="Manrope"):
    c.setFont(font, size)
    c.setFillColor(color)
    c.drawString(x, y, value)


def wrap(c, x, y, value, max_width, size=10.5, leading=15, color=INK, font="Manrope"):
    row = ""
    for word in value.split():
        trial = f"{row} {word}".strip()
        if row and pdfmetrics.stringWidth(trial, font, size) > max_width:
            text(c, x, y, row, size, color, font)
            y -= leading
            row = word
        else:
            row = trial
    if row:
        text(c, x, y, row, size, color, font)
        y -= leading
    return y


def base(c, number, section, title, subtitle=None):
    c.setFillColor(PAPER)
    c.rect(0, 0, W, H, fill=1, stroke=0)
    c.setFillColor(GREEN)
    c.rect(42, 582, 29, 3, fill=1, stroke=0)
    text(c, 42, 558, section.upper(), 9.5, GREEN, "ManropeBold")
    text(c, 42, 527, title, 23.5, INK, "Geist")
    if subtitle:
        wrap(c, 42, 503, subtitle, 708, 10.6, 15, MUTED)
    c.setStrokeColor(LINE)
    c.line(42, 39, 750, 39)
    text(c, 42, 24, "LOCAL DEMO  /  SYNTHETIC DATA  /  WORK SAMPLE", 8.4, MUTED)
    c.setFont("Manrope", 8.4)
    c.setFillColor(MUTED)
    c.drawRightString(750, 24, f"{number} / 9")


def screenshot(c, name, x, y, width, height, crop=None):
    image = Image.open(ASSETS / name).convert("RGB")
    if crop:
        image = image.crop(crop)
    iw, ih = image.size
    scale = min(width / iw, height / ih)
    dw, dh = iw * scale, ih * scale
    bx = x + (width - dw) / 2
    by = y + (height - dh) / 2
    c.setFillColor(colors.white)
    c.roundRect(x, y, width, height, 6, fill=1, stroke=0)
    c.drawImage(ImageReader(image), bx, by, dw, dh)
    c.setStrokeColor(LINE)
    c.roundRect(x, y, width, height, 6, fill=0, stroke=1)


def callout(c, x, y, width, title, body, height=73):
    c.setFillColor(PALE)
    c.roundRect(x, y, width, height, 7, fill=1, stroke=0)
    text(c, x + 13, y + height - 23, title, 11, GREEN, "Geist")
    wrap(c, x + 13, y + height - 43, body, width - 26, 10, 14, INK)


def bullet(c, y, value):
    c.setFillColor(GREEN)
    c.circle(49, y + 3, 3, fill=1, stroke=0)
    return wrap(c, 62, y, value, 675, 10.2, 15) - 9


def page_1(c):
    base(c, 1, "Automation case study", "Vendor COI chasing",
         "Six n8n workflows connect certificate intake, validation, a vendor register, renewal chasing and human approval.")
    screenshot(c, "dashboard-illustrative.png", 42, 96, 708, 391)
    text(c, 42, 77, "REGISTER OUTPUT  /  rendered by the project dashboard workflow", 9.2, GREEN)
    c.setFont("Manrope", 9.2)
    c.setFillColor(MUTED)
    c.drawRightString(750, 77, "Illustrative synthetic rows")
    c.showPage()


def page_2(c):
    base(c, 2, "System design", "One connected automation",
         "n8n handles orchestration. Postgres stores vendors, certificates, coverage, notices and outreach state. Original PDFs stay linked to the register.")
    rows = [
        ("01", "COI Intake", "Gmail, upload form or fixture -> PDF storage, extraction and validation"),
        ("02", "Source Document Route", "Serves the stored original PDF behind a certificate link"),
        ("03", "Daily Watch and Chase", "Selects due vendors, drafts requests and records pending outreach"),
        ("04", "Vendor Approval Request", "One execution per vendor; sends only after a human approves"),
        ("05", "Non-PDF Reply Notice", "Captures replies that require manual attention rather than PDF processing"),
        ("06", "COI Dashboard", "Reads Postgres and renders a vendor status register"),
    ]
    y = 464
    for num, name, desc in rows:
        c.setFillColor(colors.white)
        c.roundRect(42, y - 40, 708, 50, 5, fill=1, stroke=0)
        text(c, 55, y - 11, num, 10, GREEN, "Geist")
        text(c, 91, y - 11, name, 11.3, INK, "Geist")
        text(c, 91, y - 28, desc, 9.4, MUTED)
        y -= 57
    callout(c, 42, 64, 708, "Design boundary",
            "This is a local demonstration built with synthetic vendors and certificates. It has not been deployed for a client or certified for production use.", 70)
    c.showPage()


def page_3(c):
    base(c, 3, "Workflow 01 / COI Intake", "Three entry paths, one intake pipeline",
         "Direct n8n editor capture. All 35 functional nodes are visible in this overview; the next two pages enlarge the stages for reading.")
    screenshot(c, "work-sample-intake-overview.png", 42, 267, 708, 217, (160, 425, 2260, 835))
    text(c, 42, 242, "What it does", 11.2, INK, "Geist")
    y = 218
    for item in (
        "Accepts a Gmail PDF attachment, browser upload, or controlled manual fixture run.",
        "Normalizes the source, stores the original PDF, and keeps a source reference.",
        "Extracts certificate facts, runs deterministic checks, then persists the result in Postgres.",
    ):
        y = bullet(c, y, item)
    callout(c, 42, 65, 708, "Why the flow is split",
            "The same validation path follows each source. This keeps upload and email behavior aligned and makes fixture checks repeatable.", 62)
    c.showPage()


def page_4(c):
    base(c, 4, "Workflow 01 / COI Intake", "Sources and original-file handling",
         "Enlarged views of the same canvas. These are direct n8n screenshots, cropped for legibility.")
    text(c, 42, 474, "A  /  SOURCE BRANCHES", 9.5, GREEN)
    screenshot(c, "work-sample-intake-overview.png", 42, 287, 708, 176, (175, 500, 1010, 900))
    text(c, 42, 264, "B  /  PDF STORAGE AND EXTRACTION BRANCH", 9.5, GREEN)
    screenshot(c, "work-sample-intake-overview.png", 42, 82, 708, 171, (795, 500, 1710, 875))
    text(c, 42, 62, "The original is saved before parsing; a low-text PDF can take the visual extraction path.", 9.6, MUTED)
    c.showPage()


def page_5(c):
    base(c, 5, "Workflow 01 / COI Intake", "Structured facts, fixed rules",
         "The model transcribes document facts into a schema. Project code then applies repeatable flags and storage decisions.")
    screenshot(c, "work-sample-intake-overview.png", 42, 249, 708, 231, (1480, 445, 2260, 785))
    text(c, 42, 226, "Examples of checks", 11.2, INK, "Geist")
    y = 204
    for item in (
        "Wrong holder or coverage below the minimum is flagged for review.",
        "A non-certificate attachment creates a notice without filing a certificate.",
        "Renewal history can supersede an older record and surface a coverage gap.",
    ):
        y = bullet(c, y, item)
    callout(c, 42, 62, 708, "Human interpretation remains required",
            "A filed certificate and an automation flag are operational records; they are not a legal determination that coverage is adequate.", 60)
    c.showPage()


def page_6(c):
    base(c, 6, "Workflows 03 + 04 / Follow-up", "Daily watch with a human send gate",
         "The watch selects actionable vendors. Each approval request then runs separately so every vendor gets an independent pause and decision.")
    text(c, 42, 477, "DAILY WATCH AND CHASE  /  9 functional nodes", 9.5, GREEN)
    screenshot(c, "work-sample-daily-watch.png", 42, 300, 708, 166, (170, 480, 2250, 890))
    text(c, 42, 278, "VENDOR APPROVAL REQUEST  /  12 functional nodes", 9.5, GREEN)
    screenshot(c, "work-sample-approval.png", 42, 106, 708, 160, (185, 330, 2250, 1010))
    wrap(c, 42, 88,
         "Postgres suppression and escalation rules govern who is due. Gmail approval decides whether each prepared message is sent or declined; the decision is logged.",
         708, 9.9, 14, MUTED)
    c.showPage()


def page_7(c):
    base(c, 7, "Workflows 02 + 05 / Exceptions", "Source access and reply capture",
         "Small workflows handle two practical edge cases without making the intake canvas harder to follow.")
    text(c, 42, 474, "SOURCE DOCUMENT ROUTE  /  6 functional nodes", 9.5, GREEN)
    screenshot(c, "work-sample-source-route.png", 42, 301, 708, 161, (500, 490, 1920, 910))
    wrap(c, 42, 287,
         "A dashboard link looks up the certificate's stored file and returns the original PDF or a not-found response.",
         708, 9.8, 14, MUTED)
    text(c, 42, 247, "NON-PDF REPLY NOTICE  /  3 functional nodes", 9.5, GREEN)
    screenshot(c, "work-sample-non-pdf-reply.png", 42, 82, 708, 153, (790, 585, 1660, 840))
    wrap(c, 42, 68,
         "Replies without a PDF become notices for a manager; portal links are not fetched automatically.",
         708, 9.8, 14, MUTED)
    c.showPage()


def page_8(c):
    base(c, 8, "Workflow 06 / COI Dashboard", "A register backed by workflow state",
         "The webhook reads the Postgres view and renders an HTML board with vendor status, review flags and source-document links.")
    text(c, 42, 474, "DASHBOARD WORKFLOW  /  5 functional nodes", 9.5, GREEN)
    screenshot(c, "work-sample-dashboard-workflow.png", 42, 321, 708, 142, (650, 510, 1850, 910))
    text(c, 42, 301, "RENDERED REGISTER  /  illustrative synthetic rows", 9.5, GREEN)
    screenshot(c, "dashboard-illustrative.png", 42, 76, 708, 213)
    text(c, 42, 58, "The source-document links were exercised in the Stage 8 fixture verification.", 9.5, MUTED)
    c.showPage()


def page_9(c):
    base(c, 9, "Evidence and scope", "Tested with synthetic scenarios",
         "The repository's repeatable Stage 8 verifier passed its fixture suite and dashboard checks on the local stack.")
    scenarios = [
        ("Intake", "Valid, expired, scanned, password-protected and non-certificate PDFs"),
        ("Validation", "Wrong holder, low limits, missing GL, inverted dates and duplicate vendor"),
        ("History", "Two attachments, renewal supersession and a 14-day coverage gap"),
        ("Dashboard", "18 seeded vendors, source links, gap count and status views"),
        ("Approval", "Separate per-vendor waits, sends and decline logging verified in a later live test"),
    ]
    y = 469
    for name, detail in scenarios:
        c.setFillColor(colors.white)
        c.roundRect(42, y - 42, 708, 49, 5, fill=1, stroke=0)
        text(c, 55, y - 11, name, 10.5, GREEN, "Geist")
        wrap(c, 172, y - 11, detail, 560, 9.8, 14, INK)
        y -= 57
    callout(c, 42, 89, 708, "Scope of this sample",
            "Local demo with synthetic documents and a test mailbox. Client hosting, access controls, alerts, retries, backups, data retention and operating terms still need implementation and testing for production use.", 83)
    text(c, 42, 66, "Evidence: docs/stage-8-fixture-results.md and workflow exports in the project repository.", 9.3, MUTED)
    c.showPage()


def main():
    fonts()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUTPUT), pagesize=(W, H))
    c.setTitle("Vendor COI Chasing | Automation Work Sample")
    c.setAuthor("Automation Work Sample")
    c.setSubject("Local n8n automation case study using synthetic data")
    for page in (page_1, page_2, page_3, page_4, page_5, page_6, page_7, page_8, page_9):
        page(c)
    c.save()
    print(OUTPUT)


if __name__ == "__main__":
    main()
