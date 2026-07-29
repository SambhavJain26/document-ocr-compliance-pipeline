# n8n Operations Cookbook

**Document 12 · CLI authoring, credential provisioning, scripted testing, and the traps**

The stage documents describe workflows node by node so you understand what you are building. This document is how you actually get them into n8n **reproducibly** — as version-controlled JSON imported by CLI, not as clicks in a browser you cannot repeat.

Read this before Stage 5. It changes how you author every workflow from that point on.

> **Provenance:** most of this is hard-won from a prior n8n build. Where a behaviour is version-sensitive it is flagged. Verify against `docker compose exec n8n n8n --version` before betting a demo on it.

---

## 12.1 Author JSON, import by CLI — not clicks

**Decision (D-26): workflows are authored as JSON in `n8n/workflows/`, imported by CLI, and published by CLI. The editor UI is for inspection and for OAuth consent only.**

The UI is fine for building the first draft of a node graph. It is a bad system of record: you cannot diff it, you cannot review it, and "I clicked something and now it works" does not survive a rebuild.

### The loop

```bash
# 1. Validate before importing — a malformed file fails deep inside the
#    import with an unhelpful message.
#    PowerShell:
Get-Content -Raw n8n/workflows/wf1-intake.json | ConvertFrom-Json | Out-Null
#    Bash:
jq empty n8n/workflows/wf1-intake.json

# 2. Copy into the container and import
docker compose -f infra/docker-compose.yml cp \
  n8n/workflows/wf1-intake.json n8n:/tmp/wf1-intake.json
docker compose -f infra/docker-compose.yml exec n8n \
  n8n import:workflow --input=/tmp/wf1-intake.json

# 3. Publish (make the imported version live)
docker compose -f infra/docker-compose.yml exec n8n \
  n8n publish:workflow --id=<workflow-id>

# 4. Restart — import and publish do NOT take effect until n8n restarts
docker compose -f infra/docker-compose.yml restart n8n
```

> `n8n update:workflow --active=true` is **deprecated**. Use `publish:workflow`. If your n8n version does not have `publish:workflow`, fall back to `update:workflow` and note the version in `PROGRESS.md`.

### Export / round-trip

```bash
docker compose -f infra/docker-compose.yml exec n8n \
  n8n export:workflow --all --pretty --separate --output=/tmp/wf-export
docker compose -f infra/docker-compose.yml cp \
  n8n:/tmp/wf-export/. n8n/workflows/
```

`--separate` gives one file per workflow, `--pretty` makes the diff readable. **Round-trip after any UI edit**, then review the diff — it is how you catch a parameter you changed on a whim at 1am.

### Makefile targets

```makefile
COMPOSE := docker compose -f infra/docker-compose.yml

wf-validate:  ## Validate all workflow JSON parses
	@for f in n8n/workflows/*.json; do \
	  jq empty "$$f" && echo "  ✓ $$f" || { echo "  ✗ $$f"; exit 1; }; \
	done

wf-import: wf-validate  ## Import + publish all workflows, then restart n8n
	@for f in n8n/workflows/*.json; do \
	  base=$$(basename "$$f"); \
	  $(COMPOSE) cp "$$f" "n8n:/tmp/$$base"; \
	  $(COMPOSE) exec -T n8n n8n import:workflow --input="/tmp/$$base"; \
	done
	@bash n8n/scripts/publish-all.sh
	$(COMPOSE) restart n8n
	@bash n8n/scripts/wait-for-webhooks.sh

wf-export:  ## Round-trip live workflows back into n8n/workflows/
	$(COMPOSE) exec -T n8n n8n export:workflow --all --pretty --separate --output=/tmp/wf-export
	$(COMPOSE) cp n8n:/tmp/wf-export/. n8n/workflows/
	@git diff --stat n8n/workflows/ || true
```

---

## 12.2 Three JSON fields that fail silently or cryptically

### ① Top-level `id` (UUID) is mandatory

Workflow **and** credential JSON both need a top-level `id`. Omitting it fails on import with `NOT NULL constraint failed` and no indication of which field.

```json
{
  "id": "8f3c1d2a-4b5e-4c7f-9a10-2b3c4d5e6f70",
  "name": "COI · 1 · Intake",
  "nodes": [ ... ],
  "connections": { ... },
  "settings": { "errorWorkflow": "<error-workflow-uuid>" }
}
```

