# Stage 1 Local Runbook

This stage creates only the local n8n and Postgres environment. It does not add COI tables, fixture PDFs, extraction prompts, business workflows, dashboard HTML, or outreach logic.

## Prerequisites

- Docker Desktop or Docker Engine with Docker Compose.
- Local Docker images already available:
  - `n8nio/n8n:latest`
  - `postgres:16`
- Browser access to `http://localhost:5678`.
- OpenAI account for a later n8n credential smoke test.
- Gmail or Google Workspace account for a later n8n OAuth smoke test.

## Start The Local Stack

From the repository root:

```powershell
.\scripts\init-env.ps1
docker compose config
.\scripts\start-local.ps1
.\scripts\verify-local.ps1
```

Open n8n at:

```text
http://localhost:5678
```

On first launch, create the local n8n owner account in the browser. This account is local to the Docker volume.

## Environment Defaults

The generated `.env` keeps callbacks local to this computer:

```text
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678
N8N_EDITOR_BASE_URL=http://localhost:5678
GENERIC_TIMEZONE=America/New_York
```

Use these settings only for same-machine testing. Approval links opened on another device will not reach this n8n instance because `localhost` points to that device, not this computer.

## Postgres Credential In n8n

Create an n8n Postgres credential with:

```text
Host: postgres
Port: 5432
Database: vendor_coi
User: vendor_coi
Password: value from .env POSTGRES_PASSWORD
SSL: disabled
```

Use the n8n credential test button. Stage 1 does not create project tables.

## OpenAI Credential In n8n

Create an OpenAI API credential inside n8n. Do not store the API key in `.env` or workflow JSON.

Before testing, set a hard spend limit of `$10` in the OpenAI dashboard. For later workflow stages, prefer pinned model `gpt-5.6-luna` if available and fall back to `gpt-5.6-terra`. Do not use the floating `gpt-5.6` alias.

For Stage 1, the smoke test is a trivial OpenAI node request from n8n. Do not build extraction prompts or COI workflows yet.

## Gmail Credential In n8n

Create the Gmail OAuth credential in n8n using the demo Gmail or Google Workspace mailbox. For Stage 1, only test that OAuth completes and that a simple send or approval email can be exercised from this same machine.

Gmail approval links should be opened in a browser on this computer during local-only testing.

## Optional Telegram

Telegram is not configured in Stage 1. Keep it optional for later manager alerts or prospects who already use Telegram.

## Local Webhook Smoke Test

If a trivial webhook check is needed, create a temporary n8n workflow manually:

1. Add a Webhook trigger node with method `GET`.
2. Add a Respond to Webhook node returning a short text response.
3. Execute the workflow in test mode.
4. Open the test URL from this computer.

The URL should start with:

```text
http://localhost:5678/webhook-test/
```

Delete or leave the temporary workflow inactive after the check. It is not part of the COI implementation.

## Stop The Stack

```powershell
.\scripts\stop-local.ps1
```

To preserve the local n8n and Postgres data, do not remove Docker volumes.
