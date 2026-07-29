# Stage 0 — Prerequisites

**Document 01 · Estimated time: 2–3 hours · Cost: $0 (plus $5/mo VPS from Stage 1)**

Everything in this stage is account setup, credential generation, and repo scaffolding. Nothing here is interesting, and all of it will block you at 11pm the night before a demo if you skip it now.

**Gate:** `make doctor` exits 0.

---

## 0.1 Accounts you need

Create all five before you start Stage 1. Three of them have a delay you cannot compress.

| # | Account | Why | Delay | Cost |
|---|---|---|---|---|
| 1 | **OpenAI Platform** | Extraction and email drafting | Instant, but payment verification can take an hour | Pay-per-token, capped at $10 |
| 2 | **Google Workspace or Gmail** | Intake inbox + sending + approval gate | Instant | $0 (personal) / existing (client) |
| 3 | **Google Cloud Console project** | OAuth client for the Gmail node | 30–60 min the first time | $0 |
| 4 | **VPS provider** (Hetzner recommended) | Hosts n8n + Postgres | Minutes; Hetzner may ID-verify new accounts, which can take a day | ~$5/mo |
| 5 | **Domain or subdomain** | HTTPS hostname for webhooks | DNS propagation 5–60 min | $0–12/yr |
| 6 | *(Optional)* **Telegram** | Bonus approval channel + manager alerts | Instant | $0 |

> **Do the Google Cloud OAuth consent screen first.** It is the only step with a genuine chance of eating an afternoon, and it is the only one that can silently half-work — an unverified consent screen in Testing mode issues refresh tokens that expire in **7 days**. That expiry is exactly the silent failure this product exists to prevent, and it will kill a demo you scheduled for next week. Section 0.4 handles it properly.

---

## 0.2 OpenAI setup

### 0.2.1 Create a scoped project and key

Do not use your default project or a user-level key.

1. OpenAI Platform → **Projects** → **Create project** → name it `coi-demo`.
2. Inside that project → **API keys** → **Create new secret key**.
   - Name: `coi-demo-n8n`
   - Project: `coi-demo`
   - Permissions: **Restricted** → `Model capabilities: Write`. Nothing else. No Files, no Assistants, no Fine-tuning.
3. Copy the key immediately. It is shown once.

### 0.2.2 Set the spend limit — this is the actual budget enforcement

Settings → **Limits** → for project `coi-demo`:

| Setting | Value |
|---|---|
| Budget limit (hard) | **$10.00** |
| Email threshold (soft) | **$4.00** |

The cost tables in the build plan are estimates. This limit is the enforcement. Set it before your first API call, not after your first surprise.

### 0.2.3 Verify the key against a live model

Run this from your workstation. It is the smallest possible proof that key, project, endpoint, and model ID all agree.

```bash
curl -s https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.4-mini-2026-03-17",
    "input": "Reply with the single word: ready",
    "max_output_tokens": 16,
    "reasoning": { "effort": "low" }
  }' | python -m json.tool
```

**Expected:** a JSON object with `"status": "completed"` and an `output` array containing a `message` item whose `content[0].text` is `ready`.

**If you get `model_not_found`:** the dated snapshot has been retired. Re-verify at `https://developers.openai.com/api/docs/models`, pick the current cheapest mini-tier model with image input and Structured Outputs support, and update `client_config.model_id` in Stage 2 — not the workflow. Record the change in `PROGRESS.md` under *Model ID history*.

**If you get `insufficient_quota`:** add a payment method. New accounts sometimes carry promotional credit; check the Billing page before you top up.

---

## 0.3 The mailbox decision

You need three mail identities. They can be the same account, but you must be deliberate about it.

| Role | Purpose | Demo value | Production value |
|---|---|---|---|
| **Intake** | Where vendors and agents send certificates | `coi@yourdomain.com` or a Gmail alias | The client's own `coi@theircompany.com` |
| **Sender** | The From address on chase emails | Same as intake | **The client's mailbox.** Non-negotiable — see below |
| **Approver** | Who receives the Approve/Decline email | Your address for build, **the prospect's for the demo** | The client's ops manager |

