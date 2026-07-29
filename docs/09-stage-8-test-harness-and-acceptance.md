# Stage 8 — Test harness and acceptance

**Document 09 · Estimated time: 1 day · Cost: ~$0.30 of token spend**

Twenty fixtures, one command, one results table. This is the stage that turns "it worked when I tried it" into "it works", and it is the stage most likely to get skipped under time pressure.

Do not skip it. The failure mode of this product is silence — a wrong extraction that looks fine, a vendor who quietly never gets chased. Those are exactly the defects a manual click-through misses.

**Gate:** all 20 fixtures produce their expected outcome, or you have consciously accepted a deviation and written down what you will say about it.

---

## 8.1 `test/expected.json` — the contract

```json
{
  "f01-clean-current": {
    "outcome": "STORE", "status": "ON_FILE", "confidence": "HIGH",
    "method": "text", "coverage_lines": 3, "flags": [],
    "vendor_match": "Vaughn Electric Co", "colour": "green"
  },
  "f02-expiring-20d": {
    "outcome": "STORE", "status": "ON_FILE", "confidence": "HIGH",
    "method": "text", "coverage_lines": 1, "flags": [],
    "bucket": "D30", "colour": "amber", "days_to_expiry": 20
  },
  "f03-expired-34d": {
    "outcome": "STORE", "status": "ON_FILE", "method": "text",
    "flags": [], "bucket": "EXPIRED", "colour": "red", "days_to_expiry": -34
  },
  "f04-scanned": {
    "outcome": "STORE", "status": "ON_FILE",
    "confidence_in": ["MEDIUM", "HIGH"], "method": "vision",
    "confidence_reason_required_if": "MEDIUM", "coverage_lines": 3
  },
  "f05-inverted-dates": {
    "outcome": "STORE", "status": "NEEDS_REVIEW",
    "flags_include": ["DATE_INVERTED"], "colour": "amber"
  },
  "f06-wrong-holder": {
    "outcome": "STORE", "status": "ON_FILE",
    "flags_include": ["HOLDER_MISMATCH"], "holder_match": false
  },
  "f07-low-limits": {
    "outcome": "STORE", "status": "ON_FILE",
    "flags_include": ["LIMIT_BELOW_MINIMUM"]
  },
  "f08-four-expiries": {
    "outcome": "STORE", "status": "ON_FILE", "coverage_lines": 4,
    "assert_earliest_not_gl": true
  },
  "f09-no-gl": {
    "outcome": "STORE", "status": "ON_FILE",
    "flags_include": ["NO_GL_LINE"]
  },
  "f10a-multi-first":  { "outcome": "STORE", "status": "ON_FILE" },
  "f10b-multi-second": { "outcome": "STORE", "status": "ON_FILE" },
  "f11-not-a-coi": {
    "outcome": "REJECT", "dead_letter_reason": "NOT_A_COI",
    "certificates_created": 0, "vendors_created": 0
  },
  "f12-renewal": {
    "outcome": "STORE", "status": "ON_FILE",
    "supersedes": "f02-expiring-20d", "colour": "green"
  },
  "f13-coverage-gap": {
    "outcome": "STORE", "status": "ON_FILE",
    "flags_include": ["COVERAGE_GAP"], "coverage_gap_days": 14
  },
  "f15-sole-prop-no-wc": {
    "outcome": "STORE", "status": "ON_FILE",
    "flags_exclude": ["NO_WC_LINE"]
  },
  "f16-owner-llc-holder": {
    "outcome": "STORE", "status": "ON_FILE",
    "flags_exclude": ["HOLDER_MISMATCH"], "holder_match": true
  },
  "f17-near-duplicate": {
    "outcome": "STORE", "status": "NEEDS_REVIEW",
    "flags_include": ["POSSIBLE_DUPLICATE_VENDOR"], "vendor_id_null": true
  },
  "f18-encrypted": {
    "outcome": "REJECT", "dead_letter_reason": "PDF_ENCRYPTED",
    "certificates_created": 0, "no_execution_error": true
  },
  "f19-portal-link": {
    "outcome": "REJECT", "dead_letter_reason": "NO_ATTACHMENT_PORTAL_LINK",
    "no_outbound_fetch": true
  },
  "f20-cancellation-wording": {
    "outcome": "STORE", "status": "ON_FILE",
    "captures_field": "cancellation_notice_wording",
    "wording_contains": "thirty (30) days"
  }
}
```

