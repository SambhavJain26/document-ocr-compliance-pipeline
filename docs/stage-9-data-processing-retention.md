# Stage 9 Data Processing And Retention Terms

This is a production starting point, not legal advice. Review current vendor terms and adapt it before a paying client signs.

## Data Processed

The system processes vendor certificate paperwork and related operational metadata:

- vendor names and business contact details
- producer or insurance agent contact details
- insurer names
- policy numbers
- certificate dates
- coverage line dates and limits
- certificate holder text
- source certificate PDFs
- intake email metadata
- reminder draft text
- approval and send logs
- workflow execution metadata

The system is not intended to process tenant data, consumer personal information, W-9s, bank details, claim files, medical information, or employment records.

## Subprocessors And Systems

Production deployment normally uses:

- client-owned or client-controlled VPS/cloud host
- n8n for workflow orchestration
- Postgres for durable state
- Gmail or Google Workspace for intake, approval, and outbound email
- OpenAI API for certificate extraction and draft generation
- optional Telegram for operational alerts
- backup storage selected with the client

Before production, verify current terms for each subprocesser, especially model API data-use and retention terms.

## Storage Locations

Record for each client:

- VPS/cloud provider and region
- Postgres host
- certificate PDF storage path or volume
- backup destination and region
- n8n workspace URL
- dashboard URL

## Retention Defaults

Recommended defaults:

| Data | Default Retention |
| --- | --- |
| Source certificate PDFs | 24 months |
| Extracted certificate facts | 24 months |
| Outreach logs | 24 months |
| Intake notices | 24 months |
| Dead-letter rows | Until resolved plus 12 months |
| n8n execution logs | 30 to 90 days, based on operational need |
| Database backups | 30 daily backups plus 12 monthly backups |

The client can choose a shorter or longer retention period in writing.

## Deletion And Export

On termination or written request:

- export n8n workflow JSON
- export Postgres database dump
- export source certificate PDFs
- provide a plain CSV export of vendors, certificates, coverages, notices, and outreach logs when requested
- delete remaining hosted copies after a written confirmation window
- retain only records required for billing, dispute handling, or legal compliance

## Security Baseline

- Use HTTPS for external endpoints.
- Keep n8n credentials inside n8n or a secret manager.
- Do not commit secrets or real certificate PDFs to Git.
- Keep Postgres off the public internet.
- Restrict dashboard and upload access before production.
- Use per-client API keys where practical.
- Configure model spend limits.
- Remove operator access when support ends.

## Incident Handling

If a data incident or operational failure is suspected:

- pause affected workflows if continued processing could worsen the issue
- preserve relevant execution logs
- notify the client contact with facts known so far
- identify affected records
- document remediation and recurrence prevention
- record whether any third-party support or vendor notification is required
