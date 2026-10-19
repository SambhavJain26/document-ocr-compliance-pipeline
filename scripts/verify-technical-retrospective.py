"""Check and render the public review PDF. No n8n, database or email changes."""
from pathlib import Path
import json
import re
from collections import Counter
import pdfplumber
import pypdfium2 as pdfium
from pypdf import PdfReader
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'docs/carousels/out'
PDF = OUT / 'technical-retrospective-vendor-coi.pdf'
PAGES = OUT / 'technical-retrospective-pages'
PAGES.mkdir(parents=True, exist_ok=True)
reader = PdfReader(PDF)
assert len(reader.pages) == 10, f'Page count: {len(reader.pages)}'
with pdfplumber.open(PDF) as document:
    text = '\n'.join(p.extract_text() or '' for p in document.pages)
text += '\n' + str(reader.metadata)
assert '\u2014' not in text and '!' not in text
assert not re.search(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|https?://|localhost|[A-Za-z]:[\\/]|\.env|sk-[A-Za-z0-9]', text)
assert not reader.attachments
assert not any(p.get('/Annots') for p in reader.pages), 'Unexpected link/annotation in public PDF'
fonts = set()
images = set()
def resource_fonts(resources):
    result = list(resources.get('/Font', {}).values())
    for xo in resources.get('/XObject', {}).values():
        obj = xo.get_object()
        if obj.get('/Resources'):
            result.extend(resource_fonts(obj['/Resources']))
    return result

for p in reader.pages:
    assert abs(float(p.mediabox.width)-810) < 1
    assert abs(float(p.mediabox.height)-1012.5) < 1
    for f in resource_fonts(p['/Resources']):
        obj = f.get_object()
        fonts.add(str(obj.get('/BaseFont')))
        desc = obj.get('/FontDescriptor')
        if not desc and obj.get('/DescendantFonts'):
            desc = obj['/DescendantFonts'][0].get_object().get('/FontDescriptor')
        assert desc and any(k in desc.get_object() for k in ['/FontFile','/FontFile2','/FontFile3']), obj
    # Chrome places the tiled grain inside a pattern inside a form XObject.
    def collect_images(value, seen):
        obj = value.get_object() if hasattr(value, 'get_object') else value
        if id(obj) in seen:
            return
        seen.add(id(obj))
        if isinstance(obj, dict):
            if obj.get('/Subtype') == '/Image':
                images.add(obj.get_data())
            for key, child in obj.items():
                if key not in ('/Parent', '/P'):
                    collect_images(child, seen)
        elif isinstance(obj, list):
            for child in obj:
                collect_images(child, seen)
    collect_images(p['/Resources'], set())
assert any('Switzer' in f for f in fonts), fonts
assert any('Zodiak' in f for f in fonts), fonts
assert not any(re.search(r'Times|Arial|Helvetica', f) for f in fonts), fonts
assert len(images) == 1, f'Expected one shared grain bitmap, got {len(images)}'

# Text preservation: every public string in HTML must survive PDF extraction,
# allowing typographic ligatures and whitespace changes.
html = (ROOT / 'docs/carousels/technical-retrospective-vendor-coi.html').read_text(encoding='utf8')
def normalized(value):
    import html as html_module
    import unicodedata
    return re.sub(r'\s+', '', unicodedata.normalize('NFKC', html_module.unescape(value))).casefold()
sections = re.findall(r'<section\b[\s\S]*?</section>', html)
for i, section in enumerate(sections):
    clean = re.sub(r'<svg[\s\S]*?</svg>', '', section)
    runs = re.findall(r'>([^<>]+)<', clean)
    clean = re.sub(r'<[^>]+>', ' ', clean)
    # Inline SVG compositing can move marked text later in the PDF paint order.
    # Compare content independently of that order; inspect geometry below.
    assert Counter(normalized(clean)) == Counter(normalized(reader.pages[i].extract_text())), f'Text lost on page {i+1}'
    for run in runs:
        assert normalized(run) in normalized(reader.pages[i].extract_text()), f'Text run lost on page {i+1}: {run}'

with pdfplumber.open(PDF) as pdf:
    for i, p in enumerate(pdf.pages):
        for c in p.chars:
            assert c['x0'] >= 52 and c['x1'] <= 758, (i+1, 'horizontal bounds', c['text'])
            assert c['top'] >= 40 and c['bottom'] <= 974, (i+1, 'vertical bounds', c['text'])
        content = [c for c in p.chars if 105 < c['top'] < 908]
        assert all(c['bottom'] < 900 for c in content), f'Content crosses footer band: {i+1}'

doc = pdfium.PdfDocument(PDF)
sheet = Image.new('RGB', (1128, 4*478+24), '#777777')
draw = ImageDraw.Draw(sheet)
for i in range(len(doc)):
    im = doc[i].render(scale=4/3).to_pil().convert('RGB')
    im.save(PAGES / f'slide-{i+1:02}.png')
    thumb = im.copy()
    thumb.thumbnail((352,440))
    x, y = 12+(i%3)*376, 12+(i//3)*478
    sheet.paste(thumb,(x,y))
    draw.text((x,y+444),f'{i+1:02}', fill='white')
sheet.save(OUT/'technical-retrospective-preview.png')
report = {'pages':len(doc),'dimensions_pt':[810,1012.5],'fonts':sorted(fonts),'unique_images':len(images),'text_preserved':True,'privacy_scan':'PASS','text_bounds':'PASS','visual_review':'Review every page PNG plus contact sheet separately.'}
(OUT/'technical-retrospective-qa.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report,indent=2))