### Notes on three deliberately loose assertions

**`f04` accepts MEDIUM or HIGH.** The vision branch on a deliberately degraded scan is the one place model behaviour legitimately varies run to run. Pinning it to MEDIUM would produce a flaky test that you would eventually start ignoring, which is worse than a loose one you trust. What is *not* loose: if it comes back MEDIUM it must carry a `confidence_reason`.

**`f08` asserts `earliest_not_gl` rather than a specific date.** The point of that fixture is that the dashboard reports the earliest expiring line, not the General Liability line. Asserting the behaviour rather than the value survives a spec edit.

**`f20` asserts a substring, not the full sentence.** Verbatim capture is the requirement; exact whitespace is not.

---

## 8.2 `test/run_fixtures.py`

```python
#!/usr/bin/env python3
"""
Runs every fixture through the live pipeline and reports a results table.

Deliberately end-to-end against the real stack: it posts to the real Form
Trigger, calls the real model, and reads the real database. A mocked test
here would pass while the thing you are about to demo is broken.

Usage:
    python test/run_fixtures.py
    python test/run_fixtures.py --only f13-coverage-gap
    python test/run_fixtures.py --no-reset          # keep existing state
"""
from __future__ import annotations

import argparse, json, os, subprocess, sys, time
from pathlib import Path

import requests   # pip install requests

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / "fixtures" / "out"
BASE = os.environ["N8N_BASE_URL"].rstrip("/")
FORM_URL = f"{BASE}/form/coi-upload"
POLL_TIMEOUT = 180
POLL_INTERVAL = 3

# Fixtures whose behaviour depends on earlier state. Order is the test.
ORDERED = [
    "f01-clean-current", "f04-scanned", "f05-inverted-dates",
    "f06-wrong-holder", "f07-low-limits", "f08-four-expiries",
    "f09-no-gl", "f10a-multi-first", "f10b-multi-second",
    "f11-not-a-coi", "f15-sole-prop-no-wc", "f16-owner-llc-holder",
    "f17-near-duplicate", "f18-encrypted", "f20-cancellation-wording",
    "f02-expiring-20d",      # must precede f12
    "f12-renewal",           # supersedes f02
    "f03-expired-34d",       # must precede f13
    "f13-coverage-gap",      # gap is measured against f03
]


def psql(sql: str) -> str:
    out = subprocess.run(
        ["docker", "compose", "-f", str(ROOT / "infra/docker-compose.yml"),
         "exec", "-T", "postgres", "psql", "-tAq",
         "-U", os.environ["POSTGRES_USER"], "-d", os.environ["POSTGRES_DB"],
         "-c", sql],
        capture_output=True, text=True, check=True, cwd=ROOT)
    return out.stdout.strip()


def state_snapshot() -> dict:
    return {
        "certificates": int(psql("SELECT count(*) FROM certificates") or 0),
        "vendors":      int(psql("SELECT count(*) FROM vendors") or 0),
        "dead_letter":  int(psql("SELECT count(*) FROM dead_letter") or 0),
    }


def upload(path: Path) -> None:
    with open(path, "rb") as fh:
        r = requests.post(FORM_URL,
                          files={"Certificate_(PDF)": (path.name, fh, "application/pdf")},
                          timeout=60)
    r.raise_for_status()


def wait_for_change(before: dict, timeout=POLL_TIMEOUT) -> dict:
    """Blocks until certificates or dead_letter moves. Returns the new state."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        now = state_snapshot()
        if (now["certificates"] != before["certificates"]
                or now["dead_letter"] != before["dead_letter"]):
            time.sleep(1.5)     # let coverage inserts land
            return now
        time.sleep(POLL_INTERVAL)
    raise TimeoutError(f"No state change within {timeout}s")


def latest_certificate() -> dict | None:
    row = psql("""
      SELECT json_build_object(
        'id', c.id, 'vendor_id', c.vendor_id, 'status', c.status,
        'confidence', c.extraction_confidence, 'confidence_reason', c.confidence_reason,
        'method', c.extraction_method, 'holder_match', c.holder_match,
        'gap_days', c.coverage_gap_days, 'flags', c.validation_flags,
        'cancellation_notice_wording', c.cancellation_notice_wording,
        'coverage_lines', (SELECT count(*) FROM coverages WHERE certificate_id = c.id),
        'earliest_type', (SELECT coverage_type FROM coverages
                          WHERE certificate_id = c.id
                          ORDER BY expiration_date LIMIT 1)
      )::text
      FROM certificates c ORDER BY c.id DESC LIMIT 1;
    """)
    return json.loads(row) if row else None


def latest_dead_letter() -> dict | None:
    row = psql("""SELECT json_build_object('reason', reason_code,
                  'detail', reason_detail)::text
                  FROM dead_letter ORDER BY id DESC LIMIT 1;""")
    return json.loads(row) if row else None


def check(fid: str, exp: dict, before: dict, after: dict) -> list[str]:
    """Returns a list of failure strings. Empty means pass."""
    errs: list[str] = []
    E = errs.append

    if exp.get("outcome") == "REJECT":
        if after["dead_letter"] <= before["dead_letter"]:
            E("expected a dead_letter row; none was created")
        else:
            dl = latest_dead_letter()
            want = exp.get("dead_letter_reason")
            if want and dl["reason"] != want:
                E(f"dead_letter reason {dl['reason']!r}, expected {want!r}")
        if exp.get("certificates_created") == 0 and after["certificates"] != before["certificates"]:
            E("a certificate row was created but should not have been")
        if exp.get("vendors_created") == 0 and after["vendors"] != before["vendors"]:
            E("a vendor row was created but should not have been")
        return errs

    if after["certificates"] <= before["certificates"]:
        E("expected a new certificate row; none was created")
        return errs

    c = latest_certificate()
    flags = [f["code"] for f in (c["flags"] or [])]

    if "status" in exp and c["status"] != exp["status"]:
        E(f"status {c['status']!r}, expected {exp['status']!r}")

    if "confidence" in exp and c["confidence"] != exp["confidence"]:
        E(f"confidence {c['confidence']!r}, expected {exp['confidence']!r}")

    if "confidence_in" in exp and c["confidence"] not in exp["confidence_in"]:
        E(f"confidence {c['confidence']!r} not in {exp['confidence_in']}")

    if exp.get("confidence_reason_required_if") == c["confidence"] and not c["confidence_reason"]:
        E(f"confidence is {c['confidence']} but confidence_reason is empty")

    if "method" in exp and c["method"] != exp["method"]:
        E(f"extraction_method {c['method']!r}, expected {exp['method']!r} "
          "— check the 200-char text-layer threshold")

    if "coverage_lines" in exp and c["coverage_lines"] != exp["coverage_lines"]:
        E(f"{c['coverage_lines']} coverage rows, expected {exp['coverage_lines']}")

    for f in exp.get("flags_include", []):
        if f not in flags:
            E(f"missing flag {f} (got {flags or 'none'})")

    for f in exp.get("flags_exclude", []):
        if f in flags:
            E(f"flag {f} present but should be suppressed")

    if exp.get("flags") == [] and flags:
        E(f"expected no flags, got {flags}")

    if "coverage_gap_days" in exp and c["gap_days"] != exp["coverage_gap_days"]:
        E(f"coverage_gap_days {c['gap_days']}, expected {exp['coverage_gap_days']}")

    if "holder_match" in exp and c["holder_match"] != exp["holder_match"]:
        E(f"holder_match {c['holder_match']}, expected {exp['holder_match']}")

    if exp.get("vendor_id_null") and c["vendor_id"] is not None:
        E(f"vendor_id is {c['vendor_id']} but a near-duplicate must not auto-merge")

    if exp.get("assert_earliest_not_gl") and c["earliest_type"] == "GENERAL_LIABILITY":
        E("earliest expiring line is GL; fixture 8 is built so it should not be")

    if "wording_contains" in exp:
        w = c["cancellation_notice_wording"] or ""
        if exp["wording_contains"].lower() not in w.lower():
            E(f"cancellation wording missing {exp['wording_contains']!r} (got {w[:80]!r})")

    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--no-reset", action="store_true")
    args = ap.parse_args()

    expected = json.loads((ROOT / "test/expected.json").read_text())

    if not args.no_reset:
        subprocess.run(["bash", "db/scripts/reset-demo.sh"], cwd=ROOT, check=True)

    ids = [args.only] if args.only else ORDERED
    results, t0 = [], time.time()

    for fid in ids:
        exp = expected.get(fid)
        if not exp:
            print(f"  ? {fid}: no expectation defined — skipped")
            continue

        path = FIX / f"{fid}.pdf"
        if not path.exists():
            results.append((fid, ["fixture file missing — run `make fixtures`"]))
            continue

        before = state_snapshot()
        print(f"  ▸ {fid} ... ", end="", flush=True)
        try:
            upload(path)
            after = wait_for_change(before)
            errs = check(fid, exp, before, after)
        except Exception as e:                       # noqa: BLE001
            errs = [f"{type(e).__name__}: {e}"]

        print("\033[32mPASS\033[0m" if not errs else "\033[31mFAIL\033[0m")
        results.append((fid, errs))

    failed = [(f, e) for f, e in results if e]

    print("\n" + "=" * 68)
    print(f"  {len(results) - len(failed)}/{len(results)} passed "
          f"in {time.time() - t0:.0f}s")
    print("=" * 68)

    for fid, errs in failed:
        print(f"\n\033[31m{fid}\033[0m")
        for e in errs:
            print(f"    · {e}")

    # Cost report — you will be asked what this costs to run.
    print("\n── Cost this run ─────────────────────────────")
    print(psql("""
      SELECT extraction_method,
             count(*)                AS n,
             sum(input_tokens)       AS in_tok,
             sum(output_tokens)      AS out_tok,
             round(avg(latency_ms))  AS avg_ms,
             round((sum(input_tokens) * 0.75 / 1e6
                  + sum(output_tokens) * 4.50 / 1e6)::numeric, 4) AS usd
      FROM certificates
      WHERE extraction_method IS NOT NULL
      GROUP BY extraction_method;
    """))

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
```

