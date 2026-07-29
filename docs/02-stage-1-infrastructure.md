# Stage 1 — Infrastructure

**Document 02 · Estimated time: 2–4 hours · Cost: ~$5/mo**

Three containers behind TLS, with n8n configured so that the send-and-wait approval links resolve publicly. That last part is the whole point of this stage — get it wrong and the demo's best moment 404s in front of a prospect.

**Gate:** a webhook URL created in n8n loads from your phone on **mobile data**, not wifi.

> **Local demo override (D-29).** The current build deliberately stops at
> `http://localhost:5678`: PostgreSQL and n8n must be healthy, both databases
> must exist, n8n data must survive a restart, and PostgreSQL must publish no
> host port. Caddy, ACME, public webhooks, phone testing, and backup cron remain
> production gates. The checked-in `infra/docker-compose.yml` is authoritative
> for local work; the public-TLS configuration below is the production target.

---

## 1.1 What you are building

```
                    Internet
                       │
                       │ :443 (TLS, auto-renewed)
                       ▼
             ┌──────────────────┐
             │      Caddy       │   reverse proxy + ACME
             │  n8n.domain.com  │
             └────────┬─────────┘
                      │ internal HTTP
                      ▼
    ┌─────────────────────────────────────────┐
    │              coi-net (bridge)           │
    │                                         │
    │   ┌──────────┐        ┌──────────────┐  │
    │   │   n8n    │───────▶│  postgres:16 │  │
    │   │  :5678   │        │    :5432     │  │
    │   └────┬─────┘        └──────┬───────┘  │
    │        │                     │          │
    └────────┼─────────────────────┼──────────┘
             │                     │
        ┌────▼─────┐         ┌─────▼──────┐
        │ n8n_data │         │  pg_data   │   named volumes
        │ certs    │         └────────────┘
        └──────────┘
```

**Two Postgres roles, one instance.** n8n stores its own workflow/execution data in database `n8n`; the COI application data lives in database `coi`. Same server, separate databases, separate users. This matters: `make demo-reset` truncates COI tables, and you do not want a mistyped database name to wipe your workflows mid-call.

---

## 1.2 `infra/docker-compose.yml`

```yaml
name: vendor-coi-chasing

services:
  # ───────────────────────────────────────────────────────────────
  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      # Postgres always runs UTC. Client timezone is applied in queries.
      TZ: UTC
      PGTZ: UTC
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./initdb:/docker-entrypoint-initdb.d:ro
    networks:
      - coi-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s
    # NOTE: no `ports:` stanza. Postgres is unreachable from the internet.
    #       Use an SSH tunnel for local psql access.

  # ───────────────────────────────────────────────────────────────
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      # ── Public addressing. All three must be the public HTTPS host. ──
      N8N_HOST: ${N8N_HOST}
      N8N_PORT: 5678
      N8N_PROTOCOL: ${N8N_PROTOCOL}
      WEBHOOK_URL: ${WEBHOOK_URL}
      N8N_EDITOR_BASE_URL: ${N8N_EDITOR_BASE_URL}
      N8N_PROXY_HOPS: 1

      # ── Time ──
      GENERIC_TIMEZONE: ${GENERIC_TIMEZONE}
      TZ: ${GENERIC_TIMEZONE}

      # ── Security ──
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      N8N_SECURE_COOKIE: "true"
      N8N_BLOCK_ENV_ACCESS_IN_NODE: "true"

      # ── n8n's own persistence ──
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}

      # ── Execution hygiene ──
      EXECUTIONS_DATA_SAVE_ON_SUCCESS: all
      EXECUTIONS_DATA_SAVE_ON_ERROR: all
      EXECUTIONS_DATA_SAVE_ON_PROGRESS: "true"
      EXECUTIONS_DATA_PRUNE: "true"
      EXECUTIONS_DATA_MAX_AGE: 336          # hours = 14 days
      N8N_DEFAULT_BINARY_DATA_MODE: filesystem

      # ── Misc ──
      N8N_DIAGNOSTICS_ENABLED: "false"
      N8N_VERSION_NOTIFICATIONS_ENABLED: "false"
      N8N_PERSONALIZATION_ENABLED: "false"
      N8N_PYTHON_ENABLED: "false"       # this project uses JavaScript Code nodes only
      NODE_OPTIONS: "--max-old-space-size=1536"
    volumes:
      - n8n_data:/home/node/.n8n
      - certs_data:/data/certs          # retained certificate PDFs
    networks:
      - coi-net
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  # ───────────────────────────────────────────────────────────────
  caddy:
    image: caddy:2
    restart: unless-stopped
    depends_on:
      - n8n
    ports:
      - "80:80"
      - "443:443"
    environment:
      N8N_HOST: ${N8N_HOST}
      ACME_EMAIL: ${ACME_EMAIL}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - coi-net

networks:
  coi-net:
    driver: bridge

volumes:
  pg_data:
  n8n_data:
  certs_data:
  caddy_data:
  caddy_config:
```

