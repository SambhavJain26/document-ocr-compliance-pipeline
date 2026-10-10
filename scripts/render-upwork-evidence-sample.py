"""Create the client sample using flattened screenshots of actual executions."""
from pathlib import Path
import importlib.util
from PIL import Image
from reportlab.lib.utils import ImageReader
from reportlab.lib import colors
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('sample_design', ROOT/'scripts/render-upwork-work-sample.py')
design = importlib.util.module_from_spec(spec)
spec.loader.exec_module(design)
design.FONTS = ROOT/'docs/work-sample-assets/fonts'
design.ASSETS = ROOT/'docs/work-sample-assets/evidence'
text, wrap = design.text, design.wrap
INK, GREEN, MUTED, LINE, PALE = design.INK, design.GREEN, design.MUTED, design.LINE, design.PALE
OUTPUT = design.OUTPUT

def image(c,name,x,y,w,h):
    img=Image.open(design.ASSETS/(name+'.png')).convert('RGB')
    iw,ih=img.size; scale=min(1,w/iw,h/ih)
    dw,dh=iw*scale,ih*scale
    px=x+(w-dw)/2;py=y+(h-dh)/2
    c.drawImage(ImageReader(img),px,py,dw,dh)
    c.setStrokeColor(LINE);c.rect(px,py,dw,dh,fill=0,stroke=1)

def para(c,x,y,title,body,width=338):
    text(c,x,y,title,12,GREEN,'Geist')
    return wrap(c,x,y-22,body,width,11,16)-16

PAGES=[]
def page(section,title,subtitle,img=None,a=None,b=None,kind='standard'):
    PAGES.append(dict(section=section,title=title,subtitle=subtitle,img=img,a=a,b=b,kind=kind))

page('Automation case study','Vendor COI chasing','Document intake, expiry tracking and approval-led vendor follow-up.',kind='cover')
page('Architecture','Six workflows. One durable register.','n8n connects the process; Postgres holds certificate history, notices and outreach state.',kind='architecture')
page('01 / COI Intake','From a PDF to a usable record','Full actual canvas after n8n Tidy Up. Readable branches follow.','intake-overview',
 ('Trigger and incoming data','Gmail attachments, the certificate upload form or a manual synthetic test enter the same intake pipeline. Each PDF retains its source context.'),
 ('Output and human review','The original is saved, fields are extracted and deterministic checks choose a stored certificate or a notice. Ambiguous documents receive a review state.'))
page('01 / Intake entry points','Email and form inputs converge','Actual form and Gmail branches; the green manual path is the fresh synthetic run.','intake-inputs',
 ('Normalize first','Source-specific steps normalize attachments and form fields, then load vendor and holder context from Postgres.'),
 ('Connected evidence','The fresh run used Apex Plumbing Services LLC. A preserved form execution also stored three submitted PDFs; its results appear on page 8.'))
page('01 / Upload interface','A simple certificate upload form','Actual n8n form served by the running application. This capture shows the entry interface.','upload-form',
 ('Incoming data','A user submits a certificate PDF. The form trigger normalizes the upload and attaches the required context.'),
 ('Verified use','The preserved form run created certificates 1, 2 and 3. The fresh October run used the manual test trigger through the same storage, extraction and validation pipeline.'))
page('01 / Intake storage','Keep the original with its context','Enlarged storage branch from the fresh Apex run; green connections show the executed path.','intake-storage',
 ('Input to storage','The manual demonstration loads one synthetic PDF. Uploaded and emailed PDFs arrive with their attachment data already present.'),
 ('Persistent source document','Metadata is prepared and the original file is written to storage. Context is reattached so extraction retains the vendor and source relationship.'))
page('01 / Extraction and validation','Extract fields, then apply explicit rules','Actual OpenAI text and PDF branches converge on validation.','intake-model',
 ('Choose an extraction path','Text-rich PDFs use extracted text; low-text documents use the PDF/file path. Password-protected documents are routed to review before extraction.'),
 ('Validation is separate from AI','The model transcribes fields; code checks dates, holder, limits and vendor matching. Filing a document does not independently verify insurance or endorsements.'))
