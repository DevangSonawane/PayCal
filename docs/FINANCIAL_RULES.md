# PayCal financial rules (Phase 1)

This document describes the client-domain rules. A backend must enforce the
same invariants authoritatively; client validation is for fast feedback only.

## Amounts and currencies

- Amounts and shares are non-negative integer minor units. An expense or
  settlement amount must be greater than zero.
- Every crib has one currency. Its expenses and settlements must use that
  exact currency. PayCal never aggregates balances from different currencies.
- One crib's currency must not be changed after transactions exist until a
  future server-side migration policy is approved.

## Expenses and splits

- The payer and every split participant must be current crib members.
- An expense has at least one participant and its shares must add exactly to
  its total. A participant can occur only once because shares are keyed by
  member ID.
- Equal and percentage splits use integer minor units only. Percentage input is
  converted to basis points (100% = 10,000 basis points), which must total
  exactly 10,000.
- When integer division leaves minor units, the payer receives the first unit
  when they participate; otherwise the first supplied participant does.
  Additional units follow supplied participant order. This is deterministic and
  guarantees the shares equal the original total.
- Editing or deleting an expense is not a special balance operation: balances
  are recalculated from the currently stored expenses and settlements.

## Balances and settlements

- A positive balance means the member is owed; a negative balance means they
  owe the crib.
- A settlement is a separate financial record, never a synthetic expense. It
  must have different, valid sender and receiver members.
- `confirmed` and `selfManaged` settlements affect balances. `pending` and
  `cancelled` settlements do not.
- Partial settlements are valid and reduce only the relevant sender/receiver
  balance. Suggested transfers are recalculated after every ledger change.
- The current crib-wide “Record transfers” action creates `selfManaged`
  settlements to preserve its former immediate-settlement UX. Confirmation,
  cancellation and idempotency policy are intentionally deferred to Phase 3.
