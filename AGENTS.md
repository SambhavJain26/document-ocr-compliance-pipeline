# Repository Guidelines

## Project Structure & Module Organization

This repository is currently an implementation blueprint. Start with `PROGRESS.md`, then read `docs/00-index-and-conventions.md`. Build stages run in order from `docs/01-*` through `docs/10-*`; decisions and n8n guidance live in `docs/11-*` and `docs/12-*`.

The planned layout is authoritative: infrastructure in `infra/`, SQL in `db/`, schemas and prompts in `extraction/`, Code-node sources and workflow exports in `n8n/`, certificate tooling in `fixtures/`, and checks in `test/`. Generated PDFs belong in gitignored `fixtures/out/`.

## Build, Test, and Development Commands

The `Makefile` is introduced during Stage 0; until it exists, these commands describe the required interface rather than runnable tooling.

- `make doctor`: validate the local toolchain and configuration.
- `make up`: start local PostgreSQL and n8n with Docker Compose.
- `make infra-verify`: verify service health, database separation, and network exposure.
- `make credentials-import`: import the OpenAI and PostgreSQL n8n credentials from `.env`.
- `make credentials-verify`: confirm those credentials are encrypted, owner-visible, and leave no plaintext container file.
- `make db-apply && make db-seed && make db-verify`: migrate, seed, and verify the database.
- `make fixtures`: regenerate all synthetic certificate fixtures.
- `make test-extract`: run JavaScript validation tests and extraction smoke tests.
- `make test-fixtures`: run the 20-fixture acceptance set.
- `make test-forbidden`: scan user-facing output for prohibited coverage claims.
- `make test-all`: run the complete verification suite.

## Coding Style & Naming Conventions

Follow `docs/00-index-and-conventions.md`. Use `snake_case` for SQL identifiers, `SCREAMING_SNAKE` for statuses and flags, `NN_purpose.js` for Code-node files, and `kebab-case` for Make targets. Name n8n nodes `Title Case — Purpose` and workflows `COI · <n> · <Name>`. Keep certificate dates as PostgreSQL `DATE`, compute "today" in the client timezone, and display dates as `14 Mar 2027`. Prefer small, testable JavaScript modules.

## Testing Guidelines

Use Node's built-in `node --test` for `test/unit/test_*.js`; acceptance data lives in `test/expected.json` and is driven by `test/run_fixtures.py`. Add a regression case for every validation or workflow bug. A change is complete only when its stage gate in `PROGRESS.md` passes. Never weaken the forbidden-word test: the product reports document and date facts, never insurance conclusions.

## Commit & Pull Request Guidelines

Use concise, imperative subjects with a scope when useful, for example `db: add expiry bucket view`. Keep commits stage-focused. Pull requests should identify the blueprint stage, summarize behavior and schema changes, list commands run, link relevant issues or decision-log entries, and include dashboard screenshots for visual changes. Never commit `.env`, credential values, client documents, or plaintext n8n credential files.

## Task Completion & Knowledge Capture

At the end of every task:

1. Re-read this file and update it when repository structure, commands, conventions, or working practices have changed. Remove obsolete guidance instead of accumulating contradictions.
2. Record durable lessons discovered during the task here, including safer approaches, good practices, and corrections prompted by mistakes. Keep entries actionable and repository-specific; put architectural decisions in `docs/11-decision-log.md` and link them here when needed.
3. Run the relevant checks, inspect the final diff for secrets and unrelated edits, then commit and push the completed task to the `main` branch. Do not leave finished work only in the local checkout.

## Docker Safety

Inspect local images before starting services, for example with `docker image ls`. If the exact required image and tag already exist, reuse that image and do not pull it again. This repository's Compose project must use its own uniquely named containers, networks, and volumes. Never stop, remove, recreate, rename, or reconfigure containers belonging to another project. A shared image may be reused; another project's container or persistent volume may not.

On Windows, run repository shell scripts with Git Bash when WSL has no Linux distribution. Host `psql`, `jq`, and `dig` may be absent: prefer the project's PostgreSQL container for SQL, Python's `json.tool` for JSON, and Python socket resolution for the Stage 0 DNS check. Do not install duplicate system tools when an existing, scoped equivalent satisfies the task.

Keep Python dependencies isolated in `fixtures/.venv`; `doctor.sh` detects that environment without requiring manual activation. Commit only `fixtures/requirements.txt`, never the virtual environment.

Preserve LF endings for shell scripts and `Makefile` through `.gitattributes`; CRLF can break scripts when they reach the Ubuntu deployment host. All Compose commands must retain the explicit `vendor-coi-chasing` project name so `down` and `restart` cannot target another project's resources.

Every Compose command must also pass `--env-file .env`. Because the Compose file lives under `infra/`, relying on automatic discovery can load no root environment and initialize PostgreSQL with blank values. If first initialization fails, inspect labels/names, then remove only the newly created `vendor-coi-chasing` volumes before retrying; Postgres init scripts do not rerun on a non-empty volume.

This project uses JavaScript Code nodes only. Set `N8N_PYTHON_ENABLED=false` and do not set the obsolete `N8N_RUNNERS_ENABLED` variable; n8n 2.29 starts its JavaScript runner automatically. The image still performs one Python availability probe and logs one missing-Python warning at startup—accept only that exact warning while the log also confirms `Registered runner "JS Task Runner"`. Apply environment changes with `compose up -d`, which recreates the target service, rather than `restart`, which retains the old environment.

Docker retains a container's earlier restart logs. When validating one expected n8n startup warning, inspect logs only since the current container `StartedAt` timestamp; never count the complete retained log.

The demo defaults to `DEPLOYMENT_MODE=local` at `http://localhost:5678`; Caddy, public DNS, and `ACME_EMAIL` are production-only. Keep `N8N_SECURE_COOKIE=false` confined to local HTTP and restore it to `true` for HTTPS. Current n8n uses its built-in owner account—do not reintroduce the removed `N8N_BASIC_AUTH_*` variables. See Decision D-29.

Credential imports must use `--projectId` for the owner's personal project or n8n will not expose them in the UI. On Git Bash, prefix Docker commands that carry container paths such as `/tmp/...` with `MSYS_NO_PATHCONV=1`; otherwise Windows rewrites the path before n8n sees it. `docker compose cp` creates a root-owned file in the container, so remove it as root in an exit trap. Keep the plaintext JSON only in an OS temp directory, never in the repository.

The managed OpenAI HTTP credential is named `OpenAI — Header Auth (Managed)` to avoid colliding with user-created n8n credentials. Importers must accept a correct partial state and add only the missing managed credential; never overwrite a user credential that merely has a similar name.
