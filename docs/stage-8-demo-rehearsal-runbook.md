# Stage 8 Demo Rehearsal Runbook

Stage 8 is a local demo-readiness pass. It does not add public HTTPS, mobile-data testing, authentication, new n8n workflows, or scripted fallback-video enforcement.

## Reset And Preflight

1. Start local services:

   ```powershell
   .\scripts\start-local.ps1
   ```

2. Confirm the local stack is healthy:

   ```powershell
   .\scripts\verify-local.ps1
   ```

3. Regenerate and verify the demo fixture run:

   ```powershell
   .\scripts\verify-stage-8-fixtures.ps1
   ```

4. For a rehearsal that sends a real approval email, run the opt-in live email path and approve the message when it arrives:

   ```powershell
   .\scripts\verify-stage-8-fixtures.ps1 -IncludeLiveEmail
   ```

   Without `-IncludeLiveEmail`, Stage 8 uses deterministic manual-trigger fixture runs and does not send Gmail messages.
   To send only the Stage 6 approval email rehearsal without rerunning all fixture scenarios first, use:

   ```powershell
   .\scripts\verify-stage-8-fixtures.ps1 -OnlyLiveEmail
   ```

   The live-email verifier reads the final Gmail message back by ID and records the Gmail labels in `docs/stage-8-fixture-results.md`. When `stage_6_approver_email` and `stage_6_test_recipient_email` are the same Gmail account, search Gmail All Mail for `subject:"Certificate request for Vista Glass and Door LLC"` if the message is not obvious in the primary Inbox.

5. Reset the demo immediately before rehearsing or presenting:

   ```powershell
   .\scripts\reset-demo.ps1
   ```

6. Confirm the opening dashboard shows 18 vendors and no certificate rows.

## Local URLs

- n8n editor: `http://localhost:5678`
- pgweb read-only Postgres browser: `http://localhost:8081`
- Dashboard active webhook: `http://localhost:5678/webhook/stage-7-dashboard-webhook/coi`
- Dashboard short webhook path, when active routing is registered: `http://localhost:5678/webhook/coi`
- Stage 5 upload form, when the intake workflow is published: `http://localhost:5678/form/coi-intake`

## Four-Minute Demo Sequence

1. Open the dashboard after `.\scripts\reset-demo.ps1`.
   Show the 18-vendor register, the no-certificate rows near the top, and the five-second refresh.

   Optionally keep pgweb open to `vendors`, `certificates`, `coverages`, `intake_notices`, and `outreach_log` so the local Postgres state is visible during the walkthrough.

2. Run the deterministic fixture verifier or a single Stage 5 manual fixture from n8n.
   Use `f02-expiring-20-days` for an amber state, `f05-inverted-dates` for review, and `f13-renewal-coverage-gap` after `f03-expired-34-days` to show renewal and gap tracking.

3. Refresh the dashboard.
   Point out the factual status text, carrier/policy/GL/expiry fields, amber flag notes, neutral cancellation wording, and source PDF link.

4. Open the Stage 6 daily watch workflow.
   Show that the watch list comes from Postgres state and is ready for approval-based chasing once local Gmail credentials are configured.

5. For a real email rehearsal, run `.\scripts\verify-stage-8-fixtures.ps1 -OnlyLiveEmail`, open the approval email, click Approve, and confirm the final sent row and Gmail message ID are logged.

6. End by resetting again:

   ```powershell
   .\scripts\reset-demo.ps1
   ```

## Fallback Lines

- Gmail delay: "The intake and watch logic is already in the local state table; Gmail delivery can lag, so I am using the deterministic manual fixture path for the live walkthrough."
- Approval-link issue: "The approval wait is an n8n execution state. If the email link is delayed, I can show the pending outreach row and then continue from a prepared approval run."
- Model/API issue: "The extraction step depends on the local OpenAI credential and API availability. The verifier records any variance, and the dashboard can still show the stored state from the last successful run."
- Internet loss: "This demo is local-first. The dashboard and database remain visible; external services only affect new model extraction or email delivery."

## Pre-Live-Demo Blockers

- Validate the public HTTPS URL from a non-local network.
- Test the dashboard and approval links over mobile data.
- Record and upload a fallback video before any real prospect demo.
- Keep credentials configured in n8n only; do not export or commit them.