Generate with `python -c "import uuid;print(uuid.uuid4())"`. **Keep these IDs stable in git** — that is what makes `import:workflow` an update rather than a duplicate.

### ② Webhook-based trigger nodes need a top-level `webhookId`

**This one costs you an afternoon.** A hand-authored Webhook, Form Trigger, or any webhook-based trigger needs a `webhookId` field **on the node**, separate from the node's own `id`. Omit it and the route silently 404s while `active: true` looks perfectly correct in the UI.

```json
{
  "id": "a1b2c3d4-...",
  "webhookId": "e5f6a7b8-c9d0-4e1f-8a2b-3c4d5e6f7a8b",
  "name": "Webhook — Dashboard",
  "type": "n8n-nodes-base.webhook",
  "typeVersion": 2,
  "parameters": { "path": "coi", "httpMethod": "GET", "responseMode": "responseNode" }
}
```

Applies to every trigger in this build that serves a URL:

| Node | Workflow |
|---|---|
| `Form Trigger — Upload a Certificate` | 1 · Intake |
| `Webhook — Dashboard` | 3 · Dashboard |
| `Webhook — Certificate PDF` | 3 · Dashboard |
| `Form Trigger — Status Override` | 5 · Status Override |

**Verification, not assumption:**

```bash
curl -s -o /dev/null -w '%{http_code}\n' "$WEBHOOK_URL/webhook/coi?k=$DASHBOARD_TOKEN"
```

A 404 on a workflow that shows as active means a missing `webhookId`, every time.

### ③ Literal newlines break expressions

A JSON-decoded n8n expression cannot contain a literal newline inside a quoted JavaScript string. In workflow JSON you must **double-escape** so the expression parser receives `\n`:

```json
"text": "={{ `✅ Certificate filed — ${$json.extraction.vendor_legal_name}\\nCarrier: ${$json.extraction.coverages[0]?.insurer_name ?? '—'}` }}"
```

`\\n` in the file → `\n` reaching the parser → a newline at runtime.

Affects every multi-line message in this build: the Telegram notifications ([Stage 5 N22](06-stage-5-intake-workflow.md)), the dead-letter notice, the approval body and the Gmail signature ([Stage 6 §6.8–6.9](07-stage-6-watch-and-chase-workflow.md)), and the escalation message. **The approval email body is the one that matters** — it is what a prospect reads on their phone, and a collapsed one-line version of it is not something you want to discover live.

---

## 12.3 Credentials

### CLI-importable: the OpenAI Header Auth credential

`httpHeaderAuth` has a plaintext `data` shape, so it can be scripted. n8n encrypts on import using `N8N_ENCRYPTION_KEY`.

```json
{
  "id": "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f",
  "name": "OpenAI — Header Auth (Managed)",
  "type": "httpHeaderAuth",
  "data": { "name": "Authorization", "value": "Bearer sk-proj-REPLACED_AT_RUNTIME" }
}
```

> ### Never write this file inside the repo
>
> Plaintext credential JSON goes to a temp path **outside git**, gets copied in, imported, and both copies deleted. There is no `.gitignore` entry that makes an accidentally-committed API key un-leaked.

Use the version-controlled importer; it reads `.env`, writes plaintext JSON only
to an OS temp directory, imports the two fixed credential IDs into the owner's
personal project, and removes both temporary copies even when import fails:

```bash
make credentials-import
make restart
make credentials-verify
```

The verifier confirms only credential IDs, names, types, encrypted storage, the
owner-project shares, and removal of the container temp file. It never prints a
credential value. On Windows Git Bash, the scripts disable MSYS path conversion
only for commands that carry an in-container `/tmp/...` path.

**Workflow JSON references credentials by name and id, never by value:**

```json
"credentials": {
  "httpHeaderAuth": {
    "id": "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f",
    "name": "OpenAI — Header Auth (Managed)"
  }
}
```

### Not CLI-importable: Gmail OAuth2

**`gmailOAuth2` cannot be scripted.** There is no plaintext token to pre-author — only a live browser consent flow a human must complete in the n8n UI. Accept this and build the sequencing around it.

