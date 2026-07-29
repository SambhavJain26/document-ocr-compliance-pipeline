# Stage 9 — Demo operations

**Document 10 · Estimated time: 0.5 day + rehearsal · Cost: ~$0.012 per demo**

Everything between "it works" and "it worked in front of a stranger". Pre-call setup, the reset script, the health check, failure recovery, and the rehearsal protocol.

**Gate:** you can run the full demo in under four minutes, twice, without looking at notes — including once with your wifi turned off mid-run.

---

## 9.1 The pre-flight check

Run this the morning of every demo. Not the night before — OAuth tokens and TLS certificates expire on their own schedule.

`db/scripts/preflight.sh`:

```bash
#!/usr/bin/env bash
# Morning-of-demo health check. Everything that has ever broken on a call.
set -uo pipefail
cd "$(dirname "$0")/../.."
set -a; source .env; set +a

FAIL=0
ok()  { printf "  \033[32m✓\033[0m %s\n" "$1"; }
bad() { printf "  \033[31m✗\033[0m %s\n" "$1"; FAIL=1; }
COMPOSE="docker compose -f infra/docker-compose.yml"

echo "── Services ──────────────────────────────────────"
for s in postgres n8n caddy; do
  st=$($COMPOSE ps --format '{{.Service}} {{.State}}' | awk -v s="$s" '$1==s{print $2}')
  [ "$st" = "running" ] && ok "$s running" || bad "$s is '$st'"
done

echo
echo "── TLS ───────────────────────────────────────────"
exp=$(echo | openssl s_client -servername "$N8N_HOST" -connect "$N8N_HOST:443" 2>/dev/null \
      | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$exp" ]; then
  days=$(( ( $(date -d "$exp" +%s) - $(date +%s) ) / 86400 ))
  [ "$days" -gt 7 ] && ok "cert valid $days more days" || bad "cert expires in $days days"
else
  bad "could not read the TLS certificate"
fi

echo
echo "── Webhook reachability ──────────────────────────"
code=$(curl -s -o /dev/null -w '%{http_code}' "$WEBHOOK_URL")
[ "$code" != "000" ] && ok "webhook host answers ($code)" || bad "webhook host unreachable"

echo
echo "── Dashboard ─────────────────────────────────────"
# /healthz returns 200 well BEFORE webhook routes are registered — n8n's
# community-node-types and MCP-registry calls each time out at up to 6s,
# leaving a ~20-30s gap after any restart. Checking once inside that window
# reports a false failure, and on demo morning a false failure costs almost
# as much as a real one. Retry for 40s.
tok=$($COMPOSE exec -T postgres psql -tAq -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -c "SELECT value FROM client_config WHERE key='dashboard_token'")
deadline=$(( $(date +%s) + 40 )); code=000
printf "  waiting for webhook routes "
while [ "$(date +%s)" -lt "$deadline" ]; do
  code=$(curl -s -o /tmp/dash.html -w '%{http_code}' "${WEBHOOK_URL}webhook/coi?k=${tok}")
  [ "$code" = "200" ] && break
  printf "."; sleep 2
done
printf "\n"
if [ "$code" = "200" ]; then
  ok "dashboard 200 ($(wc -c </tmp/dash.html) bytes)"
else
  bad "dashboard returned $code after 40s"
  echo "     If the workflow shows active, check for a missing webhookId on the"
  echo "     trigger node — that 404s silently. See docs/12 §12.2."
fi

echo
echo "── Model ─────────────────────────────────────────"
mid=$($COMPOSE exec -T postgres psql -tAq -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -c "SELECT value FROM client_config WHERE key='model_id'")
code=$(curl -s -o /tmp/oai.json -w '%{http_code}' https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
  -d "{\"model\":\"$mid\",\"input\":\"ok\",\"max_output_tokens\":16,\"reasoning\":{\"effort\":\"low\"}}")
if [ "$code" = "200" ]; then
  ok "model $mid responding"
else
  bad "model $mid returned $code — $(head -c 200 /tmp/oai.json)"
  echo "     Check whether the pinned snapshot has been retired."
fi

echo
echo "── Gmail OAuth ───────────────────────────────────"
echo "  ! Manual: open n8n → Credentials → 'Gmail account' → Reconnect if it warns."
echo "    An expired refresh token is silent. Check it with your eyes."

echo
echo "── Workflows active ──────────────────────────────"
act=$($COMPOSE exec -T postgres psql -tAq -U "$POSTGRES_USER" -d n8n \
        -c "SELECT count(*) FROM workflow_entity WHERE active" 2>/dev/null || echo "?")
ok "active workflows: $act (expect 3: intake, dashboard, status override)"

echo
echo "── Demo state ────────────────────────────────────"
$COMPOSE exec -T postgres psql -tAq -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c "SELECT bucket || ': ' || count(*) FROM v_vendor_status GROUP BY bucket ORDER BY 1"

echo
[ "$FAIL" -eq 0 ] && printf "\033[32mREADY\033[0m\n" || printf "\033[31mNOT READY — fix the ✗ items\033[0m\n"
exit $FAIL
```