page('01 / Preserved form execution','Three uploads, three stored outcomes','Actual database-node output from the August 2026 form run. Source references are redacted.','intake-write',
 [('Apex Plumbing Services LLC','Vendor 1 → certificate 1, ON_FILE.'),('Blue Ridge HVAC Co.','Vendor 2 → certificate 2, ON_FILE. Expiry dates are tracked separately from filing status.'),('Summit Shield Roofing Inc.','Vendor 4 → certificate 3, NEEDS_REVIEW. Its inverted dates remain visible on the live register.')],kind='evidence')
page('01 / Fresh execution evidence','Apex is stored as certificate 6','Fresh run on 10 October 2026, using one synthetic PDF and real OpenAI extraction.',kind='fresh')
page('02 / Source Document Route','Open the document behind the row','Full actual canvas after Tidy Up. The dashboard passes the certificate record ID.','source-overview',
 ('Request and decision','The webhook receives a certificate ID. Postgres returns the stored source path; a safety check decides whether it can be read.'),
 ('Document response','The successful branch returns the original PDF. A missing or unsafe source uses a not-found response. The route does not decide insurance acceptability.'))
page('02 / Observable document output','The source route returned the stored PDF','Certificate 6: HTTP 200, application/pdf, with bytes matching the file written by intake.','source-delivered',
 ('Same synthetic vendor','The delivered document names Apex Plumbing Services LLC and Harbourline Property Management LLC, matching the extracted record.'),
 ('Dates and privacy','The coverage lines end on 30 March 2027, matching the dashboard. Producer contact details are flattened out of this image.'),kind='document')
page('03 / Daily Watch and Chase','Turn the register into an action queue','Full actual canvas after Tidy Up. Daily and manual triggers share the pipeline.','watch-overview',
 ('Incoming state','The workflow reads vendors, certificate dates and outreach history from Postgres. It handles overdue outreach before loading actionable vendors.'),
 ('Result and approval handoff','OpenAI drafts requests; pending outreach is recorded and a separate approval execution is called for each vendor. A person controls the send decision.'))
page('03 / Daily watch selection','Select vendors that need attention','Enlarged trigger, escalation and selection steps from the real workflow.','watch-selection',
 ('Trigger','The schedule is set for 08:00. The preserved proof run was started manually, making its selection and output available for review.'),
 ('Decisions in durable state','Database functions apply expiry buckets, suppression and follow-up rules. The preserved August run returned 17 actionable vendors.'))
page('03 / Draft and dispatch','Record each request before approval','Enlarged handoff branch, captured from the actual n8n editor.','watch-dispatch',
 ('Draft to a pending row','The drafted subject and body are attached to vendor context. Pending outreach is recorded before preparing the approval email.'),
 ('One approval execution per vendor','Each vendor receives its own workflow execution, giving every request an independent wait and a separate sent or declined result.'))
page('03 / Actual queue output','Seventeen requests recorded as pending','Preserved August run: actual Postgres output, with the 17-item count and the first stored rows.','watch-records',
 [('Observable business output','The workflow created 17 pending approval records.'),('Follow one request','Northstar Snow Removal LLC was outreach 10. Its approval, Gmail response and persisted sent status appear on page 18.'),('Demonstration boundary','This run used synthetic vendors, real OpenAI drafting and a test mailbox for Gmail delivery.')],kind='evidence')
page('04 / Vendor Approval Request','A human decision gates every send','Full actual canvas after Tidy Up. The caller provides one vendor and one drafted request.','approval-overview',
 ('Incoming request','Approval configuration is checked. Gmail sends an approval request and waits for a response in that vendor’s own execution.'),
 ('Resulting state','Approved requests use Gmail send and record sent status in Postgres. False approval responses record declined status. Configuration issues follow a notice branch.'))
page('04 / Approval branches','The decision controls send or stop','Enlarged decision branch with readable node labels.','approval-decision',
 ('Approved branch','Gmail sends the prepared request. Its response is carried into the outreach log, including the follow-up interval.'),
 ('Controlled stop','The false branch records a declined request. It does not pass through the Gmail send node. Every outcome belongs to an independent vendor execution.'))
page('04 / Genuine Gmail execution','Northstar: approved, sent and recorded','Preserved August run for synthetic Northstar Snow Removal LLC; real Gmail used a test recipient.',kind='approval')
page('04 / Controlled stop evidence','Vista: request recorded as declined','Preserved August run for synthetic Vista Glass and Door LLC, outreach 15.','approval-declined',
 [('Observable stop result','The database node returned status: declined and outreach_id: 15.'),('What this execution establishes','The stored response was false and the declined branch ran. This execution contains no Gmail send operation.'),('Separate vendor journey','Vista’s result stays separate from Northstar’s approved outreach 10.')],kind='evidence')
