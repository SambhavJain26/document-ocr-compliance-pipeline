# Stage 2 Database Runbook

Stage 2 creates the COI demo project tables and synthetic seed data. It does not process PDFs, create fixtures, import n8n workflows, build extraction prompts, render a dashboard, or send chase emails.

## Prerequisites

- Stage 1 local stack is running.
- n8n is reachable at `http://localhost:5678`.
- Postgres is healthy in Docker Compose.

Verify the local stack first:

```powershell
.\scripts\verify-local.ps1
```

## Apply Schema And Seed

From the repository root:

```powershell
.\scripts\apply-stage-2.ps1
```

This applies:

- `db/postgres/001-schema.sql`
- `db/postgres/002-seed.sql`

The SQL is idempotent for the Stage 2 seed set, so rerunning the script updates the seeded configuration and vendor rows without creating duplicates.

## Verify Stage 2

```powershell
.\scripts\verify-stage-2.ps1
```

The verifier checks:

- all seven project tables exist;
- expected `client_config` keys are present;
- `model_id=gpt-5.4-nano` and `model_id_fallback=gpt-5.6-luna`;
- exactly one primary holder entity exists;
- default, Roofing, and Landscaping trade requirements exist;
- default trade fallback values are present;
- exactly 18 synthetic vendors exist;
- vendor names normalize deterministically and uniquely;
- at least one vendor is `wc_exempt=true`;
- `certificates`, `coverages`, and `outreach_log` are empty.

## Seed Data Notes

The seed uses synthetic Harbourline demo data only. Email addresses use `example.test` and are not real delivery targets. The vendor register starts populated with names and contact metadata, but has no certificate records.

Do not add real vendor documents, real client names, extraction prompts, or workflow exports in Stage 2.
