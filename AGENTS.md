# Repository Guidelines

This repository is the planning and implementation workspace for a local n8n vendor certificate-of-insurance (COI) chasing demo. Treat it as an automation project, not a compiled app. The core behavior will live in n8n workflow exports, Postgres schema/state, fixtures, and small helper scripts.

## Read Order And Authority

Read these files before changing scope or implementation details:

1. `build-plan.md`: staged plan to follow across sessions.
2. `progress-notes.md`: current status, completed stages, deviations, and open items.
3. `coi-demo-build-plan.md`: detailed controlling implementation spec.
4. `01-vendor-coi-chase.md`: validated problem and architecture rationale.
5. `foundation-1-vendor-insurance.md`: domain background only.

If documents conflict, prefer the newest decision recorded in `progress-notes.md`, then update the stale document instead of silently guessing.

## Project Structure

Current files are documentation-only. Expected implementation directories:

- `workflows/` or `n8n-workflows/`: importable n8n workflow JSON exports.
- `db/postgres/`: schema, migrations, seed SQL, and reset SQL.
- `scripts/`: local setup, import, reset, validation, and fixture helpers.
- `fixtures/`: synthetic COI PDFs, email payloads, and expected outputs.
- `docs/`: runbooks, prompt schemas, demo notes, and production caveats.

Use lowercase hyphenated filenames. Use `snake_case` for database columns and JSON fields unless an external API requires otherwise.

## Local Services And Commands

There is no runnable app yet. Until scripts exist, use:

- `rg --files`: list repository files.
- `git status --short`: check the worktree before edits.
- `git diff -- *.md`: review documentation changes.
- `Get-Content -Raw <file>.json | ConvertFrom-Json | Out-Null`: validate workflow JSON once exports exist.
- `docker images`: check available local images before adding or pulling new ones.
- `docker compose ps`: inspect local service status once `docker-compose.yml` exists.
- `docker compose logs n8n`: inspect n8n startup/import/runtime failures once services exist.
- `n8n export:workflow --all --output=n8n-workflows/`: export workflows from a running n8n instance.

Stage 1 local environment commands:

- `.\scripts\init-env.ps1`: generate local `.env` from `.env.example`.
- `docker compose config`: validate Docker Compose configuration.
- `.\scripts\start-local.ps1`: start local n8n and Postgres.
- `.\scripts\verify-local.ps1`: verify Compose config, Postgres readiness/query, and n8n HTTP availability.
- `.\scripts\stop-local.ps1`: stop the local stack without removing volumes.

Expected local services are n8n at `http://localhost:5678` and Postgres on `127.0.0.1:5432`. Gmail/OpenAI credentials are created manually inside n8n and must not be stored in repo files. One Gmail or Google Workspace mailbox is enough for local testing; use plus-address aliases for logical vendor, producer, approval, and intake roles when needed. Do not assume Docker images, accounts, OAuth apps, API keys, or n8n credentials already exist. On first n8n 2.x startup, internal migrations can take long enough for early HTTP probes to fail; rerun `.\scripts\verify-local.ps1` or rely on its retry loop. The `n8nio/n8n:latest` image may log a Python task-runner warning because Python is absent; this is not a Stage 1 blocker when JS workflows and service health pass.

For n8n 2.29 CLI smoke tests, `n8n execute --file` is deprecated and may still require `--id`; import temporary smoke workflows into the local project, execute them by ID, then delete the temporary workflows from n8n.

## Architecture Rules

- n8n orchestrates the workflow; Postgres is durable automation state.
- Do not use n8n Data Tables for core state.
- Gmail Trigger and Gmail nodes are the default email path for the demo.
- IMAP is only a disabled fallback for non-Google inboxes.
- SMTP/Send Email is only a generic fallback; it is not required for the Gmail demo path.
- Use n8n OpenAI node V2 by default for extraction and drafting.
- Use HTTP Request only if the OpenAI node cannot expose the required model, PDF file input, JSON schema output, or error-handling controls.
- Keep Telegram optional. Gmail-based human approval is the default approval path.
- Do not add OCR Bro as the default. Try text extraction first, then use the OpenAI PDF/file path when text is insufficient.

## n8n Workflow Rules

Prefer editable workflow JSON exports over manual-only UI changes. Name every node descriptively; never leave default names like `Code`, `If`, `Set`, or `HTTP Request`.

Use n8n credentials by name only. Never hardcode secrets, bearer tokens, OAuth client secrets, Gmail tokens, or OpenAI keys in workflow JSON.

Known n8n gotchas to account for during implementation:

- Active webhooks may use the active workflow snapshot, not the editor draft.
- After import or activation, verify with a real execution, database row, or validation script before treating the workflow as passed.
- Code nodes may be sandboxed; do not assume `process.env` exists.
- Optional Postgres update/cleanup nodes need `alwaysOutputData` if downstream nodes must continue after zero rows.
- Postgres nodes that update then reselect rows must return every field later expressions use.
- Form Trigger submissions can render fields as `field-0`; normalize form payloads before SQL or AI steps.
- AI structured output may be wrapped under `output`; downstream expressions should handle wrapped and direct JSON shapes.

## Testing And Verification

Validation scripts are the tests once implementation begins. Each stage should include a repeatable verification command and synthetic fixtures before moving on.

Minimum fixture scenarios:

- valid COI with all required coverage.
- expired policy.
- missing endorsement or coverage.
- wrong certificate holder.
- non-certificate attachment.
- low-text/scanned PDF.
- duplicate Gmail message or duplicate attachment replay.

Record completed checks and failures in `progress-notes.md`.

## Security And Configuration

Never commit `.env`, exported credentials, real vendor documents, real client data, Gmail OAuth secrets, OpenAI API keys, or production n8n exports containing secrets. Keep examples placeholder-only.

Before adding or pulling Docker images, check local images first with `docker images`. If a required image is missing, document the need and ask before pulling.

Build reset paths for local demo data only. Never run destructive reset/delete scripts against a client Gmail account, client database, or production workflow.

## Commit And Completion Guidelines

Use short imperative or conventional commits, matching existing history, for example `docs: update COI workflow guidance` or `feat: add intake preflight`.

Before every final response, run the AGENTS maintenance checkpoint: decide whether the task exposed a durable mistake, blocker, workaround, command, gotcha, or best practice. If yes, update `AGENTS.md` first. Keep updates short, remove stale or duplicate wording, and prefer tightening existing rules over appending new sections.

If a task changes commands, scripts, workflow behavior, data model, implementation decisions, or durable repo rules, update the relevant documentation before finishing. Use `progress-notes.md` for stage status, deviations, verification results, and outstanding work. Update `build-plan.md` or `coi-demo-build-plan.md` only when the plan or controlling spec actually changes.

After every completed implementation task, commit and push the changes. If no remote is configured, commit is not requested, or push fails, report that clearly; include the commit hash if a commit was created. For documentation-only planning edits, do not auto-commit unless the user asks.

Pull requests should summarize the stage affected, verification performed, credential/manual steps, and any deviation from `build-plan.md`.
