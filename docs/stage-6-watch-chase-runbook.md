# Stage 6 Watch, Chase, Approval, and Escalation Runbook

Stage 6 turns stored certificate facts into human-approved chase actions. It does not send vendor email without an approval step, and it must not claim that a vendor is compliant, verified, covered, or approved.

## Files

- `db/postgres/004-stage-6-watch-chase.sql`: Stage 6 config, outreach audit columns, bucket query, logging, escalation, reply notices, and manual status functions.
- `n8n-workflows/stage-6-daily-watch-chase.json`: Schedule/manual daily watch workflow.
- `n8n-workflows/stage-6-non-pdf-reply-notice.json`: Gmail no-PDF reply notice workflow.
- `scripts/generate-stage-6-workflows.ps1`: regenerates both Stage 6 workflow exports.
- `scripts/apply-stage-6.ps1`: applies Stages 2, 5, and 6 SQL.
- `scripts/verify-stage-6-watch.ps1`: deterministic SQL behavior checks.
- `scripts/verify-stage-6-workflows.ps1`: workflow JSON/import/activation checks and safe OpenAI draft smoke.

## Configuration

Stage 6 adds these `client_config` keys:

- `stage_6_follow_up_days`: default `7`.
- `stage_6_outbound_test_mode`: default `true`.
- `stage_6_test_recipient_email`: actual Gmail recipient during test mode.
- `stage_6_approver_email`: approver address for Gmail Send-and-Wait.
- `stage_6_copy_vendor`: default `true`; only used for live sends, not test override sends.
- `stage_6_upload_form_url`: default `http://localhost:5678/form/coi-intake`. The chase email links this behind the anchor text `certificate upload link` and never prints the URL in the visible body. The approval email does show the raw URL so the approver can check the destination before sending. The default is reachable only on the demo machine; replace it with the public HTTPS form URL before any recipient outside localhost is expected to use it.
- `stage_6_watch_as_of_date`: optional fixed date for deterministic local tests.

When `stage_6_outbound_test_mode = true`, the workflow preserves intended recipient and cc in `outreach_log`, but sends only to `stage_6_test_recipient_email`. Keep this enabled until using a real client mailbox and real test addresses.

For local testing, `stage_6_approver_email` and `stage_6_test_recipient_email` may be the same Gmail address. Reapplying Stage 6 SQL preserves existing values for these keys.

## Behavior

`stage_6_actionable_vendors(as_of_date)` returns one actionable row per unpaused vendor using this bucket order:

`NEVER_RECEIVED`, `EXPIRED`, `14d`, `30d`, `60d`, `RE_ATTEST`.

The query suppresses vendors with:

- `vendors.chase_paused = true`.
- A pending approval for the same `issue_key`.
- An active follow-up window.
- Two overdue ignored requests for the same `issue_key`.

The daily workflow first calls `stage_6_escalate_overdue()`. After two ignored sent requests for the same issue, it writes a `CHASE_ESCALATED` notice and sets `vendors.chase_paused = true`.

## Manual Override

Use `stage_6_set_manual_certificate_status(certificate_id, status, note, set_by)` to mark a certificate `CANCELLED` or `NON_RENEWED`. These statuses are human-set only; the system does not detect cancellation from certificates.

Example:

```sql
SELECT stage_6_set_manual_certificate_status(
  123,
  'CANCELLED',
  'Producer emailed cancellation notice.',
  'ops@example.com'
);
```

## Verification

Run deterministic SQL checks:

```powershell
.\scripts\verify-stage-6-watch.ps1
```

Run workflow checks:

```powershell
.\scripts\verify-stage-6-workflows.ps1
```

The workflow verifier imports and publishes the two Stage 6 demo-facing workflows. If `stage_6_approver_email` and `stage_6_test_recipient_email` are blank, it runs the safe config-notice path. If both are configured, it sends an approval email, waits for the Approve click, then verifies that the approved chase email was sent to the configured test recipient.

To test the full Gmail approval/send path locally, set both config values before rerunning:

```sql
UPDATE client_config SET value = 'worksambhav26@gmail.com' WHERE key = 'stage_6_approver_email';
UPDATE client_config SET value = 'worksambhav26@gmail.com' WHERE key = 'stage_6_test_recipient_email';
```

Public phone approval remains deferred until the public HTTPS webhook path is configured before demo rehearsal.