### Non-obvious settings, and why each is there

| Setting | Why it is here |
|---|---|
| `WEBHOOK_URL` **and** `N8N_EDITOR_BASE_URL` | The URL n8n displays and uses for OAuth callbacks and send-and-wait resume links is `{base}/rest/oauth2-credential/callback`, where `{base}` comes from `UrlService.getInstanceBaseUrl()` — which **falls back to `WEBHOOK_URL` when `N8N_EDITOR_BASE_URL` is unset**. Here `WEBHOOK_URL` is already the public host, so the fallback would work by coincidence. Set both explicitly anyway, same value, trailing slash. **Relying on a coincidence is how the approval button 404s the day you change something unrelated.** |
| `N8N_PROXY_HOPS: 1` | Caddy sits in front. Without this n8n sees Caddy's container IP as the client, which breaks rate limiting and logs. |
| `N8N_SECURE_COOKIE: "true"` | Safe because you are behind TLS. If you ever test over plain HTTP the editor will refuse to log in — that is the setting, not a bug. |
| `N8N_BLOCK_ENV_ACCESS_IN_NODE: "true"` | Stops a Code node reading `process.env` and printing your OpenAI key into an execution log a prospect might see over your shoulder. |
| `N8N_DEFAULT_BINARY_DATA_MODE: filesystem` | PDFs move through workflows as binary. In the default `default` mode they are base64'd into the execution record in Postgres, which bloats the DB and slows the editor exactly when you are demoing. |
| `EXECUTIONS_DATA_MAX_AGE: 336` | 14 days of history. Enough to debug, not enough to fill the disk. |
| `NODE_OPTIONS: --max-old-space-size=1536` | On a 4GB box, caps n8n so a large binary payload cannot OOM Postgres alongside it. |
| `TZ: UTC` on Postgres, `TZ: ${GENERIC_TIMEZONE}` on n8n | Deliberate asymmetry. Storage is UTC; scheduling is local. See [Stage 2 §2.7](03-stage-2-data-layer.md) for how day counts are computed. |
| No `ports:` on postgres | The database has no route from the internet. This is an architecture decision, not an oversight. |

---

## 1.3 `infra/Caddyfile`

```caddyfile
{
	email {$ACME_EMAIL}
	# Uncomment while testing to avoid Let's Encrypt rate limits:
	# acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}

{$N8N_HOST} {
	encode zstd gzip

	# n8n streams execution data over SSE; disable buffering and allow long waits.
	reverse_proxy n8n:5678 {
		flush_interval -1
		transport http {
			read_timeout 300s
			write_timeout 300s
		}
	}

	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		X-Content-Type-Options "nosniff"
		X-Frame-Options "SAMEORIGIN"
		Referrer-Policy "no-referrer-when-downgrade"
		-Server
	}

	log {
		output file /data/access.log {
			roll_size 10MiB
			roll_keep 5
		}
		format json
	}
}
```

`flush_interval -1` disables response buffering. Without it, n8n's editor UI hangs while a long workflow runs — which is when you are most likely to be watching it.

---

## 1.4 The Postgres init script

Compose mounts `infra/initdb/`. Anything there runs **once**, on first boot, when the data volume is empty.

`infra/initdb/01-databases.sql`:

```sql
-- Two databases on one server.
-- `n8n` holds n8n's own workflow and execution data.
-- `coi`  holds the application data. Created by POSTGRES_DB already.
--
-- Separating them means `make demo-reset` can never touch your workflows.

CREATE DATABASE n8n;

-- Read-only role for ad-hoc inspection during a demo, so you can open a SQL
-- client on screen without any chance of a typo mutating state.
CREATE ROLE coi_readonly LOGIN PASSWORD 'readonly_change_me';
GRANT CONNECT ON DATABASE coi TO coi_readonly;
```

`infra/initdb/02-readonly-grants.sql`:

```sql
\connect coi

GRANT USAGE ON SCHEMA public TO coi_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO coi_readonly;
```

> **If you have already booted the stack before adding these**, the init directory will not re-run. Either `docker compose down -v` (destroys all data — fine at this stage) or apply the SQL by hand with `make db-shell`.

---

## 1.5 Bring it up