---

## 8.3 The consistency checks

Three defects that unit tests will not catch because they live in the gaps between components.

### 8.3.1 SQL / JavaScript normalisation parity

`test/unit/test_normalise.js`:

```javascript
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { normaliseName } from './harness.mjs';

const CASES = [
  'Kessler Heating & Air Inc',        'M. Mercer & Sons Plumbing, LLC',
  'Vaughn Electric Co.',              'ROWAN ROOFING L.L.C.',
  'Alder Landscaping',                'Bexley Cleaning Co',
  "O'Brien Plumbing & Heating",       'Thorne Pest Control, Incorporated',
  'Ashgrove General Contracting LLP', 'Linden Glass  &  Glazing',
  'Selby Locksmiths (Charlotte) Ltd', 'Fenwick   Flooring',
  'Harrow Appliance Repair PLLC',     'Draycott Tree Services Corp.',
  'Whitlock Gutter + Drain',          'Orme Concrete Works, Inc.',
  'Padstow Window-Cleaning',          'Quill Handyman Services dba QHS',
  'ABC 123 Plumbing',                 'Smith & Smith & Sons',
  'THE Roofing Company',              'Élan Interiors',
  'A1 Electric',                      'Northgate  Mutual   Insurance',
  'Harbourline Property Management LLC', 'Sable Court Properties LLC',
  'Mercer Plumbing',                  'Mercer Plumbing & Heating',
  'X',                                '',
];

function sqlNormalise(s) {
  const out = execFileSync('docker', [
    'compose', '-f', 'infra/docker-compose.yml', 'exec', '-T', 'postgres',
    'psql', '-tAq', '-U', process.env.POSTGRES_USER, '-d', process.env.POSTGRES_DB,
    '-c', `SELECT btrim(regexp_replace(regexp_replace(regexp_replace(lower($$${s}$$),
      '\\s+(llc|l\\.l\\.c\\.|inc|inc\\.|incorporated|corp|corp\\.|corporation|co|co\\.|company|ltd|ltd\\.|limited|lp|llp|pllc|pc|dba)\\b', '', 'g'),
      '[^a-z0-9 ]', ' ', 'g'), '\\s+', ' ', 'g'));`,
  ], { encoding: 'utf8' });
  return out.trim();
}

test('SQL and JS normalisation agree on every case', () => {
  const mismatches = [];
  for (const c of CASES) {
    const js = normaliseName(c);
    const sql = sqlNormalise(c);
    if (js !== sql) mismatches.push(`${c!==''?c:'(empty)'}\n    js:  ${js!==''?js:'(empty)'}\n    sql: ${sql!==''?sql:'(empty)'}`);
  }
  assert.equal(mismatches.length, 0,
    `Normalisation diverged on ${mismatches.length} case(s):\n  ${mismatches.join('\n  ')}\n\n` +
    'A divergence means seeded vendors will not match extracted names.');
});
```

