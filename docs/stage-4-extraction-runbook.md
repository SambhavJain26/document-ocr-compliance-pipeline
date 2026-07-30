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

The script regenerates and parses the workflow export. If n8n and Postgres are running, it imports the Stage 4 workflow, executes it by workflow ID, checks that the fixed smoke fixture IDs appear in the output, and attempts to delete the temporary workflow.

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
