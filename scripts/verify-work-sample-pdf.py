"""Check public text, structure, footer coverage and flattened image provenance."""
from pathlib import Path
import re, hashlib, json
from PIL import Image
from pypdf import PdfReader
import pdfplumber

ROOT=Path(__file__).resolve().parent.parent
PDF=ROOT/'output/pdf/vendor-coi-automation-work-sample.pdf'
ASSETS=ROOT/'docs/work-sample-assets/evidence'

def digest(img):
    img=img.convert('RGB')
    return (img.size, hashlib.sha256(img.tobytes()).hexdigest())

def main():
    reader=PdfReader(PDF)
    text='\n'.join(p.extract_text() or '' for p in reader.pages)
    metadata='\n'.join(str(v) for v in reader.metadata.values())
    forbidden={
        'email':r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}',
        'URL':r'https?://|mailto:|www\.',
        'repository path':r'[A-Z]:[\\/]|/home/|\.md\b|\.ps1\b',
        'personal identifier':r'Sambhav|Jain|sambhavn8n|worksambhav',
        'telephone':r'\+\d[\d ()-]{8,}\d',
    }
    for name,pattern in forbidden.items():
        assert not re.search(pattern,text+'\n'+metadata,re.I),name
    root=reader.trailer['/Root']
    assert '/OpenAction' not in root and '/AA' not in root and '/AcroForm' not in root
    assert not reader.attachments
    assert '/Names' not in root
    approved={digest(Image.open(p)) for p in ASSETS.glob('*.png')}
    image_count=0
    for n,p in enumerate(reader.pages,1):
        t=p.extract_text() or ''
        assert 'Vendor COI Chasing / Work Sample' in t
        assert f'{n} / {len(reader.pages)}' in t
        assert not p.get('/Annots')
        for img in p.images:
            assert digest(img.image) in approved, 'unapproved or altered embedded image'
            image_count+=1
    with pdfplumber.open(PDF) as doc:
        for n,p in enumerate(doc.pages,1):
            assert all(ch['x0']>=40 and ch['x1']<=752 and ch['top']>=0 and ch['bottom']<=592 for ch in p.chars),f'clipped text page {n}'
    result=dict(pages=len(reader.pages),text_privacy='PASS',metadata='PASS',links='none',attachments='none',embedded_images=image_count,image_provenance='PASS',footers='PASS',text_bounds='PASS')
    print(json.dumps(result,indent=2))
    out=ROOT/'tmp/pdfs/work-sample-review/privacy-checks.json'
    out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2))

if __name__=='__main__':main()
