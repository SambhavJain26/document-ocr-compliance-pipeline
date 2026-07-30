# Stage 7 Dashboard Runbook

Stage 7 adds the view-only demo register served by n8n at:

```text
http://localhost:5678/webhook/stage-7-dashboard-webhook/coi
```

The dashboard is also available at the simple local path `http://localhost:5678/webhook/coi`. The generated workflow keeps both webhook triggers pointed at the same page so the short demo URL and the stable verification URL work. It has no login, no framework, and no write controls. It is for the local demo only.

## Files

- `db/postgres/005-stage-7-dashboard.sql`: dashboard read model and `stage_7_dashboard_as_of_date` config default.
- `scripts/generate-stage-7-dashboard-workflow.js`: workflow generator for the dashboard webhook.
- `n8n-workflows/stage-7-dashboard-demo-view.json`: generated n8n workflow export.
- `scripts/apply-stage-7.ps1`: applies Stage 6, then Stage 7 SQL.
- `scripts/verify-stage-7-dashboard.ps1`: validates JSON, applies SQL, imports/publishes the dashboard workflow, checks rendered HTML, and verifies a source-PDF link.

## Apply

Start the local stack if needed:

```powershell
.\scripts\start-local.ps1
```

Apply the schema:

```powershell
.\scripts\apply-stage-7.ps1
```

Generate the workflow export:

```powershell
.\scripts\generate-stage-7-dashboard-workflow.ps1
```

Import and publish `n8n-workflows/stage-7-dashboard-demo-view.json` in n8n, or run the verifier below to do it through the CLI.

## Verify

```powershell
.\scripts\verify-stage-7-dashboard.ps1
```

The verifier:

- confirms the workflow JSON and Docker Compose config parse;
- applies Stage 7 SQL;
- imports and publishes the Stage 5 source-document route and Stage 7 dashboard route;
- seeds fixed dashboard rows for current, expiring, expired, review, paperwork-gap, manual status, and cancellation-notice wording states;
- checks the rendered dashboard for all expected states and forbidden dashboard language;
- opens a real stored fixture PDF through the existing Stage 5 source route;
- restores the local demo database to the clean 18-vendor opening state.

If Docker or the local services are unavailable, the script stops after static validation and prints the missing-service warning.

## Dashboard Rules

The dashboard shows date and document facts only:

- `Current until <date>`
- `Expires in <n> days`
- `Expired <n> days ago`
- `No certificate on file`
- `Needs review`

Flags render as row notes under the vendor name. `COVERAGE_GAP` is counted in the header and shown as a paperwork-gap note. Cancellation-notice wording is displayed as a neutral note because it is text on a certificate, not a promise of notice.

Manual `CANCELLED` and `NON_RENEWED` values are display-only in Stage 7. Use `stage_6_set_manual_certificate_status(certificate_id, status, note, set_by)` from Stage 6 to set them.