1. Import workflows with a **placeholder** credential id for the Gmail nodes.
2. In the UI: **Credentials → Add → Gmail OAuth2 API** → paste client id/secret → **Connect my account** → complete Google consent.
3. Fetch the real id and patch the workflow JSON:

```bash
# Authenticate against the REST API (see §12.5 for the login helper)
curl -s -b /tmp/n8n-cookie "$N8N_BASE_URL/rest/credentials" \
  | jq -r '.data[] | select(.type=="gmailOAuth2") | "\(.id)\t\(.name)"'
```

Then replace the placeholder id across `n8n/workflows/*.json`, re-import, restart.

**This is the one manual step in the whole provisioning path.** Put it in the runbook explicitly rather than letting the next person discover it.

---

## 12.4 Environment traps

### `N8N_ENCRYPTION_KEY` must be pinned before the *first* `up`

If `n8n_data` does not yet exist and the key is unset, n8n **auto-generates one and writes it into the volume**. Setting the env var afterwards is silently ignored — n8n keeps using the generated key, and every credential you later import is encrypted with a key you do not have a copy of.

```bash
# Before the very first `make up`:
grep -q '^N8N_ENCRYPTION_KEY=[0-9a-f]\{64\}$' .env || { echo "SET IT FIRST"; exit 1; }
```

If you have already booted without it: `docker compose down -v` (destroys the volume — fine before Stage 5) and start again. Recovering otherwise means re-authorising every credential.

### `N8N_EDITOR_BASE_URL` — and why a restart is not enough

The OAuth callback URL n8n displays and uses is `{base}/rest/oauth2-credential/callback`, where `{base}` comes from `UrlService.getInstanceBaseUrl()`. That falls back to `WEBHOOK_URL` when `N8N_EDITOR_BASE_URL` is unset.

In this build `WEBHOOK_URL` is already the public HTTPS host, so the fallback would happen to work — **set `N8N_EDITOR_BASE_URL` explicitly anyway.** It is what send-and-wait resume links are built from, and relying on a fallback that is correct by coincidence is how the approval button 404s the day you change something unrelated. (Decision D-16.)

> **Adding a new environment variable requires `docker compose up -d n8n`, not `restart`.** `restart` re-runs the existing container with its existing environment. This bites hard because the symptom — nothing changed — looks like the setting having no effect.

### Skip the owner-setup wizard

For reproducible provisioning, so a rebuilt stack does not stop at a browser form:

```yaml
N8N_INSTANCE_OWNER_MANAGED_BY_ENV: "true"
N8N_INSTANCE_OWNER_EMAIL: ${N8N_OWNER_EMAIL}
N8N_INSTANCE_OWNER_FIRST_NAME: COI
N8N_INSTANCE_OWNER_LAST_NAME: Admin
N8N_INSTANCE_OWNER_PASSWORD_HASH: ${N8N_OWNER_PASSWORD_HASH}
```

Generate the bcrypt hash (take everything **after** the colon):

```bash
docker run --rm httpd:alpine htpasswd -nbBC 10 admin 'your-password'
```

---

## 12.5 Scripted testing via the REST API

There is no simple CLI for listing executions or test-running a workflow. The REST API is the way, and it closes a real gap: [Stage 8](09-stage-8-test-harness-and-acceptance.md) currently tests Workflow 1 by uploading to the form, but has no way to exercise **Workflow 2**, whose only entry points are a schedule and a manual trigger.

### Login

```bash
curl -s -c /tmp/n8n-cookie -X POST "$N8N_BASE_URL/rest/login" \
  -H 'Content-Type: application/json' \
  -d "{\"emailOrLdapLoginId\":\"$N8N_OWNER_EMAIL\",\"password\":\"$N8N_OWNER_PASSWORD\"}"
```

Yields an `n8n-auth` cookie. Reuse it for everything below.

### Run a workflow with custom input

Two non-obvious requirements, both of which produce confusing failures:

- **`pinData` is the only mechanism that works.** The run endpoint's own inline-data field is silently ignored.
- **`triggerToStartFrom` is required for any workflow with more than one possible starting point — including a lone Schedule Trigger.** An empty `{}` body 500s with `Cannot read properties of undefined (reading 'nodeName')` rather than picking the only trigger.

Workflow 2 has a Manual Trigger *and* a Schedule Trigger, so it needs this every time.