```makefile
preflight:  ## Morning-of-demo health check
	@bash db/scripts/preflight.sh
```

---

## 9.2 The canary job

The pre-flight script catches things you remember to run. The canary catches the ones you do not.

**This product's failure mode is silence.** If the Gmail Trigger quietly stops polling, nothing looks broken — certificates just stop arriving, and nobody notices for six weeks. That is the exact failure this product exists to prevent, which makes it the failure that would end an engagement.

`COI · 6 · Canary` — a weekly workflow (production: daily):

```
[Schedule — Mon 06:00]
      ▼
[Gmail — Send]  a known fixture to the intake address, subject "CANARY <ts>"
      ▼
[Wait 5 minutes]
      ▼
[Postgres — Did it land?]
      ▼
[IF found] ──no──▶ [Telegram: 🔴 CANARY FAILED — intake pipeline is not running]
      │ yes
      ▼
[Postgres — clean up the canary rows]
```

```sql
-- Did it land?
SELECT count(*) AS found
FROM   certificates
WHERE  source_ref LIKE 'CANARY-%'
  AND  received_at > now() - interval '10 minutes';
```

The canary catches, in one test, every one of:

- Gmail OAuth refresh token expiry — **the most common silent killer**
- A retired model ID
- Postgres out of disk
- n8n stopped and never restarted
- Expired TLS breaking the webhook
- An accidentally deactivated workflow

Build it before your first demo, not before your first client. You will schedule a demo, not touch the system for nine days, and find out on the call that the Gmail token expired on day seven.

---

## 9.3 Demo state and reset

### Opening state

| Element | Value |
|---|---|
| Vendors | 18, **their real names** wherever you got the list |
| Certificates | 0 |
| Dashboard | all 18 grey, header reads `18 vendors · 18 no certificate on file` |
| Outreach log | empty |

### Before the call

```bash
make preflight     # must print READY
make demo-reset    # under 2 seconds
```

Then, in order:

- [ ] Dashboard open in a **second browser tab**, already loaded, token not visible in a screen-share
- [ ] Fixture 2 drafted as an email, addressed to the intake address, **not sent**
- [ ] Fixtures 3 and 13 in a folder on the desktop, ready to drag
- [ ] Approver email confirmed — theirs, asked for when scheduling
- [ ] Their phone in frame if on video
- [ ] **Your** phone on the desk on mobile data, as the fallback approver
- [ ] Fallback video open in a background tab
- [ ] n8n editor open on Workflow 2, ready for a manual run
- [ ] Notifications silenced, second monitor cleared, browser bookmarks bar hidden

---

## 9.4 The demo script

**4 minutes 10 seconds of demo. Budget 12–15 minutes for the call including discovery and the close.**

The strongest moment is at **3:05** — the prospect taps Approve on their own phone. Everything before it is setup. Do not move it earlier: they need to have seen the problem before they can appreciate the control.

### 0:00 – 0:35 · Send first, talk second

> *"Before I show you anything, let me start something running in the background."*

Send the fixture 2 email. Switch to the dashboard tab.

> *"That's a vendor certificate, sent to a monitored address, exactly the way one of your vendors or their agent would send it to you. It'll take about a minute. While it works — this is the register. Your eighteen vendors. Right now the system knows who they are and nothing else."*

Pause on the grey rows.

> *"Every one of these is grey because there's no certificate on file. Four of them will still be grey at the end of this call — and those four are the ones I'd want to look at first, because 'expiring soon' is a calendar problem and 'we've never had anything from them' is a different problem entirely."*

