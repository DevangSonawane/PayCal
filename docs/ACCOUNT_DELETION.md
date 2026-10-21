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

- The account is deactivated or deleted, and its sessions and device tokens
  are revoked immediately.
- The user id is immutable and never reused, so audit records that point at it
  stay readable after the display name is gone.
- Whether the account is soft-deleted (deactivated, then removed later) or
  hard-deleted is **not decided**. A backend decision is required, because it
  determines how a re-registration is handled.

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
| Retention period of a deactivated account | Depends on the same legal review. |
| Export requirements (for example a data download) | Depends on jurisdiction. |
| Region-specific deletion obligations | Depends on the markets the app ships in. |
| Whether an anonymised label is kept forever or re-randomised | Depends on the fraud-handling requirement. |

No number in this document is a retention promise. Filling these in is a
legal/privacy task, and the implementation must follow whatever it produces.

## Open implementation work

- A `UserDirectory` contract to look up members by id. Still open.
- The retention numbers of the table above. Still a legal/privacy task.

## What is implemented

- `supabase/functions/delete-account` closes the memberships, anonymises the
  profile, revokes the pending invitations and bans the account. GoTrue
  removed the admin sign-out endpoint, so the ban is what invalidates the
  sessions: every refresh of a banned account is refused with `user_banned`.
  An account that still owns an active crib is refused with `409`, and the
  profile screen turns that into the next step for the member.
- `AuthRepository.deleteAccount()` calls the function, and the profile screen
  offers the entry point behind a confirmation sheet.
