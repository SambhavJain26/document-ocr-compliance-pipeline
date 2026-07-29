#!/usr/bin/env python3
import argparse,json
from datetime import date,timedelta
from email import policy
from email.parser import BytesParser
from pathlib import Path
from pypdf import PdfReader
def main():
 ap=argparse.ArgumentParser();ap.add_argument("--out",default="out");args=ap.parse_args();out=Path(args.out)
 items={x["id"]:x for x in json.loads((out/"manifest.json").read_text())["fixtures"]}
 assert len(items)==20
 assert items["f02-expiring-20d"]["expiration_date"]==str(date.today()+timedelta(days=20))
 assert items["f03-expired-34d"]["expiration_date"]==str(date.today()-timedelta(days=34))
 assert items["f13-coverage-gap"]["effective_date"]==str(date.today()-timedelta(days=20))
 assert PdfReader(str(out/"f18-encrypted.pdf")).is_encrypted
 assert len(PdfReader(str(out/"f02-expiring-20d.pdf")).get_fields() or {}) == 3
 assert len(PdfReader(str(out/"f04-scanned.pdf")).pages[0].extract_text() or "") < 20
 msg=BytesParser(policy=policy.default).parsebytes((out/"f19-portal-link.eml").read_bytes())
 assert "https://" in msg.get_body().get_content() and not list(msg.iter_attachments())
 for path in out.glob("*.pdf"):
  if path.name=="f18-encrypted.pdf":continue
  text="".join(page.extract_text() or "" for page in PdfReader(str(path)).pages)
  if path.name!="f04-scanned.pdf":assert "SPECIMEN" in text
  assert "ACORD" not in text.upper()
 print("Stage 3 fixture gate PASSED")
if __name__=="__main__":main()
