# Stage 9 Client Onboarding Checklist

Use this checklist before a production go-live. It is intentionally more detailed than the local demo reset path.

## Commercial And Scope

- Scope and limitations document accepted.
- Data processing and retention terms accepted.
- Hosting model selected.
- Current n8n licensing position reviewed for the selected model.
- Client confirms who owns the VPS/cloud account.
- Exit/export plan accepted.
- Support response expectations agreed.

## Client Configuration

- Client legal name captured.
- Accepted certificate holder names captured.
- Owner LLC or property-specific holder entities captured.
- Vendor reminder cadence confirmed.
- Re-attestation cadence confirmed.
- Minimum coverage requirements confirmed.
- Per-trade requirements confirmed for high-risk trades.
- Worker compensation exemption policy confirmed.
- Dashboard access list confirmed.

## Vendor Import

- Vendor CSV received.
- Vendor legal names reviewed.
- Trade assigned to each vendor.
- Vendor contact email captured where available.
- Producer/agent email captured where available.
- Vendor aliases identified.
- Duplicate or near-duplicate vendors resolved.
- Vendors that should not be chased are paused.

## Mailbox And Credentials

- Client mailbox selected.
- Gmail/Google Workspace OAuth configured in n8n.
- Postgres credential configured in n8n.
- OpenAI credential configured in n8n.
- Model spend limit set.
- Approval recipient configured.
- Test recipient or production recipient behavior configured.
- Approval links tested from a non-local network.

## Production Deployment

- HTTPS URL configured.
- `WEBHOOK_URL` points to the production HTTPS URL.
- n8n editor protected.
- Dashboard protected.
- Upload route protected or limited.
- Postgres not exposed publicly.
- Certificate storage path mounted and backed up.
- Execution log retention configured.
- Secrets are not present in Git or workflow JSON.

## Production Controls

- Error Trigger workflow enabled and tested.
- Retry/backoff implemented for model calls.
- Retry/backoff implemented for Gmail sends.
- Dead-letter queue implemented and visible.
- Idempotency implemented with message ID plus attachment hash.
- Daily heartbeat workflow enabled.
- Weekly canary certificate workflow enabled.
- Weekly client digest enabled.
- Dashboard uptime monitor enabled.
- Backup job enabled.
- Restore test completed.

## Training

- Approver understands the Gmail approval step.
- Approver understands that approving a draft sends a reminder email only.
- Client understands dashboard statuses.
- Client understands `NEEDS_REVIEW`.
- Client knows how to open source PDFs.
- Client knows who handles holder mismatch, low limit, and missing GL flags.
- Client understands the system does not verify coverage.

## Go-Live Test

- Reset or migrate production state intentionally.
- Process one clean known certificate.
- Process one expiring certificate.
- Process one document that needs review.
- Confirm dashboard rows.
- Confirm source PDF links.
- Run daily watch manually.
- Approve one chase email.
- Confirm final vendor/producer email sent.
- Confirm outreach log.
- Confirm weekly digest preview.
- Confirm backup after test records exist.

## Handoff

- Client receives local runbook.
- Client receives dashboard URL.
- Client receives support contact path.
- Client receives export process.
- Operator records deployment version, workflow IDs, model ID, backup location, and credential names.
