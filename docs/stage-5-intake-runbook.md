# Stage 5 Intake Runbook

Stage 5 adds the first persistent intake layer. It accepts fixture/manual inputs, form uploads, and Gmail attachments through the generated intake workflow, stores original PDFs on disk, writes certificate and coverage rows to Postgres, and creates deterministic intake notices for items that should not create certificate rows.

## Files

- `db/postgres/003-stage-5-intake.sql`: Stage 5 notice table, source-ref indexes, config defaults, and `store_stage_5_intake_result(payload jsonb)`.
- `scripts/generate-stage-5-workflows.js`: generator for both Stage 5 workflow exports.
- `n8n-workflows/stage-5-intake-workflow.json`: generated intake workflow.
- `n8n-workflows/stage-5-source-document-route.json`: generated source PDF route.
- `scripts/apply-stage-5.ps1`: applies Stage 2 plus Stage 5 SQL and creates today’s local certificate storage directory.
- `scripts/verify-stage-5-storage.ps1`: deterministic SQL/storage checks.
- `scripts/verify-stage-5-intake.ps1`: live n8n/OpenAI fixture smoke checks.

## Storage

`docker-compose.yml` mounts:

```text
./data/certificates -> /home/node/.n8n-files/certificates
```

`data/` is ignored. Do not place real client documents in git.

The intake workflow writes PDFs under:

```text
/home/node/.n8n-files/certificates/YYYY/MM/DD/<safe-source-ref>-<safe-filename>.pdf
```

n8n’s file node requires the parent directory to exist. `scripts/apply-stage-5.ps1` creates today’s UTC path on the host for local smoke runs.

## Apply

Start the local stack first:

```powershell
.\scripts\start-local.ps1
```

Apply the schema and config defaults:

```powershell
.\scripts\apply-stage-5.ps1
```

This is idempotent and reruns Stage 2 first.

## Generate Workflows

```powershell
.\scripts\generate-stage-5-workflows.ps1
```

Do not hand-edit generated workflow JSON. Update `scripts/generate-stage-5-workflows.js` or the shared validator, then regenerate.

## Storage Checks

```powershell
.\scripts\verify-stage-5-storage.ps1
```

This tests:

- clean `ON_FILE` insert and coverage insert;
- duplicate `source_ref` skip;
- `NEEDS_REVIEW` flag retention;
- notice-only non-certificate and older-than-current handling;
- no vendor creation for unmatched incoming names.

## Intake Smoke

```powershell
.\scripts\verify-stage-5-intake.ps1
```

This imports temporary Stage 5 workflows, runs deterministic fixture sets through the manual trigger, checks database state, checks source-PDF retrieval, truncates Stage 5 data, deletes the temporary workflows, and restarts n8n to clear active webhook state.

It covers:

- `f01-clean-current`;
- `f10-two-certificates-email`;
- `f02-expiring-20-days` then `f12-renewal-supersede`;
- `f12-renewal-supersede` then older `f02-expiring-20-days`;
- `f03-expired-34-days` then `f13-renewal-coverage-gap`;
- `f11-not-a-certificate`, `f18-password-protected`, and `f19-portal-link-email`.

Raw n8n output is saved under ignored `tmp/stage5-intake-*-output.txt` for debugging.

## Source PDF Route

The source-document workflow uses Webhook node path `coi-source/:certificate_id` with stable webhook ID `stage-5-source-document-webhook`. For CLI-imported local smoke workflows on n8n 2.29, the reachable URL is:

```text
http://localhost:5678/webhook/stage-5-source-document-webhook/coi-source/<certificate_id>
```

The route returns PDF bytes only when the certificate exists and `stored_path` starts with `/home/node/.n8n-files/certificates/`. Missing or unsafe paths return a small 404 response.

## Gmail And Form Intake

The generated intake workflow includes:

- Form Trigger path `coi-intake`;
- Gmail Trigger with `simple=false`, `filters.q='has:attachment'`, `downloadAttachments=true`, and attachment prefix `attachment_`;
- disabled IMAP fallback path for non-Google mailboxes.

Live Gmail smoke is optional in Stage 5. Gmail credentials must be created manually inside n8n and must not be committed.

## Notes

- Stage 5 does not create vendors from incoming certificates. Exact vendor matches link `vendor_id`; unmatched and near-match cases require review.
- Manager notices are stored in `intake_notices`. Optional Gmail notice sending is controlled by `send_manager_notices` and `manager_notice_email`, but live sends are not required for Stage 5.
- Stage 5 does not build chase emails, approval gates, dashboard HTML, or reminder scheduling.
