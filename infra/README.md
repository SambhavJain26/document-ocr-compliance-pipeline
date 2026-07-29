# Local Infrastructure

The demo stack contains two isolated services:

- `postgres:16` for both the `coi` application database and separate `n8n` database.
- `n8nio/n8n:latest` for the workflow runtime and editor.

Both images must already exist locally; Compose uses `pull_policy: never`. The
project name is fixed to `vendor-coi-chasing`, so its containers, network, and
volumes cannot overlap with another Compose project.

n8n is bound to `127.0.0.1:5678` and PostgreSQL publishes no host port. Start
the stack with:

```bash
docker compose --project-name vendor-coi-chasing \
  --env-file .env -f infra/docker-compose.yml up -d
```

Open `http://localhost:5678` and create the built-in owner account on first
launch. Stop only this stack with `make down` or the equivalent Compose command.
Do not add `-v` unless intentionally deleting this project's local databases and
n8n credentials.

Run `make infra-verify` on a system with GNU Make, or
`"C:\Program Files\Git\bin\bash.exe" infra/verify.sh` on this Windows
workstation, to repeat the local Stage 1 gate.

Caddy, public DNS, HTTPS, and mobile-data webhook verification are deferred to
the production deployment described by Decision D-29.