> ### Stop — pin `N8N_ENCRYPTION_KEY` before the first `up`
>
> If the `n8n_data` volume does not yet exist and the key is unset, **n8n auto-generates one and writes it into the volume.** Setting the env var afterwards is silently ignored — n8n keeps using the generated key, and every credential you later import is encrypted with a key you have no copy of.
>
> ```bash
> grep -q '^N8N_ENCRYPTION_KEY=[0-9a-f]\{64\}$' .env || { echo "SET IT FIRST"; exit 1; }
> ```
>
> If you have already booted without it: `docker compose down -v` and start again. That is cheap now and expensive after Stage 5.

```bash
cd /opt/coi                      # wherever you cloned the repo on the VPS
cp .env.example .env             # then fill it in properly
mkdir -p infra/initdb            # place the two SQL files

make up
make logs                        # watch until quiet
```

> ### Adding a new env var needs `up -d`, not `restart`
>
> `docker compose restart n8n` re-runs the **existing** container with its **existing** environment. A newly added variable has no effect, and the symptom — nothing changed — reads as "that setting does nothing" rather than "the container never saw it".
>
> Changing a value of an existing variable: `restart` is fine. Adding a variable that was not there before: `docker compose -f infra/docker-compose.yml up -d n8n`.

Verify each service independently:

```bash
docker compose -f infra/docker-compose.yml ps
# All three should read "running", postgres and n8n "(healthy)".

# Postgres reachable inside the network:
docker compose -f infra/docker-compose.yml exec postgres \
  psql -U coi -d coi -c "SELECT version();"

# n8n answering internally:
docker compose -f infra/docker-compose.yml exec n8n \
  wget -qO- http://localhost:5678/healthz

# TLS working from outside:
curl -sI https://n8n.yourdomain.com | head -n 1
# Expect: HTTP/2 200
```

**If Caddy cannot get a certificate:** the near-universal cause is DNS not yet resolving, or port 80 blocked. Check `docker compose logs caddy`. Let's Encrypt rate-limits five failures per hostname per hour — if you burn through them, uncomment the `acme_ca` staging line in the Caddyfile, get it working, then comment it back out and `docker compose restart caddy`.

---

## 1.6 First login and OAuth redirect

1. Open `http://localhost:5678` for the local demo, or the HTTPS hostname in production. n8n shows its built-in owner-account setup.
2. Create the owner account. Use a real address — n8n emails password resets there.
3. **Go back to Google Cloud Console** → Credentials → your `n8n-gmail` OAuth client → set the authorised redirect URI to exactly:

```
https://n8n.yourdomain.com/rest/oauth2-credential/callback
```

No trailing slash. Exact scheme and host. Save.

---

## 1.7 Create the four credentials

In n8n → **Credentials → Add credential**. Create all four now so no stage stalls on a missing credential.

### 1.7.1 `OpenAI Account`

Type: **OpenAI API**

| Field | Value |
|---|---|
| Name | `OpenAI Account` |
| API Key | your OpenAI project key |

Every model call uses an HTTP Request node for exact Responses API payload control. Configure its authentication as **Predefined Credential Type → OpenAI API → OpenAI Account**. Do not create a duplicate generic Header Auth credential.

### 1.7.2 `Postgres — COI`

Type: **Postgres**

| Field | Value |
|---|---|
| Host | `postgres` |
| Database | `coi` |
| User | `coi` |
| Password | from `.env` |
| Port | `5432` |
| SSL | `Disable` |

`postgres` is the Docker service name and resolves on `coi-net`. Never `localhost` — inside the n8n container that is n8n itself.

### 1.7.3 `Gmail account`

Type: **Gmail OAuth2 API**

1. Paste Client ID and Client Secret from `.env`.
2. Click **Sign in with Google**.
3. Choose the account that owns the `COI-INTAKE` label.
4. Click through the "Google hasn't verified this app" interstitial → **Advanced** → **Go to COI Automation (unsafe)**. This is your own app; the warning is expected.
5. Grant. n8n shows **Account connected**.

**Verify immediately** — do not assume. Create a scratch workflow: Manual Trigger → Gmail (Get Many, limit 1). Execute. If it returns a message, OAuth works.

### 1.7.4 `Telegram — COI` *(optional)*

Type: **Telegram API** · Access Token: your BotFather token.

---

## 1.8 The gate — verify public webhook reachability

**This is the most important verification in the entire build.** n8n's send-and-wait approval buttons resolve against the URL n8n believes it lives at. If that is wrong, the button 404s, and you will discover it in front of a prospect.

### The test

1. New workflow → add a **Webhook** node.
2. HTTP Method `GET`, Path `stage1-check`, Respond `Immediately`.
3. Add a **Respond to Webhook** node → Respond With `Text` → Response Body `stage1 ok`.
4. **Save and activate the workflow.** Copy the **Production URL** (not the Test URL).

