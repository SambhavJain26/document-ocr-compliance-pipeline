"""Flatten approved crops from genuine UI captures; private originals stay in tmp."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / 'docs/work-sample-assets/evidence'
PRIVATE = ROOT / 'tmp/work-sample-evidence'
RAW = PRIVATE / 'canvas-captures'

def crop(source, target, box, redactions=()):
    img = Image.open(source).convert('RGB')
    draw = ImageDraw.Draw(img)
    for rect in redactions:
        draw.rectangle(rect, fill='#252525')
    img.crop(box).save(DEST / target, optimize=True)

def main():
    public = {
      'intake-overview': (125,365,1380,565),
      'intake-inputs': (330,210,1335,727),
      'intake-storage': (245,302,1462,610),
      'intake-extraction': (275,315,1440,720),
      'intake-validation': (190,310,1390,790),
      'intake-final': (145,80,1245,710),
      'watch-overview': (120,340,1405,630),
      'watch-selection': (285,280,1210,670),
      'watch-dispatch': (175,385,1040,590),
      'approval-overview': (125,280,1405,670),
      'approval-hold': (340,340,1235,730),
      'approval-decision': (55,245,1395,725),
      'source-overview': (205,300,1330,665),
      'reply-overview': (425,395,1105,585),
      'dashboard-workflow': (330,300,1220,665),
      'upload-form': (503,20,961,334),
      'dashboard-live': (95,30,1338,858),
    }
    for name, box in public.items():
        crop(RAW / (name+'-raw.jpg'), name+'.png', box)
    crop(RAW/'intake-final-raw.jpg', 'intake-model.png', (145,365,1050,710))
    for name, box in {
      'fresh-write': (801,70,1428,302),
      'intake-write': (801,70,1428,650),
      'approval-true': (948,70,1428,211),
      'approval-sent': (801,70,1428,258),
      'approval-declined': (801,70,1428,232),
      'reply-notices': (801,70,1428,716),
      'watch-records': (801,70,1428,435),
    }.items():
        redactions = {
            'intake-write': [(814,217,1424,258),(814,355,1424,396),(814,494,1424,535)],
            'fresh-write': [(814,216,1424,239)],
        }.get(name, ())
        crop(PRIVATE / (name+'-raw.jpg'), name+'.png', box, redactions)
    crop(PRIVATE/'gmail-send-raw.jpg', 'gmail-send.png', (944,70,1437,256), [(955,170,1197,247)])
    crop(PRIVATE/'approval-true-raw.jpg', 'northstar-input.png', (79,145,500,240))
    crop(PRIVATE/'source-delivered.png', 'source-delivered.png', (45,170,1110,725), [(590,190,1100,241)])
    crop(PRIVATE/'source-delivered.png', 'source-preview.png', (45,248,575,366))
    crop(RAW/'dashboard-live-raw.jpg', 'dashboard-counts.png', (95,30,1338,211))
    crop(RAW/'dashboard-live-raw.jpg', 'apex-register.png', (105,274,1330,440))
    crop(RAW/'dashboard-live-raw.jpg', 'review-register.png', (105,740,1330,856))
    print('Flattened screenshots ready; originals are never embedded in the PDF.')

if __name__ == '__main__':
    main()