page('05 / Non-PDF Reply Notice','Keep messages without a PDF visible','Full actual workflow after Tidy Up. Gmail messages are normalized into stored notices.','reply-overview',
 ('Trigger and incoming data','Gmail supplies received messages. The normalizer skips messages with a PDF attachment; those documents belong to intake.'),
 ('Output and intervention','Messages without PDFs become intake notices for manual follow-up. The workflow does not create a certificate from an email body.'))
page('05 / Actual notice output','Ten messages became durable notices','Preserved August test-mailbox run: actual database results, with 10 items and notice IDs.','reply-notices',
 [('What this run exercised','Approval messages received by the test mailbox had no PDF attachments and passed through the notice capture path.'),('Result in the application','Notice IDs 1–10 returned PORTAL_LINK_NO_ATTACHMENT. This code labels a notice, not a filed certificate.'),('Business purpose','A person can follow up on messages that did not deliver a usable PDF, while document intake remains a separate process.')],kind='evidence')
page('06 / COI Dashboard','Make stored state easy to act on','Full actual workflow after Tidy Up. A browser request triggers a fresh database read.','dashboard-workflow',
 ('Request to register','The webhook loads vendor rows from Postgres, builds the register HTML and responds to the browser.'),
 ('What a person sees','Counts, dates, document flags, chase history and source links appear together. The displayed page refreshes every five seconds.'))
page('06 / Actual dashboard output','Apex’s record is visible in the register','Actual dashboard served by n8n on 10 October 2026. Every displayed vendor is synthetic.',kind='dashboard')
page('Verified demonstration','What this build demonstrated','Evidence connects inputs and decisions to stored records, delivered files and outreach outcomes.',kind='summary')

def base(c,n,p):
    c.setFillColor(colors.white);c.rect(0,0,792,612,fill=1,stroke=0)
    c.setFillColor(GREEN);c.rect(42,582,29,3,fill=1,stroke=0)
    text(c,42,558,p['section'].upper(),9.5,GREEN,'ManropeBold')
    text(c,42,527,p['title'],24,INK,'Geist')
    wrap(c,42,502,p['subtitle'],708,10.5,15,color=MUTED)
    c.setStrokeColor(LINE);c.line(42,39,750,39)
    text(c,42,24,'Vendor COI Chasing / Work Sample',8.5,MUTED)
    c.setFont('Manrope',8.5);c.drawRightString(750,24,f'{n} / {len(PAGES)}')