It must read exactly:

```
https://n8n.yourdomain.com/webhook/stage1-check
```

**If it says `localhost`, `0.0.0.0`, or `http://`, stop.** Fix `WEBHOOK_URL` and `N8N_EDITOR_BASE_URL` in `.env`, then `make down && make up`. n8n reads these only at boot.

### The part people skip

```bash
# From your workstation:
curl -s https://n8n.yourdomain.com/webhook/stage1-check
# Expect: stage1 ok
```

Then — and this is the step that actually matters — **open that URL on your phone with wifi turned off, on mobile data.**

Your workstation may resolve the hostname through a local DNS cache, a VPN, or an `/etc/hosts` entry you added and forgot. Your phone on a cellular network resolves it the way a prospect's phone will. If it loads there, the approval button will work on the call.

Now delete the scratch workflow.

### Second gate: the send-and-wait link itself

Reachability is necessary but not sufficient — send-and-wait builds its resume URL from a different code path than the Webhook node's display URL. Test it directly:

1. New workflow: **Manual Trigger** → **Gmail** node.
2. Operation: **Send and Wait for Response**
   - To: your own address
   - Subject: `stage1 approval check`
   - Message: `Tap approve.`
   - Response Type: **Approval**
   - Type of Approval: **Approve and Disapprove**
3. Execute. Open the email **on your phone, on mobile data**.
4. Inspect the Approve link before tapping. It must start `https://n8n.yourdomain.com/webhook-waiting/`.
5. Tap Approve. n8n shows a confirmation page; the workflow execution completes.

**Only when both of those pass is Stage 1 done.** Record the date you verified this in `PROGRESS.md` — you will re-verify before every demo.

---

## 1.9 Backups

Two minutes now, and it is the difference between a bad hour and a lost week.

```bash
sudo tee /etc/cron.daily/coi-backup >/dev/null <<'EOF'
#!/bin/sh
cd /opt/coi || exit 1
mkdir -p /opt/coi/backups
docker compose -f infra/docker-compose.yml exec -T postgres \
  pg_dumpall -U coi | gzip > "/opt/coi/backups/all-$(date +%F).sql.gz"
find /opt/coi/backups -name 'all-*.sql.gz' -mtime +14 -delete
EOF
sudo chmod +x /etc/cron.daily/coi-backup
sudo /etc/cron.daily/coi-backup    # run once now
ls -lh /opt/coi/backups/
```

`pg_dumpall` captures both databases — the COI data and your n8n workflows.

**Test the restore once.** An untested backup is a belief, not a backup:

```bash
gunzip -c backups/all-YYYY-MM-DD.sql.gz | head -n 40
```

You should see `CREATE ROLE` and `CREATE DATABASE` statements. That is enough proof at this stage.

---

## 1.10 Operational reference

| Task | Command |
|---|---|
| Start / stop | `make up` / `make down` |
| Tail logs | `make logs` |
| Restart n8n only | `make restart` |
| psql shell | `make db-shell` |
| Local psql over tunnel | `ssh -L 5433:localhost:5432 root@VPS` then `psql -h localhost -p 5433 -U coi coi` |
| Update n8n | `docker compose -f infra/docker-compose.yml pull n8n && make up` |
| Disk usage | `docker system df` |
| Reclaim space | `docker system prune -a --volumes` ⚠️ **destroys volumes — never run casually** |

> **Pin the n8n image before a client engagement.** `:latest` is fine while building; it is not fine when a client depends on it. Change to `docker.n8n.io/n8nio/n8n:1.<minor>.<patch>` and upgrade deliberately.

---

## Stage 1 exit checklist

- [ ] `docker compose ps` shows postgres, n8n, caddy all running; postgres and n8n healthy
- [ ] `https://n8n.yourdomain.com` serves a valid certificate (no browser warning)
- [ ] Databases `coi` and `n8n` both exist
- [ ] Postgres has **no** published port
- [ ] All four credentials created; Gmail verified by an actual API call
- [ ] Google OAuth redirect URI updated to the real host
- [ ] Webhook production URL shows the public HTTPS hostname
- [ ] **Webhook URL loads on a phone over mobile data**
- [ ] **Send-and-wait approval email received on the phone, link starts `https://n8n.yourdomain.com/webhook-waiting/`, tapping Approve resumes the execution**
- [ ] Daily backup cron installed and one dump exists
- [ ] `N8N_ENCRYPTION_KEY` is in a password manager

→ Continue to [Stage 2 — Data layer](03-stage-2-data-layer.md)
