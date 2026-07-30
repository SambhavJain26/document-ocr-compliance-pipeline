# Stage 3 Fixtures Runbook

Stage 3 creates synthetic fixture artifacts for later extraction and workflow testing. It does not import n8n workflows, call OpenAI, write certificate rows, render the dashboard, or send chase emails.

## Generate Fixtures

From the repository root:

```powershell
.\scripts\generate-stage-3-fixtures.ps1
```

The generator reads:

```text
fixtures/spec/stage-3-fixtures.json
```

It writes:

```text
fixtures/pdfs/
fixtures/emails/
fixtures/expected/stage-3-expected.json
```

The generator uses the bundled Codex Python runtime when available because it includes `reportlab`, `pypdf`, `pdfplumber`, and `Pillow`. It also uses bundled Poppler for the scanned fixture.

## Verify Fixtures

```powershell
.\scripts\verify-stage-3-fixtures.ps1
```

The verifier checks:

- 20 fixture records exist;
- 17 PDF artifacts exist;
- 2 email payload fixtures exist;
- fixture 14 is metadata-only and generates no PDF;
- normal PDFs contain extractable text and the visible `SPECIMEN - SYNTHETIC TEST DOCUMENT` watermark;
- scanned fixture has little or no extractable text;
- password-protected PDF is encrypted and blocks unauthenticated text extraction;
- all PDFs render to PNG previews under `tmp/stage-3-previews/`;
- generated fixture artifacts avoid forbidden words: `ACORD`, `compliant`, `verified`, and `approved`.

## Fixture Notes

All fixture data is fictional and uses `example.test` email addresses. The certificate-like PDFs use a custom layout rather than an industry form replica. Do not add real client documents, real vendor data, logos, or copyrighted form text to `fixtures/`.

The password-protected PDF uses the local test password recorded in `fixtures/expected/stage-3-expected.json`; it is not a secret.
