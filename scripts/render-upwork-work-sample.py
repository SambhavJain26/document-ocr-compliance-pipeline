"""Shared design helpers and entry point for the evidence work sample."""

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
FONTS = ROOT / "docs" / "work-sample-assets" / "fonts"
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


def callout(c, x, y, width, title, body, height=73):
    c.setFillColor(PALE)
    c.roundRect(x, y, width, height, 7, fill=1, stroke=0)
    text(c, x + 13, y + height - 23, title, 11, GREEN, "Geist")
    wrap(c, x + 13, y + height - 43, body, width - 26, 10, 14, INK)


def main():
    import importlib.util
    spec = importlib.util.spec_from_file_location("evidence_sample", ROOT / "scripts/render-upwork-evidence-sample.py")
    renderer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(renderer)
    renderer.main()


if __name__ == "__main__":
    main()