def render(c,p):
    kind=p['kind']
    if kind=='standard':
        image(c,p['img'],42,215,708,262)
        para(c,42,190,*p['a']);para(c,412,190,*p['b'])
    elif kind=='evidence':
        image(c,p['img'],334,72,416,405)
        y=464
        for title,body in p['a']:y=para(c,42,y,title,body,267)-10
        text(c,42,62,'Actual execution output; private fields cropped or redacted.',9,MUTED)
    elif kind=='cover':
        wrap(c,42,460,'I built an automation that collects vendor certificates of insurance, extracts dates and coverage fields, maintains a vendor register and prepares follow-up requests for human approval.',690,17,26,font='Geist')
        for x,t,b in [(42,'Collect','Gmail and form submissions bring PDFs into one consistent intake process.'),(286,'Track','Stored records connect original PDFs, expiry dates and review flags.'),(530,'Follow up','A daily watch prepares requests and waits for a person to approve each send.')]:
            design.callout(c,x,257,220,t,b,112)
        para(c,42,219,'Business problem','Certificates arrive across emails and uploads, while expiry dates and missing documents require repeated manual checking. The build connects these documents to one register and an approval-led follow-up process.',708)
        wrap(c,42,130,'Demonstration scope: synthetic vendors and certificate-like documents on a local n8n/Postgres stack. OpenAI extraction and drafting used the real service. Preserved Gmail runs delivered to a test mailbox. No mock application screens are presented as evidence.',708,10.5,16)
    elif kind=='architecture':
        rows=[('COI Intake','Gmail / form → PDF storage, extraction, checks → certificate or notice'),('Source Document Route','Dashboard record ID → stored source lookup → original PDF response'),('Daily Watch and Chase','Schedule → vendor/outreach state → drafts and pending outreach'),('Vendor Approval Request','One request → Gmail approval → sent or declined outreach'),('Non-PDF Reply Notice','Gmail message without PDF → normalization → durable notice'),('COI Dashboard','Browser request → Postgres register rows → refreshed dashboard')]
        y=465
        for name,body in rows:
            c.setFillColor(PALE);c.roundRect(42,y-43,708,50,5,fill=1,stroke=0)
            text(c,55,y-15,name,11,GREEN,'Geist');wrap(c,240,y-15,body,493,10.3,14);y-=60
        wrap(c,42,81,'Core systems: n8n, Postgres, Gmail, OpenAI, the upload form and certificate file storage.',708,10.5,15)
    elif kind=='fresh':
        image(c,'fresh-write',334,304,416,173);image(c,'source-preview',334,140,416,120)
        para(c,42,462,'Input','One synthetic Apex Plumbing Services LLC PDF entered through the manual test trigger.',267)
        para(c,42,355,'Executed steps','The run saved the original, extracted fields with OpenAI, validated the result and wrote a certificate record.',267)
        para(c,42,239,'Observable result','Postgres returned ON_FILE for vendor 1, certificate 6, with certificate_inserted. The register shows the same vendor and 30 March 2027 expiry.',267)
        wrap(c,42,107,'Lower image: vendor details in the actual delivered PDF. The enlarged document is on page 11.',267,10,15)
    elif kind=='approval':
        image(c,'northstar-input',42,350,320,85);image(c,'approval-true',410,350,340,100)
        text(c,42,328,'1 / Synthetic vendor context',10,GREEN,'ManropeBold')
        text(c,410,328,'2 / Gmail approval response: true',10,GREEN,'ManropeBold')
        image(c,'gmail-send',42,158,320,132);image(c,'approval-sent',410,158,340,132)
        text(c,42,137,'3 / Real Gmail response includes SENT',10,GREEN,'ManropeBold')
        text(c,410,137,'4 / Postgres records outreach 10 as sent',10,GREEN,'ManropeBold')
        wrap(c,42,98,'The same execution connects Northstar’s approval to Gmail delivery and a durable sent result with a seven-day follow-up interval. Contacts and Gmail message identifiers are removed from these captures.',708,10.5,16)
    elif kind=='dashboard':
        image(c,'dashboard-counts',42,363,708,112)
        image(c,'apex-register',42,232,708,106)
        image(c,'review-register',42,126,708,90)
        wrap(c,42,104,'Apex appears current until 30 March 2027; Summit Shield is marked Needs review. The register reads actual stored records. Certificate 6’s source link returned the original PDF successfully.',708,10.5,16)
    elif kind=='document':
        image(c,'source-delivered',42,109,708,370)
        wrap(c,42,88,'The delivered document names Apex Plumbing Services LLC and the expected certificate holder. Its coverage dates match the register. Producer contact details are flattened out of this image.',708,10.5,16)
    elif kind=='summary':
        rows=[('Document intake','Fresh Apex PDF → certificate 6 → current register row → original PDF returned.'),('Form submission','Three submitted PDFs → three stored results, including a document marked for review.'),('Daily watch','17 selected vendors → 17 durable pending approval records.'),('Approved outreach','Northstar approval true → Gmail SENT response → outreach 10 recorded as sent.'),('Controlled stop','Vista false response → outreach 15 declined; send node not executed.'),('Message capture','10 test-mailbox messages without PDFs → 10 durable notices.')]
        y=460
        for title,body in rows:
            text(c,42,y,title,12,GREEN,'Geist');wrap(c,210,y,body,540,11,16);y-=58
        wrap(c,42,94,'Documents become traceable records, dates become actionable requests and human decisions become recorded outreach outcomes.',708,11,17)

def main():
    design.fonts();OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    c=canvas.Canvas(str(OUTPUT),pagesize=(792,612),pageCompression=1)
    c.setTitle('Vendor COI Chasing | Work Sample');c.setAuthor('Automation Work Sample')
    c.setSubject('Synthetic vendor demonstration with genuine automation evidence')
    c.setCreator('Work Sample');c.setKeywords('')
    for n,p in enumerate(PAGES,1):base(c,n,p);render(c,p);c.showPage()
    c.save();print(f'{len(PAGES)} pages: {OUTPUT}')

if __name__=='__main__':main()