**Why this test earns its keep:** the seed script normalises in SQL, the matcher normalises in JavaScript, and neither can call the other. If they drift, a seeded vendor stops matching the certificate that names them, a duplicate vendor is created, and the dashboard shows one vendor twice with half the data on each. That failure is invisible until you look at the register, and it is exactly the kind of thing you look at during a demo.

### 8.3.2 Prompt and schema drift

`test/check_pasted_sources.py`:

```python
#!/usr/bin/env python3
"""
The extraction prompt and JSON schema exist twice: as files under
extraction/, and pasted as constants inside n8n Code nodes. This checks the
pasted copies still match the files.

They exist twice because the n8n Code node cannot read from disk. That is a
platform constraint, not a design choice — so the mitigation is a test.
"""
import json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
WF = json.loads((ROOT / "n8n/workflows/wf1-intake.json").read_text())

prompt_file = (ROOT / "extraction/prompts/extract.system.md").read_text().strip()
schema_file = json.loads((ROOT / "extraction/schema/coi_extraction.schema.json").read_text())

code = "\n".join(
    n["parameters"].get("jsCode", "")
    for n in WF["nodes"] if n["type"] == "n8n-nodes-base.code"
)

fail = 0

m = re.search(r"const SYSTEM_PROMPT\s*=\s*`([\s\S]*?)`;", code)
if not m:
    print("✗ SYSTEM_PROMPT constant not found in any Code node"); fail = 1
elif m.group(1).strip() != prompt_file:
    print("✗ Pasted SYSTEM_PROMPT differs from extraction/prompts/extract.system.md"); fail = 1
else:
    print("✓ prompt matches")

m = re.search(r"const SCHEMA\s*=\s*(\{[\s\S]*?\n\});", code)
if not m:
    print("✗ SCHEMA constant not found"); fail = 1
else:
    try:
        if json.loads(m.group(1)) != schema_file:
            print("✗ Pasted SCHEMA differs from extraction/schema/coi_extraction.schema.json"); fail = 1
        else:
            print("✓ schema matches")
    except json.JSONDecodeError as e:
        print(f"✗ Pasted SCHEMA is not valid JSON: {e}"); fail = 1

sys.exit(fail)
```

