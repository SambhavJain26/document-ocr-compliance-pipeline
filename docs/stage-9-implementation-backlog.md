# Stage 9 Implementation Backlog

These are production features to build after the demo flow is accepted and before a paying client relies on the system.

## P0 Before First Client

| Item | Owner | Acceptance |
| --- | --- | --- |
| Client-owned hosting template | Operator | New client deployment can be created without sharing n8n/Postgres state with another client. |
| HTTPS and protected n8n editor | Operator | Public n8n editor is not accessible without authentication. |
| Error Trigger workflow | Operator | Simulated workflow failure sends alert with execution link. |
| Dead-letter table | Operator | Forced intake failure creates unresolved visible row. |
| Idempotency by message ID and attachment hash | Operator | Duplicate email replay creates no duplicate active certificate row. |
| Model retry/backoff | Operator | Transient model failure retries and then succeeds or dead-letters. |
| Gmail retry/backoff | Operator | Transient send failure retries and then succeeds or dead-letters. |
| Heartbeat workflow | Operator | Missed execution window alerts. |
| Backup and restore | Operator | Latest backup restores into clean DB with expected row counts. |
| Scope/data/onboarding docs signed off | Operator/client | Client accepts documents before live vendor chasing. |

## P1 First Month

| Item | Owner | Acceptance |
| --- | --- | --- |
| Weekly canary certificate | Operator | Canary appears in processed rows and reports failure when broken. |
| Weekly digest | Operator | Client receives counts for processed documents, reminders, reviews, and dead letters. |
| Dashboard authentication | Operator | Dashboard no longer has anonymous production access. |
| Uptime monitor | Operator | Dashboard outage creates alert. |
| Vendor alias table | Operator/client | Known alias maps to intended vendor without creating a new vendor. |
| Admin review view | Operator | Unresolved review/dead-letter rows are visible without raw SQL. |

## P2 After Operational Learning

| Item | Owner | Acceptance |
| --- | --- | --- |
| ZIP attachment handling | Operator | Email ZIP can be unpacked and PDF attachments processed safely. |
| Embedded image handling | Operator | Email-body certificate images route to review or extraction path. |
| Batch historical backfill tooling | Operator | Client certificate folder can be loaded with a summary report. |
| Multi-property holder mapping | Operator/client | Certificate holder can be matched per property or owner entity. |
| Owner-facing monthly report | Operator/client | Client can export factual paperwork status report without coverage claims. |

## Deferred Unless Client Registers It

- SMS alerts or reminders.
- PMS write-back.
- Live carrier policy checks.
- Endorsement interpretation.
- Shared multi-tenant SaaS packaging.