```bash
WF=<workflow-id>

# Pin input onto the trigger
curl -s -b /tmp/n8n-cookie -X PATCH "$N8N_BASE_URL/rest/workflows/$WF" \
  -H 'Content-Type: application/json' \
  -d '{"pinData":{"Manual Trigger":[{"json":{}}]}}'

# Run, naming the trigger explicitly
curl -s -b /tmp/n8n-cookie -X POST "$N8N_BASE_URL/rest/workflows/$WF/run" \
  -H 'Content-Type: application/json' \
  -d '{"triggerToStartFrom":{"name":"Manual Trigger"}}'
```

### Read the result

```bash
curl -s -b /tmp/n8n-cookie \
  "$N8N_BASE_URL/rest/executions?filter=$(python -c "import urllib.parse,json;print(urllib.parse.quote(json.dumps({'workflowId':'$WF'})))")"

curl -s -b /tmp/n8n-cookie "$N8N_BASE_URL/rest/executions/<id>?includeData=true"
```

> **`data.data` is "flatted"-serialised** — values may be integer indices into the same array rather than inline data. You must un-flatten it before reading node output. Write the helper once, in `test/lib/n8n.py`, and never hand-parse an execution payload again.

### Changing a node parameter live, without a restart

`PATCH /rest/workflows/{id}` only saves a **draft** (`versionId`). It does not change what is live (`activeVersionId`) until you activate that version:

```bash
NEW=$(curl -s -b /tmp/n8n-cookie -X PATCH "$N8N_BASE_URL/rest/workflows/$WF" \
       -H 'Content-Type: application/json' -d "$PATCH_BODY" | jq -r '.data.versionId')

curl -s -b /tmp/n8n-cookie -X POST "$N8N_BASE_URL/rest/workflows/$WF/activate" \
  -H 'Content-Type: application/json' -d "{\"versionId\":\"$NEW\"}"
```

Takes effect immediately, no restart. This is how you test a threshold without editing the file — for example forcing the `IF — Has Text Layer` node to `> 999999` to prove fixture 1 routes correctly down the **vision** branch too.

### Two things the CLI cannot do

- **`n8n execute --id=` will not run inside the already-running container** — the Task Broker port 5679 conflicts. Use a one-off container sharing the same volume and encryption key.
- **`n8n execute` cannot supply custom trigger input.** It only replays pinned data. Use the REST path above.

---

## 12.6 Startup timing — `/healthz` lies

**A 200 from `/healthz` does not mean webhook routes are registered.** There is a ~20–30 second gap after a restart while n8n's community-node-types and MCP-registry calls each time out at up to 6 seconds.