### Why the sender must be the client's mailbox

Chase emails are transactional relationship messages to an existing vendor, which is why they land in CAN-SPAM's exempt category. That exemption depends on the message not containing false or misleading routing information. A renewal request that appears to come from an Indian freelancer's domain, about a policy held by a plumber, for a property manager the vendor works with, is misleading routing whatever your intent. It is also a deliverability disaster — you have no SPF/DKIM relationship with the vendor's mail server.

**Send from their mailbox, with their real reply-to, always.** For the demo, that means your own Gmail is fine because the recipient is also you. For any real client it means their Google Workspace account, connected by OAuth at onboarding.

### Gmail alias trick for the demo

You do not need a second Google account. Gmail's plus-addressing gives you a routable intake address:

- Send certificates to `youraddress+coi@gmail.com`
- Create a Gmail filter: `to:(youraddress+coi@gmail.com)` → **Apply label** `COI-INTAKE` → **Skip Inbox**
- The Gmail Trigger in Stage 5 watches label `COI-INTAKE`, not the whole inbox

This keeps demo traffic out of your real inbox and makes the trigger's filter precise. Create the label and filter now.

---

## 0.4 Google Cloud OAuth — do this carefully

The n8n Gmail node needs an OAuth2 client. The failure mode here is subtle and delayed.

### 0.4.1 Project and API

