# Stage 9 Production Readiness Plan

Stage 9 defines the work required before a paying client relies on the COI chasing system. It does not convert the local demo into production by itself. The demo workflows remain useful for sales and rehearsal; production needs the controls below implemented, tested, and accepted.

## Hosting Decision

Default production model:

- One client per deployment.
- Client-owned VPS or cloud account, or a VPS provisioned in the client's name.
- n8n, Postgres, certificate storage, backup storage, and monitoring are isolated per client.
- No shared multi-tenant n8n deployment unless n8n licensing is clarified in writing for that exact commercial model.

Recommended baseline:

- Linux VPS with Docker Compose.
- Caddy or another managed reverse proxy for HTTPS.
- n8n editor behind authentication and not openly exposed.
- Postgres bound only to the Docker network, not the public internet.
- Separate OpenAI and Gmail credentials per client where practical.

Demo-only local services such as unauthenticated dashboard access and localhost pgweb must not be exposed publicly.

## Required Production Controls

### Error Handling

- Add an n8n Error Trigger workflow for each production deployment.
- Alert includes workflow name, failed node, execution ID, execution URL, timestamp, and first useful error message.
- Alert goes to the client's chosen manager channel, with Gmail as baseline and Telegram optional.
- Error workflow must be tested by deliberately failing a disposable smoke workflow.

### Retry And Backoff

- Model extraction calls: 3 attempts with exponential backoff and clear final failure handling.
- Email sends: 3 attempts with exponential backoff before dead-lettering.
- Source PDF writes: retry transient filesystem errors, then dead-letter with source metadata.
- Never retry an unsafe duplicate insert without checking idempotency first.

### Dead Letter Queue

Add a visible failure queue before production. Minimum fields:

- `dead_letter_id`
- `source`
- `source_ref`
- `message_id`
- `attachment_hash`
- `workflow_id`
- `execution_id`
- `node_name`
- `error_code`
- `error_message`
- `payload`
- `created_at`
- `resolved_at`
- `resolved_by`
- `resolution_note`

The dashboard or a pgweb/admin view must make unresolved rows easy to find.

### Idempotency

Production intake must key duplicate detection on both:

- email message ID
- attachment hash

Current demo source refs are sufficient for fixture repeatability, but not enough for live mailbox replay, forwarded messages, or Gmail redelivery edge cases.

### Silent Failure Monitoring

This system's worst failure mode is silence. Add:

- Daily heartbeat workflow checking expected workflow executions in the last 24 hours.
- Missed-heartbeat alert with workflow ID, workflow name, last successful execution, and expected cadence.
- Weekly canary certificate emailed into the intake path.
- Canary assertion that a known vendor/certificate record is created or updated.
- Weekly client digest summarizing documents processed, review rows, reminders sent, pending approvals, and unresolved dead letters.
- Uptime monitoring for the dashboard webhook.

### Backup And Restore

Production requires a documented restore test, not just backup creation.

Minimum:

- Daily Postgres dump.
- Offsite backup copy outside the VPS.
- Certificate PDF volume backup.
- Retention window agreed with the client.
- Monthly restore test into a clean database.
- Written restore record with backup timestamp, restore duration, row counts, and any errors.

### Security

- HTTPS only for all public endpoints.
- n8n editor protected by strong authentication.
- Dashboard authenticated before production use.
- Upload form restricted to PDF files and a configured max file size.
- Certificate file storage on an encrypted disk or encrypted cloud volume where available.
- Secrets kept in n8n credentials or host secret storage, not committed files.
- Postgres not exposed on a public port.
- Per-client model spend limit.
- Admin access reviewed when support engagement ends.

### Data Retention

Use the Stage 9 data processing and retention terms as the starting document. Production deployment must set:

- certificate PDF retention period
- extracted-data retention period
- execution-log retention period
- dead-letter retention period
- export process
- deletion process after termination

Default recommendation: retain certificate PDFs and extracted certificate facts for 24 months unless the client chooses otherwise.

### Client Onboarding

Use the Stage 9 onboarding checklist before any production go-live:

- vendor import
- accepted holder entities
- trade requirements
- mailbox/OAuth setup
- approver list
- approval training
- test certificate run
- dashboard review
- backup test
- exit/export plan

## Acceptance Tests Before Client Reliance

Production is not accepted until all of these pass:

| Area | Required Test |
| --- | --- |
| Error alert | Simulated workflow failure sends alert with workflow name and execution link. |
| Idempotency | Duplicate email or attachment replay does not create duplicate active certificate rows. |
| Retry | Simulated transient model/send failure retries and then either succeeds or creates a dead-letter row. |
| Dead letter | Forced unrecoverable failure appears in the visible failure queue. |
| Heartbeat | Disabling or delaying an expected workflow creates a missed-heartbeat alert. |
| Canary | Weekly canary certificate processes end to end and is included in the digest. |
| Digest | Weekly digest sends to the configured client contact with non-misleading counts. |
| Dashboard uptime | Monitor alerts on dashboard webhook failure. |
| Backup | Restore from latest backup into a clean database and compare expected row counts. |
| Scope | Client receives and accepts the limitations document. |
| Export | Client can receive workflow JSON, database dump, and certificate file archive on termination. |

## Explicit Non-Goals

- Enterprise compliance assurance.
- Endorsement interpretation.
- Live carrier or agency management system checks.
- Buildium/Rentec/Rent Manager/Propertyware write-back.
- SMS unless registered under the client's own legal entity and approved A2P campaign.
- Shared multi-tenant SaaS packaging without a written licensing decision.

## Go/No-Go Gate

Before the first paying production go-live, complete these items:

- Production hosting decision recorded.
- Current n8n license position reviewed for the chosen hosting model.
- Current model API terms reviewed for retention and training language.
- Error trigger, retry, dead letter, heartbeat, canary, digest, uptime, backup, and restore tests pass.
- Client signs or accepts the scope and data terms.
- Client receives onboarding checklist and one-page user runbook.
- Demo-only unauthenticated surfaces are removed or protected.