### 8.3.3 Secret leakage in exports

`test/check_exports.sh`:

```bash
#!/usr/bin/env bash
# n8n exports credential REFERENCES by id, which is correct and safe.
# This is belt-and-braces against a key pasted into a node parameter by hand.
set -uo pipefail
FAIL=0
for f in n8n/workflows/*.json; do
  if grep -oiE '(sk-[A-Za-z0-9_-]{20,}|Bearer [A-Za-z0-9._-]{20,}|AIza[A-Za-z0-9_-]{30,})' "$f"; then
    echo "✗ possible secret in $f"; FAIL=1
  fi
done
[ "$FAIL" -eq 0 ] && echo "✓ no secrets in workflow exports"
exit $FAIL
```

---

## 8.3.4 Test-running Workflow 2 without waiting for 08:00

The fixture harness exercises Workflow 1 by posting to the Form Trigger. Workflow 2 has no HTTP entry point — only a Schedule Trigger and a Manual Trigger — so it needs the REST API. Full mechanics in [§12.5](12-n8n-operations-cookbook.md); the two things that will bite you:

- **`pinData` is the only way to supply input.** The run endpoint's own inline-data field is silently ignored.
- **`triggerToStartFrom` is mandatory whenever a workflow has more than one possible starting point — including a lone Schedule Trigger.** An empty `{}` body 500s with `Cannot read properties of undefined (reading 'nodeName')` instead of picking the only trigger. Workflow 2 has two triggers, so this applies every run.

