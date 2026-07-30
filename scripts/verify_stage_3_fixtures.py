import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from pypdf import PdfReader
from pypdf.errors import FileNotDecryptedError


FORBIDDEN = ["ACORD", "compliant", "verified", "approved"]
WATERMARK = "SPECIMEN - SYNTHETIC TEST DOCUMENT"


def find_pdftoppm():
    env_path = os.environ.get("PDFTOPPM")
    if env_path:
        return env_path
    found = shutil.which("pdftoppm")
    if found:
        return found
    raise RuntimeError("pdftoppm not found")


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def extract_text(path, password=None):
    reader = PdfReader(str(path))
    if reader.is_encrypted:
        if password is None:
            raise FileNotDecryptedError("PDF is encrypted")
        if reader.decrypt(password) == 0:
            raise FileNotDecryptedError("PDF password failed")
    parts = []
    for page in reader.pages:
        parts.append(page.extract_text() or "")
    return "\n".join(parts)


def render_preview(pdftoppm, pdf_path, preview_dir, password=None):
    prefix = preview_dir / pdf_path.stem
    command = [pdftoppm, "-r", "96", "-png"]
    if password:
        command.extend(["-upw", password])
    command.extend([str(pdf_path), str(prefix)])
    subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    rendered = sorted(preview_dir.glob(f"{pdf_path.stem}-*.png"))
    if not rendered:
        raise AssertionError(f"No preview rendered for {pdf_path.name}")
    return rendered


def assert_no_forbidden(label, text):
    upper = text.upper()
    for forbidden in FORBIDDEN:
        if forbidden.upper() in upper:
            raise AssertionError(f"Forbidden term {forbidden!r} found in {label}")


def main():
    repo_root = Path(__file__).resolve().parents[1]
    expected_path = repo_root / "fixtures" / "expected" / "stage-3-expected.json"
    spec_path = repo_root / "fixtures" / "spec" / "stage-3-fixtures.json"
    pdf_dir = repo_root / "fixtures" / "pdfs"
    email_dir = repo_root / "fixtures" / "emails"
    preview_dir = repo_root / "tmp" / "stage-3-previews"

    pdftoppm = find_pdftoppm()
    expected = read_json(expected_path)
    spec = read_json(spec_path)

    if preview_dir.exists():
        shutil.rmtree(preview_dir)
    preview_dir.mkdir(parents=True, exist_ok=True)

    assert_no_forbidden("fixture spec", json.dumps(spec))
    assert_no_forbidden("expected metadata", json.dumps(expected))

    records = expected["fixtures"]
    checks = []

    def check(name, passed, detail):
        checks.append((name, bool(passed), str(detail)))

    check("twenty fixture records", len(records) == 20, len(records))

    pdfs = sorted(pdf_dir.glob("*.pdf"))
    emails = sorted(email_dir.glob("*.json"))
    check("seventeen pdf artifacts", len(pdfs) == 17, len(pdfs))
    check("two email payloads", len(emails) == 2, len(emails))

    by_id = {record["id"]: record for record in records}
    check("fixture 14 metadata only", by_id["f14-no-file-vendors"]["type"] == "metadata_only" and not by_id["f14-no-file-vendors"]["artifacts"], by_id["f14-no-file-vendors"].get("artifacts"))

    for email_path in emails:
        payload = read_json(email_path)
        assert_no_forbidden(email_path.name, json.dumps(payload))
        check(f"email payload valid {email_path.name}", "fixture_id" in payload and "attachments" in payload, payload.get("fixture_id"))

    preview_count = 0
    for pdf_path in pdfs:
        fixture_id = pdf_path.stem
        record = by_id.get(fixture_id)
        if not record:
            raise AssertionError(f"PDF without expected metadata: {pdf_path.name}")
        password = record.get("password")
        rendered = render_preview(pdftoppm, pdf_path, preview_dir, password=password)
        preview_count += len(rendered)

        if record["type"] == "password_certificate":
            reader = PdfReader(str(pdf_path))
            check("password pdf encrypted", reader.is_encrypted, pdf_path.name)
            try:
                extract_text(pdf_path)
            except FileNotDecryptedError:
                unauth_failed = True
            else:
                unauth_failed = False
            check("password pdf blocks unauthenticated text", unauth_failed, pdf_path.name)
            decrypted_text = extract_text(pdf_path, password=password)
            assert_no_forbidden(pdf_path.name, decrypted_text)
            check("password pdf decrypts with test password", WATERMARK in decrypted_text, pdf_path.name)
            continue

        text = extract_text(pdf_path)
        assert_no_forbidden(pdf_path.name, text)

        if record["type"] == "scanned_certificate":
            check("scanned pdf has little text", len(text.strip()) < 50, len(text.strip()))
        else:
            check(f"text pdf has watermark {pdf_path.name}", WATERMARK in text, pdf_path.name)
            check(f"text pdf has extractable text {pdf_path.name}", len(text.strip()) > 200, len(text.strip()))

    check("rendered previews created", preview_count >= len(pdfs), preview_count)

    failures = [item for item in checks if not item[1]]
    print("check_name\tpassed\tdetail")
    for name, passed, detail in checks:
        print(f"{name}\t{'t' if passed else 'f'}\t{detail}")

    if failures:
        raise AssertionError(f"{len(failures)} Stage 3 fixture checks failed")

    print("Stage 3 fixture verification complete.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Stage 3 fixture verification failed: {exc}", file=sys.stderr)
        raise