1. [console.cloud.google.com](https://console.cloud.google.com) → **New Project** → `coi-automation`.
2. **APIs & Services → Library** → search `Gmail API` → **Enable**.

### 0.4.2 OAuth consent screen

**APIs & Services → OAuth consent screen**

| Field | Value |
|---|---|
| User type | **External** |
| App name | `COI Automation` |
| User support email | your address |
| Developer contact | your address |
| Scopes | Add `https://mail.google.com/` |
| Test users | **Add your own Gmail address explicitly** |

### 0.4.3 The 7-day refresh token trap — read this

An app left in **Testing** publishing status issues refresh tokens that **expire after 7 days**. Your Gmail Trigger will work perfectly for a week, then silently stop polling. No error surfaces in n8n's UI until you open an execution.

Two ways out. Pick one now.

| Option | Effort | Result |
|---|---|---|
| **Publish the app** (Publishing status → **Publish app**) | 2 minutes | Refresh tokens do not expire. Because you only request Gmail scope for your own account and add no other users, Google does not require verification for this path — you will see an "unverified app" interstitial at consent, which you click through. **Do this.** |
| Stay in Testing and re-authorise weekly | 2 min/week forever | Guarantees you will forget the week of your best demo |

**Publish the app.** Then set a calendar reminder to re-verify the connection 24 hours before any scheduled demo regardless — Stage 9's canary job automates this for production, but for the demo period a human check is cheaper than building it early.

### 0.4.4 Credentials

**APIs & Services → Credentials → Create Credentials → OAuth client ID**

- Application type: **Web application**
- Name: `n8n-gmail`
- Authorised redirect URI: `https://<YOUR_N8N_HOST>/rest/oauth2-credential/callback`

You do not have `<YOUR_N8N_HOST>` yet — it comes from Stage 1. **Create the client now with a placeholder and return to edit the redirect URI at Stage 1.6.** Note this as a pending item in `PROGRESS.md`.

Save the **Client ID** and **Client Secret** into `.env`.

---

## 0.5 VPS and DNS

### Sizing

| Spec | Minimum | Recommended | Why |
|---|---|---|---|
| vCPU | 2 | 2 | n8n is I/O bound here |
| RAM | 2 GB | **4 GB** | n8n + Postgres + Caddy. 2GB works but OOMs when you open the editor while a workflow runs — which is precisely what you do during a demo |
| Disk | 20 GB | 40 GB | PDFs, Postgres, n8n execution history |
| Location | — | **US East** | Nearest to the prospect. Also the honest answer to "where does our data live" |

**Hetzner CX22** (2 vCPU / 4 GB / 40 GB, Ashburn VA) at roughly €4.50/mo is the reference. Any equivalent works. Ubuntu 24.04 LTS.

### DNS

Create an **A record** pointing a subdomain at the VPS IP:

```
n8n.yourdomain.com.    300    IN    A    <VPS_IPv4>
```

TTL 300 while you build; raise it later. Verify before proceeding:

```bash
dig +short n8n.yourdomain.com
```

Must return your VPS IP. If it returns nothing, wait — Caddy's TLS provisioning in Stage 1 will fail against a hostname that does not resolve, and the failure message is unhelpful.

### Firewall

On the VPS, allow only what is needed:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

**Postgres port 5432 is never opened.** It is reachable only on the Docker network. If you need a SQL client from your workstation, tunnel it:

```bash
ssh -L 5433:localhost:5432 root@<VPS_IP>
```

---

## 0.6 Telegram (optional, 5 minutes)

Used for manager alerts and as a bonus approval channel. Email is the default approval path — see Decision Log D-04 — but Telegram alerts are genuinely useful during the build because they tell you a workflow ran without opening n8n.

1. Message [@BotFather](https://t.me/BotFather) → `/newbot` → name it → copy the token.
2. Message your new bot anything (a bot cannot initiate a conversation).
3. Get your chat ID:

```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | python -m json.tool
```

Read `result[0].message.chat.id`. Save both values to `.env`.

---

## 0.7 Local toolchain

On your **workstation** (not the VPS):

| Tool | Version | Purpose | Check |
|---|---|---|---|
| Git | any | Version control | `git --version` |
| Python | ≥ 3.10 | Fixture generation, test harness | `python --version` |
| Docker Desktop | any | Local Postgres for unit tests (optional) | `docker --version` |
| Node.js | ≥ 20 | Running Code-node unit tests | `node --version` |
| `psql` | ≥ 14 | Applying migrations over the SSH tunnel | `psql --version` |
| `jq` | any | Poking at API responses | `jq --version` |

On the **VPS**:

```bash
# Docker Engine + Compose plugin, official convenience script
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER    # log out and back in
docker compose version           # must print v2.x
```

### Python environment for fixtures

```bash
cd fixtures
python -m venv .venv
# Windows:  .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

`fixtures/requirements.txt`:

```
reportlab==4.2.5
pypdf==5.1.0
pdf2image==1.17.0
Pillow==11.0.0
```

`pdf2image` requires **Poppler** on the host:

| OS | Install |
|---|---|
| Windows | Download Poppler for Windows, unzip, add its `bin/` to `PATH` |
| macOS | `brew install poppler` |
| Ubuntu | `sudo apt install poppler-utils` |

Only fixture 4 (the fake scan) needs Poppler. If it is a fight on Windows, generate that one fixture on the VPS instead — `apt install poppler-utils` there is one line. Do not spend an hour on it locally.

---

## 0.8 Repository scaffold

Create the structure from [Document 00](00-index-and-conventions.md#repository-layout). This script does it in one shot; run it from the repo root.

```bash
mkdir -p docs infra \
  db/migrations db/seeds db/queries db/scripts \
  extraction/schema extraction/prompts extraction/payloads \
  n8n/code/lib n8n/workflows \
  fixtures/spec fixtures/out \
  test/unit
touch PROGRESS.md Makefile README.md .env.example .gitignore
git init
```

### `.gitignore`

```gitignore
# Secrets — never commit
.env
*.pem
*.key

# Generated artefacts
fixtures/out/
*.pdf
!docs/**/*.pdf

# Runtime data
data/
n8n-data/
postgres-data/

# Python
.venv/
__pycache__/
*.pyc

# Node
node_modules/

# OS
.DS_Store
Thumbs.db
```

`fixtures/out/` is ignored because the fixtures regenerate deterministically from `fixtures/spec/fixtures.json`. The spec is the artefact; the PDFs are output. This also keeps synthetic certificates out of a repo you might one day share.

### `.env.example` — committed, with dummy values

```bash
# ─── Infrastructure ────────────────────────────────────────────
N8N_HOST=n8n.example.com
N8N_PROTOCOL=https
WEBHOOK_URL=https://n8n.example.com/
N8N_EDITOR_BASE_URL=https://n8n.example.com/
GENERIC_TIMEZONE=America/New_York
TZ=UTC

# ─── n8n auth & encryption ─────────────────────────────────────
# Generate: openssl rand -hex 32
N8N_ENCRYPTION_KEY=CHANGE_ME_32_BYTE_HEX
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=CHANGE_ME_STRONG

# ─── Postgres ──────────────────────────────────────────────────
POSTGRES_USER=coi
POSTGRES_PASSWORD=CHANGE_ME_STRONG
POSTGRES_DB=coi
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# ─── OpenAI ────────────────────────────────────────────────────
OPENAI_API_KEY=sk-proj-CHANGE_ME

# ─── Google OAuth (Gmail node) ─────────────────────────────────
GOOGLE_OAUTH_CLIENT_ID=CHANGE_ME.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=CHANGE_ME

# ─── Telegram (optional) ───────────────────────────────────────
TELEGRAM_BOT_TOKEN=CHANGE_ME
TELEGRAM_CHAT_ID=CHANGE_ME

# ─── Dashboard access token ────────────────────────────────────
# Generate: openssl rand -hex 16
DASHBOARD_TOKEN=CHANGE_ME_HEX

# ─── Caddy ─────────────────────────────────────────────────────
ACME_EMAIL=you@example.com
```

Copy to `.env` and fill in real values. Generate the two secrets now:

```bash
openssl rand -hex 32   # N8N_ENCRYPTION_KEY
openssl rand -hex 16   # DASHBOARD_TOKEN
```

> **`N8N_ENCRYPTION_KEY` is not optional and not regenerable.** n8n encrypts stored credentials with it. Lose it or change it and every saved credential becomes unreadable — you re-authorise Gmail, re-enter the OpenAI key, redo the OAuth dance. Put it in a password manager the moment you generate it.

---

## 0.9 The Makefile

Every operational command in this blueprint has a Make target. Create the file now; targets get filled in as stages complete.

```makefile
# Vendor COI Chasing — operational commands
.DEFAULT_GOAL := help
SHELL := /bin/bash
include .env
export

COMPOSE := docker compose -f infra/docker-compose.yml
PSQL    := $(COMPOSE) exec -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

.PHONY: help doctor up down logs restart \
        db-apply db-verify db-reset db-shell \
        fixtures fixtures-clean \
        test test-extract test-fixtures test-forbidden \
        demo-reset backup

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

doctor:  ## Verify local prerequisites (Stage 0 gate)
	@bash db/scripts/doctor.sh

up:  ## Start all services
	$(COMPOSE) up -d

down:  ## Stop all services
	$(COMPOSE) down

logs:  ## Tail all service logs
	$(COMPOSE) logs -f --tail=100

restart:  ## Restart n8n only
	$(COMPOSE) restart n8n

db-apply:  ## Apply all migrations in order
	@bash db/scripts/apply.sh

db-verify:  ## Verify schema and seed state (Stage 2 gate)
	@bash db/scripts/verify.sh

db-shell:  ## Open a psql shell
	$(COMPOSE) exec postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

demo-reset:  ## Reset to demo opening state (Stage 9)
	@bash db/scripts/reset-demo.sh

fixtures:  ## Regenerate all test fixtures
	cd fixtures && python generate.py --spec spec/fixtures.json --out out/

fixtures-clean:
	rm -rf fixtures/out/*

test: test-extract test-fixtures test-forbidden  ## Run everything

test-extract:  ## Unit-test extraction + validation logic
	node --test test/unit/

test-fixtures:  ## Run all 20 fixtures through the live pipeline
	python test/run_fixtures.py

test-forbidden:  ## Scan rendered dashboard for forbidden words
	python test/forbidden_words.py

backup:  ## Dump Postgres to ./backups
	@mkdir -p backups
	$(COMPOSE) exec -T postgres pg_dump -U $(POSTGRES_USER) $(POSTGRES_DB) \
	  | gzip > backups/coi-$$(date +%Y%m%d-%H%M%S).sql.gz
	@echo "Backup written to backups/"
```

---

## 0.10 `doctor.sh` — the Stage 0 gate

`db/scripts/doctor.sh`:

```bash
#!/usr/bin/env bash
# Stage 0 gate. Verifies prerequisites before you waste time on Stage 1.
set -uo pipefail

FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
bad()  { printf "  \033[31m✗\033[0m %s\n" "$1"; FAIL=1; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }

echo "── Toolchain ─────────────────────────────────────"
for t in git python docker node psql jq curl openssl; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t"; else bad "$t not found"; fi
done

echo
echo "── Environment ───────────────────────────────────"
if [ -f .env ]; then ok ".env exists"; else bad ".env missing (copy .env.example)"; fi

# shellcheck disable=SC1091
[ -f .env ] && set -a && source .env && set +a

for v in N8N_HOST WEBHOOK_URL N8N_ENCRYPTION_KEY POSTGRES_PASSWORD \
         OPENAI_API_KEY DASHBOARD_TOKEN GENERIC_TIMEZONE; do
  val="${!v:-}"
  if [ -z "$val" ]; then
    bad "$v is empty"
  elif [[ "$val" == CHANGE_ME* ]]; then
    bad "$v still has its placeholder value"
  else
    ok "$v set"
  fi
done

if [ "${#N8N_ENCRYPTION_KEY}" -lt 32 ]; then
  bad "N8N_ENCRYPTION_KEY is shorter than 32 chars"
else
  ok "N8N_ENCRYPTION_KEY length ok"
fi

echo
echo "── DNS ───────────────────────────────────────────"
if command -v dig >/dev/null 2>&1; then
  IP=$(dig +short "$N8N_HOST" | tail -n1)
  if [ -n "$IP" ]; then ok "$N8N_HOST → $IP"; else bad "$N8N_HOST does not resolve"; fi
else
  warn "dig not installed; skipping DNS check"
fi

echo
echo "── OpenAI ────────────────────────────────────────"
RESP=$(curl -s -o /tmp/oai.json -w "%{http_code}" \
  https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.4-mini-2026-03-17","input":"say: ready","max_output_tokens":16,"reasoning":{"effort":"low"}}')

if [ "$RESP" = "200" ]; then
  ok "OpenAI responded 200 for the pinned model"
else
  bad "OpenAI returned HTTP $RESP"
  echo "      $(head -c 300 /tmp/oai.json)"
fi

echo
echo "── Python packages ───────────────────────────────"
for p in reportlab pypdf PIL; do
  if python -c "import $p" 2>/dev/null; then ok "python: $p"; else warn "python: $p missing (needed for Stage 3)"; fi
done

echo
if [ "$FAIL" -eq 0 ]; then
  printf "\033[32mStage 0 gate PASSED\033[0m\n"
else
  printf "\033[31mStage 0 gate FAILED — fix the ✗ items above\033[0m\n"
fi
exit $FAIL
```

```bash
chmod +x db/scripts/doctor.sh
make doctor
```

---

## Stage 0 exit checklist

Tick every line in `PROGRESS.md` before moving on.

- [ ] OpenAI project `coi-demo` exists with a **restricted** key and a **$10 hard budget limit**
- [ ] `curl` against `gpt-5.4-mini-2026-03-17` returns 200 with `"status": "completed"`
- [ ] Gmail label `COI-INTAKE` and its filter exist
- [ ] Google Cloud project created, Gmail API enabled, consent screen **Published** (not Testing)
- [ ] OAuth client created; redirect URI noted as **pending Stage 1.6**
- [ ] VPS provisioned, Ubuntu 24.04, Docker + Compose v2 installed, `ufw` allows only 22/80/443
- [ ] DNS A record resolves to the VPS IP
- [ ] Telegram bot created and chat ID captured *(optional)*
- [ ] Repo scaffold created, `.gitignore` in place, `.env` filled, `N8N_ENCRYPTION_KEY` **saved to a password manager**
- [ ] `make doctor` exits 0

→ Continue to [Stage 1 — Infrastructure](02-stage-1-infrastructure.md)