`test/run_chase.py`:

```python
#!/usr/bin/env python3
"""
Test-runs Workflow 2 (Watch & Chase) via the REST API and asserts the queue.

Stops before the approval gate: the run pauses at Send-and-Wait, which is
correct — this verifies bucketing and drafting, not the human step. Approve
by hand once, in Stage 6.
"""
import json, os, sys, time, urllib.parse, requests

BASE = os.environ["N8N_BASE_URL"].rstrip("/")
WF   = os.environ["WF2_ID"]
TRIGGER = "Manual Trigger"

s = requests.Session()
s.post(f"{BASE}/rest/login", json={
    "emailOrLdapLoginId": os.environ["N8N_OWNER_EMAIL"],
    "password":           os.environ["N8N_OWNER_PASSWORD"],
}).raise_for_status()

# pinData is the only mechanism the run endpoint honours.
s.patch(f"{BASE}/rest/workflows/{WF}",
        json={"pinData": {TRIGGER: [{"json": {}}]}}).raise_for_status()

# triggerToStartFrom is required — two starting points in this workflow.
s.post(f"{BASE}/rest/workflows/{WF}/run",
       json={"triggerToStartFrom": {"name": TRIGGER}}).raise_for_status()

time.sleep(20)

f = urllib.parse.quote(json.dumps({"workflowId": WF}))
ex = s.get(f"{BASE}/rest/executions?filter={f}").json()["data"][0]
detail = s.get(f"{BASE}/rest/executions/{ex['id']}?includeData=true").json()

print(f"execution {ex['id']}: status={detail['data'].get('status')}")
print("Expect 'waiting' — the run pauses at the approval gate.")
```

> **`data.data` is "flatted"-serialised** — values may be integer indices into the same array rather than inline objects. Write the un-flattener once in `test/lib/n8n.py` and never hand-parse an execution payload again.

### Changing a threshold live, without editing a file

`PATCH /rest/workflows/{id}` saves only a **draft** (`versionId`); it does not change what is live (`activeVersionId`) until you activate that version. Useful for proving a branch you cannot otherwise reach — for example forcing `IF — Has Text Layer` to `> 999999` so fixture 1 routes down the **vision** branch, confirming both branches produce the same extraction from the same document:

