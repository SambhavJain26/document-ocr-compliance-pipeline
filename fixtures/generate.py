#!/usr/bin/env python3
import argparse,json,shutil
from datetime import date,timedelta
from email.message import EmailMessage
from pathlib import Path
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.utils import ImageReader
from pypdf import PdfReader,PdfWriter
from PIL import Image,ImageDraw,ImageFont
def main():
 a=argparse.ArgumentParser();a.add_argument("--spec",default="spec/fixtures.json");a.add_argument("--out",default="out");args=a.parse_args()
 s=json.loads(Path(args.spec).read_text());out=Path(args.out)
 if out.exists(): shutil.rmtree(out)
 out.mkdir(parents=True);today=date.today();manifest=[]
 for x in s["fixtures"]:
  if x.get("kind")=="eml":
   m=EmailMessage();m["Subject"]="Certificate available in portal";m.set_content("Visit https://portal.vendorfiles.example/certificate");name=x["id"]+".eml";(out/name).write_bytes(m.as_bytes());manifest.append({"id":x["id"],"file":name,"kind":"eml"});continue
  name=x["id"]+".pdf";path=out/name;c=Canvas(str(path),pagesize=letter);c.setTitle("Synthetic test document")
  title="CERTIFICATE OF LIABILITY INSURANCE" if x.get("kind")!="other" else "EQUIPMENT RENTAL INVOICE"
  if x.get("scanned"):
   image=Image.new("RGB",(1275,1650),"#f4efe4");draw=ImageDraw.Draw(image)
   try: font=ImageFont.truetype("C:/Windows/Fonts/arial.ttf",32)
   except OSError: font=ImageFont.load_default()
   draw.text((100,100),title,fill="black",font=font);draw.text((100,180),"INSURED: "+x["vendor"],fill="black",font=font)
   draw.text((100,240),"EXPIRATION: "+str(today+timedelta(days=x["exp"])),fill="black",font=font);draw.text((340,1400),s["defaults"]["watermark"],fill="#aa4444",font=font)
   c.drawImage(ImageReader(image),0,0,width=letter[0],height=letter[1]);c.save()
  else:
   c.setFont("Helvetica-Bold",16);c.drawString(45,750,title);c.setFont("Helvetica",10);c.drawString(45,710,"INSURED:");c.drawString(45,690,"HOLDER:")
   c.drawString(120,710,x.get("vendor","Synthetic Test Vendor"));c.drawString(120,690,s["defaults"]["holder"])
   c.acroForm.textfield(name="insured_name",value=x.get("vendor","Synthetic Test Vendor"),x=115,y=700,width=390,height=16,borderWidth=1)
   c.acroForm.textfield(name="certificate_holder",value=s["defaults"]["holder"],x=115,y=680,width=390,height=16,borderWidth=1)
   if "exp" in x:
    c.drawString(45,650,"GENERAL LIABILITY EXPIRATION:")
    c.drawString(225,650,str(today+timedelta(days=x["exp"])))
    c.acroForm.textfield(name="gl_expiration",value=str(today+timedelta(days=x["exp"])),x=220,y=640,width=160,height=16,borderWidth=1)
   if x["id"]=="f01-clean-current":
    effective=str(today-timedelta(days=120));expiration=str(today+timedelta(days=x["exp"]))
    c.drawString(45,610,"COMMERCIAL GENERAL LIABILITY  POLICY: SYN-GL-001  EFFECTIVE: "+effective+"  EXPIRATION: "+expiration)
    c.drawString(45,590,"EACH OCCURRENCE: $1,000,000  GENERAL AGGREGATE: $2,000,000")
    c.drawString(45,570,"AUTOMOBILE LIABILITY  POLICY: SYN-AU-001  EFFECTIVE: "+effective+"  EXPIRATION: "+expiration)
    c.drawString(45,550,"WORKERS COMPENSATION  POLICY: SYN-WC-001  EFFECTIVE: "+effective+"  EXPIRATION: "+expiration)
   c.setFont("Helvetica-Bold",18);c.setFillColorRGB(.8,.1,.1);c.drawString(120,380,s["defaults"]["watermark"]);c.save()
  if x.get("encrypted"):
   r=PdfReader(str(path));w=PdfWriter();[w.add_page(p) for p in r.pages];w.encrypt("fixture-password");w.write(path.open("wb"))
  item={"id":x["id"],"file":name,"kind":"pdf"}
  if "exp" in x:item["expiration_date"]=str(today+timedelta(days=x["exp"]))
  if "eff" in x:item["effective_date"]=str(today+timedelta(days=x["eff"]))
  if x["id"]=="f13-coverage-gap":item["effective_date"]=str(today-timedelta(days=20))
  manifest.append(item)
 (out/"manifest.json").write_text(json.dumps({"generated_on":str(today),"fixtures":manifest},indent=2));print(str(len(manifest))+" fixtures written")
if __name__=="__main__":main()
