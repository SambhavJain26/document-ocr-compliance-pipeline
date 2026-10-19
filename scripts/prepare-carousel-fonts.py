"""Cache Fontshare faces for technical decks without committing font binaries.

The CDN currently returns static files with internal names set to 'false'.
Give each downloaded face explicit names so PDF subsets cannot collide.
Requires fonttools. Cache lives under ignored tmp/; no workflow/service access.
"""
from pathlib import Path
from urllib.request import urlopen, Request
import re
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / 'tmp/carousel-fonts'
CACHE.mkdir(parents=True, exist_ok=True)
SPECS = [('switzer','400,500,600,700,800,900'),('zodiak','801')]
rules = []
for slug, weights in SPECS:
    url = f'https://api.fontshare.com/v2/css?f[]={slug}@{weights}&display=swap'
    css = urlopen(Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=45).read().decode()
    for block in re.findall(r'@font-face\s*\{([^}]+)\}',css):
        weight = re.search(r'font-weight:\s*(\d+)',block)[1]
        style = re.search(r'font-style:\s*(\w+)',block)[1]
        source = re.search(r"url\('([^']+\.ttf)'\)",block)[1]
        filename = f'{slug}-{weight}-{style}.ttf'
        target = CACHE / filename
        family = f'Carousel {slug.title()}'
        face = ('Italic' if style=='italic' else 'Regular') + weight
        if not target.exists():
            raw = CACHE / ('raw-'+filename)
            raw.write_bytes(urlopen('https:'+source,timeout=45).read())
            font = TTFont(raw)
            for rec in font['name'].names:
                names = {1:family,2:face,3:f'{family}-{face}',4:f'{family} {face}',6:f'Carousel{slug.title()}-{face}',16:family,17:face}
                if rec.nameID in names:
                    rec.string = names[rec.nameID].encode(rec.getEncoding())
            font.save(target)
        rules.append(f'@font-face {{ font-family:"{family}"; src:url("{filename}") format("truetype"); font-weight:{weight}; font-style:{style}; font-display:block; }}')
(CACHE/'fonts.css').write_text('\n'.join(rules),encoding='utf8')
print(f'Prepared {len(rules)} font faces in ignored render cache.')