```bash
NEW=$(curl -s -b /tmp/n8n-cookie -X PATCH "$N8N_BASE_URL/rest/workflows/$WF1" \
       -H 'Content-Type: application/json' -d "$PATCH_BODY" | jq -r '.data.versionId')
curl -s -b /tmp/n8n-cookie -X POST "$N8N_BASE_URL/rest/workflows/$WF1/activate" \
  -H 'Content-Type: application/json' -d "{\"versionId\":\"$NEW\"}"
```

Immediate, no restart. **Restore the original threshold afterwards** — a left-behind test patch is a live config change nobody remembers making.

---

## 8.4 Full acceptance run

```makefile
test-all: db-verify test-extract test-fixtures test-forbidden test-consistency  ## Full acceptance

test-consistency:
	@python test/check_pasted_sources.py
	@bash   test/check_exports.sh
```

```bash
make fixtures
make test-all
```

Expected runtime: 8–14 minutes, dominated by model latency on 19 uploads.

### The results table

Record it in `PROGRESS.md` after every full run:

| Fixture | Expected | Actual | Notes |
|---|---|---|---|
| f01 | ON_FILE / HIGH / 3 lines | ✅ | 4.2 s, 1,584 in / 712 out |
| f04 | vision / MEDIUM | ✅ | 18.1 s, reason: "policy expiration partially obscured" |
| … | | | |

The `confidence_reason` column is worth capturing verbatim. When a prospect asks *"what happens when it gets one wrong?"*, you open a `NEEDS_REVIEW` row and it says *"policy expiration date partially obscured by scan artefact"* in plain English. That answer is worth more than a demo feature — and you want to know in advance which sentence they will see.

---

## 8.5 Accepting a deviation

Some fixtures will fail on the first full run. That is normal and it is what the stage is for. For each one, choose deliberately:

| Situation | Action |
|---|---|
| Model reads a field wrong on a clean PDF | Fix the prompt. This is a real defect. |
| Model marks fixture 4 HIGH instead of MEDIUM | Strengthen the CONFIDENCE block; verify the whole block reached `instructions`. |
| A validation rule fires when it should not | Fix the rule. Confident wrong alerts are the worst outcome in this product. |
| Vision branch is slow (> 30 s) | Accept it. Note it. The demo uses the text branch and the upload form. |
| Model occasionally returns MEDIUM on a clean PDF | Accept it. Over-caution is the correct failure direction here. |
| A fixture fails only when run out of order | **Do not accept.** That is a real state-dependency bug and it will surface in production. |

Write each accepted deviation into `PROGRESS.md` under *Accepted deviations*, with the sentence you will say if a prospect notices it. An accepted deviation you have not rehearsed a line for is an unaccepted deviation.

---

## 8.6 Load sanity

Not a load test — a check that nothing falls over at realistic volume.

```bash
for f in fixtures/out/f0*.pdf; do
  curl -s -F "Certificate_(PDF)=@$f" "$N8N_BASE_URL/form/coi-upload" >/dev/null &
done
wait
```

Ten concurrent uploads. Watch for:

- All ten produce a row (certificate or dead_letter). **Zero silent drops.**
- No n8n OOM — `docker stats coi-n8n` stays under the 1536 MB cap
- Postgres connections stay well under 100
- Dashboard still renders in under a second

A real client sends 20–40 certificates in a backfill batch. Ten concurrent is comfortably above what the drip of ordinary operation produces.

---

## Stage 8 exit checklist

- [ ] `test/expected.json` covers all 20 fixtures
- [ ] `make test-fixtures` runs the full set unattended
- [ ] All 20 produce their expected outcome, or a deviation is written down **with the line you will say**
- [ ] SQL/JS normalisation parity test passes on all 30 strings
- [ ] Pasted prompt and schema match their source files
- [ ] No secrets in workflow exports
- [ ] `make test-forbidden` passes
- [ ] Ten concurrent uploads produce ten rows, zero drops
- [ ] Cost-per-certificate measured and recorded for both branches
- [ ] Results table pasted into `PROGRESS.md`
- [ ] Total OpenAI spend still under $5

→ Continue to [Stage 9 — Demo operations](10-stage-9-demo-operations.md)