[Stage 9's `preflight.sh`](10-stage-9-demo-operations.md) checks the dashboard **once**. If you run it inside that window it reports a false failure, and on demo morning a false failure is nearly as costly as a real one.

`n8n/scripts/wait-for-webhooks.sh`:

```bash
#!/usr/bin/env bash
# Retries webhook reachability for 40s. A 404 inside the startup window is
# not a failure — /healthz returns 200 well before routes are registered.
set -uo pipefail
cd "$(dirname "$0")/../.."
set -a; source .env; set +a

URL="${WEBHOOK_URL%/}/webhook/coi?k=${DASHBOARD_TOKEN}"
DEADLINE=$(( $(date +%s) + 40 ))

printf "  waiting for webhook routes "
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL")
  if [ "$code" = "200" ]; then
    printf " \033[32mready\033[0m (%ss)\n" "$(( 40 - (DEADLINE - $(date +%s)) ))"
    exit 0
  fi
  printf "."
  sleep 2
done

printf " \033[31mstill %s after 40s\033[0m\n" "$code"
echo "     Check for a missing webhookId on the trigger node (§12.2)."
exit 1
```

### Side-effect-free reachability check

For a webhook that triggers real work, POST an **empty array**:

```bash
curl -s -X POST "$WEBHOOK_URL/webhook/<path>" \
  -H 'Content-Type: application/json' -d '[]'
```

With a Split Out node at the head of the branch, zero items means nothing downstream fires. You get route registration confirmed without sending an email to an insurance agent.

---

## 12.7 Node-authoring rules

### Postgres: `executeQuery` with an **array** expression

> **This corrects [Stage 5 N18](06-stage-5-intake-workflow.md).** The comma-separated string form the UI hints at **breaks on commas inside values** — and certificate holder names and addresses are full of commas (`Harbourline Property Management LLC, Suite 210`). It would fail on real data while passing on tidy fixtures, which is the worst possible failure profile.

```json
{
  "parameters": {
    "operation": "executeQuery",
    "query": "INSERT INTO certificates (vendor_id, source, certificate_holder) VALUES ($1,$2,$3) RETURNING id, (xmax = 0) AS was_insert",
    "options": {
      "queryReplacement": "={{ [$json.vendor_id, $json.source, $json.extraction.certificate_holder] }}"
    }
  }
}
```

An **expression evaluating to an array**. Not `={{ $json.a }}, {{ $json.b }}`.

Also: prefer `executeQuery` over the node's `insert` / `upsert` operations. Those need a `resourceMapper` structure that is genuinely awkward to hand-author, and `executeQuery` is what every query in [Stage 2 §2.6](03-stage-2-data-layer.md) is already written for.

### `alwaysOutputData` on anything optional

Any Postgres node whose result may be zero rows, where the branch must continue, needs `alwaysOutputData: true`. In this build: `Postgres — Vendor Lookup` (a vendor with no prior certificate), `Postgres — Chase Queue` (empty queue), and the supersede update.

Without it the branch stops and you get a workflow that "works" until the day a query legitimately returns nothing.

### Reference named nodes, never a bare `$json` across hops

**This corrects [Stage 6 §6.9](07-stage-6-watch-and-chase-workflow.md), which was wrong.** After the `Gmail — Send and Wait for Response` node, `$json` is the minimal approval payload — `{ data: { approved: true } }`. There is no `config` on it. `$json.config.from_mailbox` in the send node resolves to `undefined`, and the vendor email goes out with a blank Reply-To and a blank signature.

```javascript
// ✗ Wrong — $json here is the approval payload
{{ $json.config.from_mailbox }}

// ✓ Right — reach back to the node that actually holds it
{{ $('06 Bucket Context').item.json.config.from_mailbox }}
```

The general rule: **a bare `$json` after two sequential HTTP or gate nodes refers to the previous node's response, not the one you were thinking of.** Reach back by name. Avoid shim Code nodes that exist only to carry a value forward — they are a symptom of not doing this.

### Name every node descriptively

Never `Code`, `HTTP Request`, `If`, `Set`. Node names appear in error alerts, and `Node: Code` at 3am tells you nothing. The convention is in [docs/00](00-index-and-conventions.md): `Title Case — Purpose`.

### Code nodes cannot assume `process.env`

This build sets `N8N_BLOCK_ENV_ACCESS_IN_NODE: "true"` deliberately, so a Code node cannot print your OpenAI key into an execution log a prospect might see over your shoulder. **Everything configurable comes from `client_config` via a Postgres node.** No Code node in this blueprint reads `process.env`, and none should.

---

## 12.8 Error Trigger emits two different payload shapes

**This corrects [Stage 5 §5.3](06-stage-5-intake-workflow.md), which handled only one.**

| Failure type | Payload shape |
|---|---|
| Node-execution failure | `{ execution: { id, error: { message }, lastNodeExecuted, url }, workflow: { id, name } }` |
| **Workflow-activation failure** | `{ trigger: { error: { message } }, workflow: { id, name } }` — **no `execution` key at all** |

The activation-failure shape arrives whenever n8n tries and fails to activate a workflow on restart. A Manual-Trigger-only workflow with an `errorWorkflow` registered hits this **on every restart**. In this build that is `COI · 5 · Status Override` and any manual-only test workflow you leave lying around.

The Stage 5 message reads `$json.execution.lastNodeExecuted` and would log blank fields for the entire activation-failure class — meaning the alert that tells you a workflow failed to come up is itself the useless one.

Read both shapes defensively:

```javascript
={{ `🔴 <b>Workflow failed</b>\n` +
   `${$json.workflow?.name ?? 'unknown workflow'}\n` +
   `${$json.execution ? `Node: ${$json.execution.lastNodeExecuted ?? '—'}\n` : 'Activation failure\n'}` +
   `${$json.execution?.error?.message ?? $json.trigger?.error?.message ?? 'no message'}\n` +
   `${$json.execution?.url ?? ''}` }}
```

Remember to double-escape those `\n` to `\\n` when this goes into workflow JSON (§12.2).

---

## 12.9 OpenAI-specific

### Never send `temperature` to a reasoning model

Reasoning models reject it outright with `400 Unsupported parameter`. This build uses `reasoning: { effort: "low" | "medium" }` on the Responses API, which is correct — **do not "helpfully" add `temperature: 0` for determinism.** It will 400 every call, and the failure looks like a malformed request rather than a rejected parameter.

### Structured Output Parser caveats do not apply here

The LangChain Structured Output Parser node has no `$ref` support and may wrap output under an `output` key. **This build does not use it** — every model call goes through an HTTP Request node against the Responses API with `text.format` strict Structured Outputs ([Decision D-01/D-02](11-decision-log.md)).

Two things carry over anyway:

- The schema in [Stage 4 §4.2](05-stage-4-extraction-engine.md) uses **no `$ref`**. Keep it that way — it costs a little repetition and buys portability.
- `03_parse_response.js` walks `output[]` for a `message` item rather than assuming a shape. That defensiveness is the same instinct.

### AI subnodes are not on the main execution path

If you ever add a LangChain AI node, `$('OpenAI Chat Model').item` from a downstream node fails with `No path back to referenced node`, even though token telemetry appears in the saved execution metadata.

Not an issue here — token counts come back in the HTTP response body's `usage` object and are written to `certificates.input_tokens` / `output_tokens` ([Stage 2](03-stage-2-data-layer.md)), which is why the Stage 8 cost report works at all.

---

## 12.10 Querying Postgres from a script

Already used by the Stage 8 harness, restated because the flags matter:

```bash
docker compose -f infra/docker-compose.yml exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A \
  -c "SELECT row_to_json(t) FROM (SELECT id, status, validation_flags FROM certificates ORDER BY id DESC LIMIT 5) t;"
```

One JSON object per line, `JSON.parse`/`json.loads` directly. `-t` strips headers, `-A` turns off column alignment. This handles embedded newlines and commas that CSV output would mangle — `confidence_reason` and `cancellation_notice_wording` both contain prose, so CSV is not an option.

No `pg` or `psycopg` dependency needed.

---

## 12.11 Revised provisioning sequence

Replaces the click-through implied by Stages 1 and 5. Reproducible end to end apart from one human step.

```bash
# 1. Encryption key pinned BEFORE the first up (§12.4)
grep -q '^N8N_ENCRYPTION_KEY=[0-9a-f]\{64\}$' .env || { echo "SET IT FIRST"; exit 1; }

# 2. Bring up the stack
make up
bash n8n/scripts/wait-for-webhooks.sh || true   # no workflows yet; expected to fail

# 3. Database
make db-apply && make db-seed && make db-verify

# 4. Scriptable credentials
bash n8n/scripts/import-credentials.sh
make restart

# 5. ── MANUAL, UNAVOIDABLE ──
#    n8n UI → Credentials → Gmail OAuth2 API → Connect my account
#    Complete Google consent, then capture the real id:
bash n8n/scripts/fetch-credential-ids.sh    # writes n8n/workflows/.credential-ids.json

# 6. Workflows
make wf-import        # validate → cp → import → publish → restart → wait

# 7. Verify
make preflight
```

Steps 1–4 and 6–7 are repeatable on a fresh box in under ten minutes. **Step 5 is the only thing a human must do**, and it is the one to put in the client runbook in bold.

---

## Added to the Stage checklists

| Stage | New item |
|---|---|
| 1 | `N8N_ENCRYPTION_KEY` pinned **before the first `up`** |
| 1 | New env vars applied with `up -d`, not `restart` |
| 1 | `import-credentials.sh` provisions OpenAI + Postgres credentials |
| 1 | Gmail OAuth completed in the UI; real credential id captured |
| 5 | Every webhook-based trigger has a top-level `webhookId` |
| 5 | Postgres nodes use `queryReplacement` as an **array expression** |
| 5 | Error Trigger reads **both** payload shapes |
| 5 | All `\n` in workflow JSON expressions are `\\n` |
| 6 | Post-approval nodes reference `$('06 Bucket Context')`, not bare `$json` |
| 8 | Workflow 2 test-run uses `pinData` + `triggerToStartFrom` |
| 9 | `preflight.sh` retries webhook reachability for 40 s |