**Use their own vendor names out loud.** *"Right now the system knows Mercer and Kessler and Alder exist and nothing else"* lands very differently from a list of strangers.

> **Why this sequencing is the single most important decision in the script:** the Gmail Trigger polls on a one-minute cycle. Send the email at 2:00 and stand there watching, and that minute is the longest minute of your professional life. Sending it first turns polling latency into narrative time.

### 0:35 – 1:30 · Make them describe their own problem

> *"Quick question while that runs — when Mercer Plumbing shows up at a property on Thursday, how do you know his general liability is current that day?"*

**Then stop talking.** Let the pause be uncomfortable.

Most will describe a spreadsheet, a shared drive folder, or admit they do not really know. **That admission is the entire sale.** You have not claimed anything yet; they have diagnosed themselves.

> *"That's normal — nearly everyone I talk to is somewhere in that range. Buildium will warn you at assignment if the date someone typed in has already passed. Two gaps: somebody has to type it in first, and the warning fires when you're already dispatching, which is exactly when people override it."*

### 1:30 – 2:00 · The reveal

The page refreshes itself. The Kessler HVAC row has filled in.

> *"There it is. Vendor, carrier, policy number, the general liability limit, and the expiry date — all read off the certificate. Nobody typed anything."*

Pause on the amber.

> *"And it's amber, because that policy expires in twenty days."*

Click through to the source PDF.

> *"That's the actual document, one click away. You don't have to trust the system — every field is next to the thing it came from. It's doing the typing, not the deciding."*

**That sentence is the most important thing you say in the whole demo.** It is what makes an unproven freelancer safe to hire. Say it slowly.

### 2:00 – 2:20 · The red row

Drag fixture 3 into the upload form.

> *"Here's one that came in through the upload page instead of email — same pipeline. This one's Mercer Plumbing."*

Row appears red.

> *"Expired thirty-four days ago. Nobody knew. There was no alert, because there was no system — just a folder and the hope that somebody would remember."*

### 2:20 – 2:35 · The one they did not see coming

Drop in fixture 13.

> *"Last one. This is Mercer's renewal, the replacement for that expired policy."*

Row turns green, then the flag appears.

> *"Green — but look at that note. Old policy ended the first of March, new one started the fifteenth. That's a fourteen-day window where he was working your properties uninsured. Nobody was going to catch that. Not a spreadsheet, not Buildium, not a person comparing two PDFs six months apart."*

Let it sit. Second-best moment in the demo, and it costs fifteen seconds.

### 2:35 – 3:05 · The draft

Trigger Workflow 2 manually.

> *"So here's what happens next. The system drafts the chase email — addressed to the agent, not the plumber, because the agent is the one who can actually produce the certificate. Policy number's already in it. Expiry date's already in it."*

Show the body.

> *"But it doesn't send it."*

### 3:05 – 3:35 · **THE MOMENT**

Their phone buzzes — an email, in whatever mail app they already use.

> *"Check your email."*

**Wait. Let them pick it up. Do not narrate.**

> *"That's the draft, and two buttons. Nothing goes out to a vendor unless a person taps Approve. Go ahead — tap it."*

They tap. The email sends.

> *"That just went out from your address, to that agent, and it's logged. If they ignore it, in seven days it drafts one follow-up — which you approve the same way. If they ignore that one too, you get a message. Two ignored requests escalate to a human, not to more automation."*

The whole demo is engineered around one sentence you want them to say to themselves: **"I approved that. It didn't do it on its own."** That is what makes a stranger from another country safe to hire.

If you could not get their address in advance, use your own phone and hand it over in person, or hold it to the camera and tap it yourself while narrating. Materially weaker — get the address when you book the call. **Never make this moment depend on them installing anything.**

### 3:35 – 4:10 · Name the limitation before they find it

> *"One thing I want to say before you ask, because you'd find it eventually and I'd rather you heard it from me. This reads the certificate and tracks the dates. It cannot tell you that you're covered. A certificate is an information document — it doesn't amend the policy, and the 'additional insured' box is an assertion someone ticked, not proof. Actual additional-insured status comes from a carrier endorsement, and no tool at this price verifies endorsements. If you need that, you want an enterprise compliance platform, and I'll tell you that rather than pretend otherwise."*

> *"What this does is make sure a certificate never expires without anyone noticing, and take the chasing off your desk."*

