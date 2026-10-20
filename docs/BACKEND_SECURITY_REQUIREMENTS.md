# Backend security requirements

The Flutter client, custom URI parameters, local repository checks, and
`FinancialLedger` validation are not authorization boundaries. The backend must
authenticate the caller and enforce every rule below.

## Authorization matrix

| Operation | Server authorization |
| --- | --- |
| Read crib, expenses, settlements, activity | Active member only; historical access for removed users follows the approved policy. |
| Create expense | Active member; payer and participants are active members; crib currency matches. |
| Edit/delete expense | Actor is permitted creator/payer/admin under approved policy; reject protected/settled records; check version. |
| Create settlement | Active member; sender/recipient are active members; sender matches authenticated actor. |
| Confirm/cancel settlement | Recipient confirms; sender cancels pending request; no arbitrary status changes. |
| Create/revoke invitation | Owner/admin only. |
| Join invitation | Authenticated user; opaque token valid, unexpired, unrevoked, and approval rule satisfied. |
| Update/delete crib, role changes, remove member | Owner/admin only, with ownership-transfer safeguards. |
| Recurring schedule changes | Owner/admin or creator, as product approves. |

## Atomicity and integrity

- Scope every query by authenticated user's authorized crib IDs. Never fetch a
  record by ID alone and then trust a client-provided crib ID.
- Use database transactions for crib deletion with dependent records,
  membership changes, invitation acceptance, settlement creation/status changes,
  and recurring occurrence generation.
- Enforce foreign keys or equivalent checks for crib, member, expense,
  settlement, invitation, and recurring schedule references.
- Enforce unique IDs plus idempotency constraints for settlement creates and
  recurring occurrences. Recommended keys: `(crib_id, client_request_id)` and
  `(recurring_payment_id, occurrence_date)`.
- Persist a row version/updated timestamp. Expense and crib update/delete
  mutations must use compare-and-swap and return `conflict` rather than silently
  overwriting concurrent edits.
- Validate integer minor-unit amounts and exact share sums server-side with the
  same financial rules as the client.

## Threat-specific requirements

### Cross-crib access

All reads and writes must verify active membership in the target crib. IDs,
DTOs, deep links, QR payloads, and cached local objects are untrusted input.

### Invitations

Do not use `paycal://crib/<cribId>` as a production invitation credential.
Resolve opaque tokens only on the server, reject forged/expired/revoked tokens,
rate-limit attempts, and audit creation, acceptance, rejection, and revocation.

### Expenses and settlements

Reject unauthorized modification even if the caller knows an expense or
settlement ID. Use idempotency keys to make retried requests safe. Reject or
explicitly handle duplicate settlement requests and overpayments atomically
against the latest ledger state.

### Removed members and historical records

Removal must atomically end active membership and prevent future writes/reads
outside approved historical access. Never mutate old payer/participant IDs to
make deletion easier; preserve an immutable audit trail.

### Operational security

- Short-lived access tokens, refresh-token revocation, secure device storage,
  and server-side session invalidation.
- Rate limits and abuse monitoring for auth, invitation, and mutation endpoints.
- Audit events include actor ID, crib ID, target ID, action, timestamp, request
  ID, and before/after version metadata.
- Server-generated timestamps and IDs for authoritative records.
- Encryption in transit and at rest; secrets never ship in the Flutter app.
