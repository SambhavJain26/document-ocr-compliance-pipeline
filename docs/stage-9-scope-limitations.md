# Stage 9 Scope And Limitations

This document is the plain-language scope boundary for a production client.

## What The System Does

The system tracks vendor certificate paperwork. It receives certificate PDFs, extracts date and document facts, stores those facts in Postgres, shows the source PDF next to the extracted fields, and drafts reminder emails for human approval.

It helps the client see:

- which vendors have no certificate on file
- which certificates are expired
- which certificates are approaching an expiration date
- which documents need human review
- which reminders were drafted, approved by a human, and sent

## What The System Does Not Do

The system does not verify coverage.

It does not:

- confirm that a policy is active with the carrier
- confirm additional insured status
- interpret endorsements
- detect forged certificates
- detect mid-term cancellation
- know about vendors missing from the provided vendor register
- decide whether a vendor may work on a property
- update the client's property management system
- replace the client's insurance broker, attorney, or risk manager

## Language Boundary

Use date and document facts:

- `Current until <date>`
- `Expires in <n> days`
- `Expired <n> days ago`
- `No certificate on file`
- `Needs review`

Do not describe a vendor as compliant, verified, covered, or approved. A human may approve sending a reminder email; that is not an approval of the vendor.

## Human Approval Boundary

Outbound vendor chase emails require a human approval step. The approver is responsible for reading the draft before approving it. The system logs approval and send facts, but it does not decide risk.

## Source Document Boundary

Every extracted field should remain traceable to the source PDF. If a scan is poor, a document is password-protected, a holder name is unclear, or a vendor match is uncertain, the system should route the item to review instead of guessing.

## Client Responsibility

The client remains responsible for:

- maintaining the vendor register
- confirming holder entities and trade requirements
- deciding what to do with review rows
- asking brokers or carriers for endorsement or policy-status confirmation when needed
- training approvers not to rubber-stamp outbound messages

## Operator Responsibility

The operator is responsible for:

- keeping workflows and credentials healthy
- monitoring errors, dead letters, heartbeat, canary, and backups
- documenting outages and fixes
- exporting client data on request or termination
- not expanding claims beyond certificate paperwork tracking