This paragraph wins deals. With no track record, naming your own ceiling is the fastest credibility available to you.

### The hand-over

> *"Want to try it? I'll send you the upload link — drop any PDF in it, doesn't have to be a certificate, and see what it does."*

Send the Form Trigger URL in chat. Let them break it. Fixture 11's behaviour means a junk PDF produces a clean, honest *"this isn't a certificate"* rather than garbage. **Letting a prospect try to break something in front of you, and having it behave well, is worth more than any feature.**

### The closing ask

> *"Here's what I'd like to do, and it's smaller than you're expecting. Email me ten of your actual vendor certificates — whatever's in the folder, however messy. No system access, no credentials, no integration, nothing touching Buildium. I'll run them tonight and send you back a one-page picture of where you actually stand: who's current, who's expiring, who's lapsed. Tomorrow morning. It costs you nothing, and if the answer is 'we're fine', I'll tell you that and we'll leave it there."*

It requires no trust, no budget, no IT involvement, and no decision. And it inverts the relationship — you are no longer selling, you are producing a finding. When you come back with *"seven of these ten expired more than ninety days ago"*, they are no longer evaluating you; they are dealing with a problem.

If they hesitate, shrink it: *"Send me three."*

---

## 9.5 Failure recovery

**Rehearse the lines out loud.** Reading them cold is how a small failure becomes a large one.

| What breaks | Likelihood | What you say | What you do |
|---|---|---|---|
| **Approval button 404s** | **Highest** | *"That's my webhook URL, not the workflow — one second."* | Approve from the n8n Executions view on screen: *"Same gate, just approving it from here."* Concept survives; only the theatre is lost. |
| **Gmail Trigger does not fire** | Medium | *"Email polling is on a one-minute cycle and it's being slow — let me use the upload page instead, same pipeline."* | Drag the fixture into the form. Rehearse this switch until it is smooth. |
| **OpenAI 429 / 500** | Low | *"That's the model API rate-limiting me — this is why the system retries rather than failing silently."* | Re-run the node. Twice failed → cut to a pre-processed row: *"Here's one I ran this morning."* |
| **Internet drops** | Low | *"I've lost my connection — give me thirty seconds, and if it doesn't come back I've got a recording."* | Phone hotspot first, then the fallback video from your phone. **Never** debug infrastructure live. |
| **Extraction gets a field wrong** | Medium | *"Good — this is exactly what I want you to see."* | Show it flagged, or open the source PDF beside it. A visible wrong answer next to its source proves the review model works. Do not apologise; explain the gate. |
| **Dashboard renders broken** | Low | *"Let me pull it up fresh."* | Second tab is already open. This is why you open it before the call. |
| **Model ID retired overnight** | Low | *"One of my dependencies moved under me this morning — one second."* | `UPDATE client_config SET value='gpt-5.6-luna' WHERE key='model_id';` One SQL statement, no workflow edit. This is why the ID lives in the database. |
| **They ask something you cannot answer** | High | *"I don't know. I'll find out and tell you today."* | Then actually do it, same day. With no track record, one kept small promise beats a confident guess. |

**The rule for all of these:** never debug in front of a prospect. Acknowledge, switch to the alternate path, keep moving. A demo that hits a snag and recovers calmly reads as *a real system built by a competent person*. A demo where someone opens a terminal reads as *a prototype*.

### The nuclear option

If three things fail, stop:

> *"This isn't going well and I'm not going to waste your time fighting it. Let me do this instead — send me ten of your certificates and I'll send you back the actual output tomorrow. That's a better proof than a live demo anyway."*

That recovers more deals than grinding through. It is also, straightforwardly, true.

---

## 9.6 The fallback video

Record it once, before your first live demo.

- 4 minutes, perfect run, **including the phone** in frame for the approval moment
- No audio, or a light voiceover — you will be talking over it
- Under 100 MB, uploaded somewhere you can link to from your phone
- Open in a background tab before every call

It is also your follow-up asset: send it after the call so whoever was not on the call can watch it.

---

## 9.7 Rehearsal protocol

**Five full runs.** Not five readings — five runs with the system live and a timer going.

