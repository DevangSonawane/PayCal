# Account deletion and retention requirements

Status: requirements only. The product rules for v1 are approved
(`PRODUCT_RULES.md` §7); the retention numbers below are deliberately **not**
defined, because they need legal and privacy input.

## Scope

This document describes what has to happen when somebody deletes their
account, and what the app is not allowed to do while doing it. It does not
define how long anything is kept.

## Requirements

### 1. The account itself

- The Auth account is permanently deleted, and its sessions and device tokens
  are revoked immediately.
- The user id is immutable and never reused, so audit records that point at it
  stay readable after the display name is gone.
- Whether a removed person may re-register with the same email is a product
  and fraud-prevention decision; the old Auth account no longer exists.

### 2. Shared financial history

- Deleting an account must not erase shared financial history. Expenses,
  settlements, cribs and activity stay, because other members' balances and
  records depend on them.
- The display identity in historical records is replaced with a retained or
  anonymised label, for example "Removed member". The internal user id stays
  the reference for audit and fraud handling.
- Nothing in a financial record is rewritten to make deletion easier. No
  payer, participant or member id is mutated.
- Membership of the deleted account in a crib ends. Whether the deleted
  account keeps read-only access to its own historical records is **not
  decided** (see `PRODUCT_RULES.md` §1).

### 3. Invitations and sessions

- Invitations the user created are revoked, so their links stop working
  immediately. Members that already accepted keep their membership.
- Active sessions, refresh tokens and device tokens are invalidated.
- Pending invitation requests that the user sent are withdrawn.

### 4. Data that is not kept

- Device-local profile data (the cached display name and email in
  `AppSettings`) is cleared on the device.
- The in-memory prototype has no deletion call: its `deleteAccount()` is a
  `signOut()`. The real deletion is the `delete-account` edge function, so the
  in-memory checks are not a security boundary
  (`BACKEND_SECURITY_REQUIREMENTS.md`).

## Not decided, and why

| Question | Why it is open |
| --- | --- |
| Retention period of financial records | A legal obligation, not a product choice. |
| Retention period of anonymised profile data | Depends on the same legal review. |
| Export requirements (for example a data download) | Depends on jurisdiction. |
| Region-specific deletion obligations | Depends on the markets the app ships in. |
| Whether an anonymised label is kept forever or re-randomised | Depends on the fraud-handling requirement. |

No number in this document is a retention promise. Filling these in is a
legal/privacy task, and the implementation must follow whatever it produces.

## Open implementation work

- A `UserDirectory` contract to look up members by id. Still open.
- The retention numbers of the table above. Still a legal/privacy task.

## What is implemented

- `supabase/functions/delete-account` closes memberships, anonymises the
  profile, revokes pending invitations, then permanently deletes the matching
  `auth.users` record. The anonymised profile remains because shared financial
  history references it.
- An account that only takes part in a crib leaves it as part of the deletion:
  `crib_members.left_at` is set (the history of the member stays reachable)
  and the response lists the cribs it left in `left`.
- An account that still owns an active crib is refused with `409` and
  `{ "error": "...", "blocked": [{ "id", "name" }] }`. The crib has to be
  handed over or deleted first, because a crib must never end up without an
  owner. The response is idempotent: repeating the call after the ban repeats
  the same updates and returns the same result.
- The profile screen turns that refusal into the next step for the member: a
  popup lists every crib that still keeps the account and offers Leave, Hand
  over or Delete per crib. The account is only confirmed for deletion once no
  crib is left.
- The same three actions are discoverable from the crib itself: the group
  details sheet offers "Hand over this crib", "Leave this crib" and, for the
  owner, "Delete this crib". Both screens share
  `lib/features/cribs/crib_membership_actions.dart`, so the confirmation and
  the refusal handling cannot drift apart.
- `AuthRepository.deleteAccount()` calls the function, and the profile screen
  offers the entry point behind the popup above.
