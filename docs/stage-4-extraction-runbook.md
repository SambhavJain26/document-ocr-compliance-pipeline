# Stage 4 Extraction And Validation Runbook

Stage 4 proves the extraction and validation core for one PDF at a time. It does not build the Gmail intake workflow, dashboard, reminder workflow, PDF storage route, or outbound messages.

## Artifacts

- `docs/schemas/coi-extraction.schema.json`: strict JSON Schema for OpenAI structured extraction.
- `scripts/lib/coi-stage-4-validator.js`: shared deterministic validation logic.
- `scripts/test-stage-4-validation.js`: offline tests for every Stage 4 validation flag.
- `n8n-workflows/stage-4-extraction-validation-core.json`: generated n8n workflow export.
- `scripts/generate-stage-4-workflow.ps1`: regenerates the workflow export from the shared validator and schema.
- `scripts/verify-stage-4-validation.ps1`: runs offline validator tests.
- `scripts/verify-stage-4-extraction.ps1`: validates the workflow export, then imports and executes it when n8n and Postgres are running.

## Generate Workflow Export

```powershell
.\scripts\generate-stage-4-workflow.ps1
```

The generated workflow embeds the validator source from `scripts/lib/coi-stage-4-validator.js`. Edit the shared validator first, then regenerate the workflow export.

## Offline Verification

```powershell
.\scripts\verify-stage-4-validation.ps1
```

This command requires local Node.js only. It verifies:

- hard flags route to review or ignore states;
- soft flags do not block `ON_FILE`;
- note flags remain informational;
- accepted holder entities match;
- near-duplicate vendors are not merged;
- WC missing-line checks are suppressed for `wc_exempt` vendors;
- renewal context catches older-than-on-file and coverage-gap cases;
- `addl_insd_asserted` and `cancellation_notice_wording` keep their honest field names.

## Live n8n Smoke Verification

Start the local stack first:

```powershell
.\scripts\start-local.ps1
.\scripts\verify-local.ps1
.\scripts\apply-stage-2.ps1
```

Then run:

```powershell
.\scripts\verify-stage-4-extraction.ps1
```

The script regenerates and parses the workflow export. If n8n and Postgres are running, it deletes any prior temporary workflow row with the Stage 4 smoke ID, imports the workflow, executes it by workflow ID in a one-off n8n container, parses the final validation node output, and deletes the temporary workflow row afterward.

The live smoke asserts:

- `f01-clean-current` uses the text branch, exact-matches the seeded vendor, returns `ON_FILE`, and extracts the expected holder, certificate date, and GL limits.
- `f04-scanned-clean-current` uses the vision branch, returns `ON_FILE`, and extracts a March 2027 GL expiration without hard validation flags.
- `f11-not-a-certificate` returns `NOT_A_COI` and `ignore_not_certificate`.
- `f18-password-protected` returns `PDF_PASSWORD_PROTECTED` and a graceful `NEEDS_REVIEW` result.

The smoke fixture set is:

- `f01-clean-current`;
- `f04-scanned-clean-current`;
- `f11-not-a-certificate`;
- `f18-password-protected`.

## n8n Notes

The n8n service mounts fixture files read-only at:

```text
/home/node/.n8n-files/fixtures
```

This matches n8n 2.x file-node access restrictions and keeps the workflow from reading arbitrary repo paths.

The workflow uses n8n's built-in OpenAI node as the default path. If a future n8n version changes the OpenAI node parameters for PDF file input, JSON Schema output, or dynamic model IDs, keep HTTP Request as the fallback path documented in the build plan rather than adding provider-switching logic to the demo workflow.

For n8n 2.29, the OpenAI node V2 extraction call uses `resource: text`, `operation: response`, messages under `responses.values`, dynamic `modelId`, and strict JSON Schema output under `options.textFormat.textOptions`. File read and text extraction nodes can remove original JSON or binary context, so the workflow reattaches fixture context after file read, after text extraction, and after model output.

The password-protected fixture is intentionally routed around `Extract From File`, because that node aborts encrypted PDFs before a downstream validator can turn the condition into structured review JSON.