| Run | Focus |
|---|---|
| 1 | Mechanics. Do not worry about time. Find every place you fumble. |
| 2 | Timing. Get under 4:30. |
| 3 | **Turn your wifi off at 2:15.** Practise the recovery out loud. |
| 4 | **Have someone else tap Approve** on a phone you have not touched. |
| 5 | Full run, no notes, under 4:00, including the closing ask. |

Runs 3 and 4 are the ones people skip and the ones that matter. The failure lines have to sound relaxed, and relaxed only comes from having said them enough times that they are boring.

### Say these out loud until they are boring

- *"It's doing the typing, not the deciding."*
- *"It cannot tell you that you're covered."*
- *"That's my webhook URL, not the workflow — one second."*
- *"I don't know. I'll find out and tell you today."*

---

## 9.8 Rehearsed answers to the questions you will get

These need no build. They need saying out loud. Every one is a question a serious buyer asks and an unserious one does not — treat them as buying signals, not attacks.

### "What if the policy gets cancelled mid-term?"

> *"It won't catch that, and neither will anything else that reads a certificate — including the enterprise platforms. Since the 2010 ACORD revision the carrier's obligation runs to the insured, not to you as certificate holder. The only thing that gets you real notice is being scheduled onto the vendor's policy by endorsement, and most national carriers don't offer that any more. What I can do is shrink the window: instead of finding out at renewal twelve months later, we re-confirm every ninety days. That's not monitoring and I won't call it monitoring — it's asking more often."*

### "What happens if you disappear?"

> *"Fair question, and you should ask it. Three things. It runs on your server, not mine. The workflows export as a file you keep. And the data is a standard Postgres database you own. If I vanish, any n8n developer can pick it up — and worst case you're back to the spreadsheet you have today, which is where you'd be anyway. You're not handing me anything you can't take back."*

### "You're in India — what if something breaks at 9am my time?"

> *"I'm about nine and a half hours ahead, so I work while you sleep. In practice, anything you flag at end of day is usually fixed before you're back at your desk. If something breaks at nine in the morning your time, you'll wait a few hours — which is why nothing in this system is time-critical by design. It drafts and notifies; it never has to act inside a deadline. That's deliberate."*

### "I'm not comfortable emailing you our vendor documents"

> *"Completely reasonable, and I'm happy to sign an NDA before you send anything. Worth saying though — these are documents your vendors hand to anyone who asks for one. There's no tenant data in them, no financial data, no bank details. If it helps, start with three instead of ten."*

### "Isn't this just a spreadsheet with extra steps?"

> *"For twelve vendors, honestly, yes — and I'd tell you not to buy it. The break point is somewhere around fifteen to twenty regular vendors, because that's where nobody can hold the dates in their head any more and the spreadsheet stops being updated. How many do you use regularly?"*

Being willing to disqualify them is the most persuasive thing you can do.

### "Where does our data actually go?"

> *"Three places, and that's the whole list. The certificates and the extracted data sit in a Postgres database on a server in Virginia — in production, on a server that belongs to you. The certificate content goes to OpenAI's API for the reading step; under their API terms that data isn't used to train models and is retained up to thirty days for abuse monitoring, then deleted. And the emails go through your own Google Workspace. Nothing touches Buildium — the system has no credentials to it and no way to write to it. I'll send you the link to OpenAI's own privacy page rather than paraphrasing it."*

Have that link open in a tab. Citing the provider's page beats paraphrasing from memory.

**If they push on the OpenAI retention specifically** — and a sharp one will, because it was in the news:

> *"Worth me raising this before you find it. In 2025 a court order in the New York Times case temporarily required OpenAI to preserve API content that would normally have been deleted on the thirty-day cycle. OpenAI has since stated they've returned to standard deletion. So the honest answer is: there was a litigation hold, it's been lifted, and I can send you their statement. I'd rather tell you that than have you read about it next week and wonder what else I didn't mention."*

The value here is not the fact. It is being the person who raised it. Volunteering an awkward detail about your own supplier is the cheapest credibility available to someone with no track record — and the answer is genuinely fine, so you lose nothing by giving it.

### "What about Certificial / TrustLayer / [competitor]?"

**Be able to name Certificial before they do.** It is the one real competitor at your price point — published requestor pricing starts around **$99/month** — and it solves the mid-term cancellation problem you cannot, by connecting to the insurance agent's agency management system for live policy data rather than parsing static PDFs.

> *"That's the right product if you want live policy status, and it's genuinely better than what I do on that specific axis — it plugs into your vendors' agents' systems rather than reading PDFs. Two things I'd check before you sign up. Whether your vendors' agents are actually on their network, because if they're not you fall back to ordinary document review. And whether you want to run a vendor onboarding programme to get them there, because that's real work for your team. What I do is narrower and needs nothing from anybody — certificates arrive by email and get chased. If you want the live version, go look at them. I'd rather tell you that than lose your trust in month three."*

That answer costs you nothing and buys an enormous amount. Most prospects at 200–600 doors will not run a vendor-onboarding programme, **which is the actual reason your product exists.**

The rest of the field, so you are not caught blank:

| Platform | What it actually does | Your line |
|---|---|---|
| **Certificial** | AMS-connected live policy data, 25,000+ agencies claimed, ~$99/mo entry | The one to name first. See above |
| **TrustLayer** | COI automation with real-time validation via direct carrier partnerships | Carrier coverage spans a limited subset; vendors outside it fall back to document review. Enterprise-priced |
| **NetVendor** | Enforcement-grade PMS integrations where compliance status gates work-order eligibility | The "block dispatch automatically" product. Enterprise multifamily, above your segment |
| **myCOI, Jones, CertFocus** | Document-based tracking with human review teams | Enterprise portfolios. **Same structural blind spot you have** |

> **Treat the entire comparison genre as adversarial marketing.** Almost everything published comparing these platforms is written by one of them about the others. Verify anything that would change a decision.

**Why you cannot build the AMS-connected version**, if asked: live policy status flows carrier → agency over rails like IVANS, into agency management systems such as Applied Epic, AMS360, HawkSoft and EZLynx. Your client is a third party with no seat on that rail. The moat is not code — it is having signed up 25,000 insurance agencies. That is years and a sales team, and no amount of n8n substitutes for it. Saying this plainly is far stronger than being vague about it.

### "Buildium already tracks this"

> *"It does — it warns you at assignment if the date someone typed in has already passed. Two gaps. Somebody has to type the date in first, and the warning fires when you're already dispatching, which is exactly when people override it. This fills the certificate in automatically and tells you thirty days early, when there's still time to do something about it."*

### "We've never had a problem"

> *"Most companies haven't. The question isn't whether it's happened — it's how long it'd take you to find out when it does. Want me to run your current vendor folder through it? I'll tell you in ten minutes where you actually stand."*

**That is a strong close disguised as an objection handler.** Offer it free, immediately, every time.

### "Can't I just set calendar reminders?"

> *"You can, and some do. The reminders are the easy half. The annoying half is opening each PDF, reading four date fields, typing them somewhere, then emailing the agent and following up when they ignore you. That's the part this removes."*

### "How much?"

Do not let them ask first. Name it immediately after the closing ask, anchored against the right comparison:

> *"Six hundred to set up, two-fifty a month. The way I'd frame that: people hire an offshore VA for exactly this work, and those packages run a thousand to twenty-five hundred a month. This does the chasing part for a fraction of that, doesn't need training, and doesn't quit. And for the first couple of clients I'm pricing below that in exchange for a written testimonial — I need case studies more than I need the margin, and I'd rather be straight with you about why."*

Naming the discount's motive is stronger than hiding it — and if you use their testimonial in marketing, the FTC requires the connection be disclosed anyway. Get the honest habit early.

---

## 9.9 The free-trial run

The closing ask produces ten real certificates. That run is your actual product demonstration, and it costs about five cents.

```bash
mkdir -p /tmp/trial && cp ~/Downloads/prospect-certs/*.pdf /tmp/trial/
for f in /tmp/trial/*.pdf; do
  curl -s -F "Certificate_(PDF)=@$f" "$N8N_BASE_URL/form/coi-upload" >/dev/null
  sleep 4
done
```

Before running: seed their real vendor names, their real legal entity in `holder_entities`, and their real minimums in `client_config`. Running against demo config produces holder mismatches on every certificate, and you would be showing them a bug rather than a finding.

**Then delete their data when the engagement ends or the deal dies.** Offer that in writing. It is a small promise that is easy to keep and it removes a real objection.

### The deliverable

One page, next morning:

```
Vendor certificates — where you stand as of 30 July

  10 certificates reviewed

   3  expired more than 90 days ago
   1  expires within 30 days
   2  name a different entity as certificate holder
   1  general liability limit below $1M
   3  current, nothing needed

  The three expired: Mercer Plumbing (expired 4 Mar, 148 days),
  Alder Landscaping (expired 22 Jan, 189 days), Rowan Roofing
  (expired 11 Apr, 110 days).

  One thing worth flagging: two of these name "Beacon Ridge Realty"
  as certificate holder rather than your company. That's usually an
  agent copying a previous job's template. Worth a note to them.

  This tracks what the certificates say. It doesn't confirm coverage
  is in force today, and it can't verify endorsements.
```

That last paragraph belongs on the page. The whole business rests on the client believing what you tell them, and the fastest way to earn that is to volunteer the limit on the same page as the finding.

---

## 9.10 What changes for a paying client

Not demo scope. Listed so you can answer *"what would this look like in production?"* without inventing on the spot.

### Robustness
- Error Trigger on every workflow → Telegram with workflow, node, and execution URL *(already built in Stage 5)*
- Retry with backoff on all model calls and Gmail sends *(already built)*
- Dead-letter table *(already built)*
- Idempotency on content hash *(already built)*
- **Daily** canary instead of weekly

### Silent-failure monitoring
- Heartbeat: every morning, confirm each active workflow executed in the last 24h
- Weekly digest to the client: *"3 certificates processed, 2 reminders sent, 1 awaiting review."* Proves it is alive in a quiet week and is a retention tool
- Uptime Kuma on the dashboard webhook

### Real-data edge cases you will hit
- Vendor legal names that do not match how the client refers to them → `vendor_aliases` *(schema already supports it)*
- Multi-page certificates with a remarks schedule attached
- Certificates arriving as images in the email body rather than as attachments
- Agencies that send a ZIP of certificates
- Vendors with two active policies from different carriers mid-switch

### Security
- Basic auth or SSO on the n8n editor; never expose it publicly
- `N8N_ENCRYPTION_KEY` in a secret manager, not in `docker-compose.yml`
- Form Trigger rate-limited, PDF-only, 10 MB cap
- Certificate PDFs on an encrypted volume
- Separate OpenAI API key per client with per-key spend limits
- Tested Postgres restore, not just a backup

### Onboarding — build this before client one, not after
- Vendor import: CSV template, or a guided session where you seed the list together on a call
- Historical backfill: their existing certificate folder in one batch. This is also the free-trial deliverable
- Config interview: legal name(s), minimum limits, reminder cadence, who approves, which mailbox sends
- A one-page runbook: what the statuses mean, what to do with a `NEEDS_REVIEW` row, who to contact
- **Approver training** — fifteen minutes on the gate. The whole trust model depends on a human actually reading before approving. If they start rubber-stamping, the product's honesty claim quietly becomes false

### Commercial and legal
- Written scope stating explicitly what the system does not do. Reuse the honesty list verbatim. This is the document that protects you if a lapsed policy ever becomes a dispute
- Professional indemnity insurance before client two
- n8n hosted on the client's infrastructure — the safer licence position under the Sustainable Use License *and* the better sales position: *"it runs on your server, I just build and maintain it"*
- One-page data processing terms: what you store, where, for how long, what happens on termination
- Exit plan: *"you keep the database and the workflows export as JSON"* — removes a real objection from a solo supplier and costs nothing

---

## Stage 9 exit checklist

- [ ] `make preflight` exits 0 and checks services, TLS, webhook, dashboard, model, workflows
- [ ] Canary workflow built and verified by deliberately breaking the pipeline once
- [ ] `make demo-reset` returns the opening state in under 2 seconds
- [ ] Fallback video recorded, under 100 MB, linkable from your phone
- [ ] Five full rehearsals done, including one with wifi off and one with someone else approving
- [ ] All four key lines said out loud until boring
- [ ] All eleven rehearsed answers said out loud — including **Certificial**, which you should be able to name before they do
- [ ] Competitor table read at least once; you can place TrustLayer, NetVendor and myCOI without hesitating
- [ ] The OpenAI litigation-hold answer rehearsed, and their statement bookmarked
- [ ] OpenAI privacy page bookmarked and ready to send
- [ ] Free-trial procedure tested end to end on the fixture set
- [ ] Full demo under 4 minutes, twice, without notes

**The build is complete.** Go sell it.
