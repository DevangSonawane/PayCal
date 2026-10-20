# PayCal v1 product rules

Status: **approved for v1** (Phase 3 review, milestone "v1 product-rule
approval and P0 backend-readiness implementation").

The rules marked **Approved** are implemented in the in-memory repositories and
enforced in the UI. The rules under **Open** are not decided yet; they are
tracked here so a backend implementation does not silently invent behaviour.

## 1. Cribs, roles, and membership

**Approved**

- The creator of a crib is its owner, and the owner is the only admin in v1.
  `MemberRole` stays `owner` / `member`; a second admin role is not introduced.
- Regular members cannot manage crib membership or invitations. Adding and
  removing members and creating or revoking invitations are owner-only
  operations, enforced by `CribRepository` and `InvitationRepository`.
- The owner may remove a member. Removal is a soft removal: the member stays
  in the crib history with `isActive == false` and `leftAt` set, so historical
  expenses and settlements keep validating and balances stay reconstructable.
- A removed member loses active access: they cannot create expenses or
  settlements any more.
- The owner cannot be removed, and ownership transfer is not part of v1.
- Membership never changes through `CribRepository.update`. The update
  contract rejects a member-list change and points to `addMember` /
  `removeMember`, so every membership change is authorised, versioned and
  recorded in the activity feed.

**Open**

- Whether a removed member keeps read-only access to their own historical
  records.
- Ownership transfer and an explicit admin role for larger cribs.

## 2. Expenses

**Approved**

- Expense editing permissions are explicit and identical in the UI and in the
  repository:
  - create: the signed-in member is an active member of the crib and is the
    payer;
  - edit / delete: the creator (`Expense.createdById`, falling back to the
    payer for older records), the payer, **or the Crib Owner**. The owner
    manages the whole crib, so they may correct any expense in it;
  - flag a dispute: any active member of the crib; a dispute never changes
    the money.
- The owner override does not extend to the money rules: the payer, the
  currency and the split still cannot be changed, and the settled history is
  still frozen.
- The payer, the currency and the amount split of an expense cannot be changed
  silently: changing the payer or the currency is rejected.
- Every mutation carries an optimistic-concurrency version. A stale version is
  a conflict, not a silent overwrite.
- Once a crib has a confirmed or self-managed settlement, its expenses can no
  longer be edited or deleted: the settled history stays intact.
- Financial validation stays in `FinancialLedger`. The repositories call it,
  they do not re-implement the money rules.

**Open**

- Tombstone / reversal instead of a hard delete for an **expense**. The
  in-memory store still removes the record on delete; the tombstone model has
  to land with the backend.
- Admin override for editing somebody else's expense. **Decided 2026-10-20:**
  the Crib Owner may edit and delete any expense of their own crib. There is
  no platform role and no override that reaches across cribs.

## 2b. Deleting a Crib

**Approved**

- The Crib Owner can delete their Crib, and the app asks for a confirmation
  first. The confirmation says what happens to the records.
- **The delete is a tombstone.** The Crib keeps its row, so the expenses, the
  settlements and the activity of it still point at something that exists and
  the balances of a deleted Crib still add up. The records are never
  destroyed and never become orphans.
- **The members lose access.** A deleted Crib does not show up in the lists
  any more, and its expenses, settlements and activity are not readable
  through the app. The history stays complete for the record, not for the
  members.
- A deleted Crib cannot be changed, deleted again, or have its membership
  touched. Deleting it twice does not write a second event.

**Open**

- Whether a member should be told that a Crib was deleted, and how. The
  activity event exists, but the members of a deleted Crib do not see their
  own feed any more.
- Whether the owner can undo the deletion.

## 3. Invitations

**Approved**

- Invitations carry an opaque random token (32 characters, `Random.secure`).
  A crib id is never a credential: `paycal://crib/<id>` links are rejected
  instead of joining a crib.
- Invitations support revocation and expiry. The default lifetime is 7 days
  (`AppConfig.invitationLifetime`); the expiry is stored on the invitation.
- Joining goes through an explicit acceptance operation
  (`InvitationRepository.accept(token)`). It validates the stored invitation,
  its revocation and expiry state, and the membership eligibility of the
  signed-in member before adding anybody.
- Acceptance requires an authenticated member. An unknown token is not found,
  a revoked or expired token is unauthorized, and a member who already belongs
  to the crib gets a conflict.
- Revocation invalidates future joins immediately. Members that already
  accepted stay in the crib.

**Open**

- Single-use vs reusable invitations. The approved rules do not decide this,
  so the existing single-use behaviour is kept: an invitation is consumed by
  the first acceptance. Making invitations reusable (optionally with a
  maximum-uses limit) is still open.
- Whether invitees should enter a `pending` membership that the owner
  approves. v1 accepts the invitation directly.

## 4. Settlements

**Approved**

- Settlements are separate from expenses. Recording a settlement never changes
  the tracked spending of a crib.
- A confirmed settlement cannot be silently overwritten. `confirmed` and
  `selfManaged` settlements are final: their status can no longer be changed
  and no new settlement may edit them in place.
- Only the sender may create or cancel a settlement, only the recipient may
  confirm one. A `confirmed` settlement cannot be created directly, because
  the recipient is the one who confirms it.
- Settlement overpayments are rejected: an amount that exceeds the sender's
  outstanding debt to the recipient at the transaction snapshot is refused.
- Every create request carries a client-generated idempotency key scoped to the
  crib and the sender. Replaying the key returns the original settlement.
- The crib settle-up sheet only records the signed-in member's own
  transfers. Transfers that belong to other members stay requests until those
  members record them.

**Open**

- Whether a confirmed settlement may be reversed by a compensating settlement
  instead of staying immutable.
- Whether partial settlements need an explicit policy beyond the overpayment
  rule.

## 5. Recurring expenses

**Approved**

- A recurring schedule stores its timezone, its scheduled local time, its
  start date, its recurrence rule, its original day of month, its creator and
  its active state. `RecurringScheduler` owns the date rules and nothing else.
- The timezone is explicit: an IANA zone (`Asia/Kolkata`) or a fixed offset
  (`UTC+05:30`). The device offset is used when a schedule is created, because
  the platform does not expose an IANA zone id without an extra plugin.
- A monthly schedule anchored on the 29th, 30th or 31st runs on the last day of
  shorter months and returns to its anchor day afterwards. Yearly schedules
  follow the same rule, so 29 February becomes 28 February in a common year.
- Occurrences are idempotent per schedule and due date. The key is
  `schedule id + due date`; the generated expense id is derived from it, and a
  `RecurringOccurrence` ledger records what was generated.
- Generation is on demand: the app catches up missed runs when a crib is
  opened. There is no background job in v1, so nothing is generated while the
  app is closed and nothing claims to be.
- Cancelling a schedule stops future occurrences only. Generated expenses stay
  in the ledger.
- A schedule is paid by one member at a time. The creator is the payer when
  the schedule is created, and the Crib Owner can hand the paying to another
  active member.
- When the member who pays a schedule leaves the Crib or is removed, the
  schedule is **paused**: it generates nothing until the Crib Owner assigns an
  active member as the new payer. Only an active member of the Crib can be
  assigned, and the assignment is recorded in the activity feed.
- A pause does not create a backlog. The schedule continues at the first due
  date after the pause, so the occurrences of the paused window are never
  generated.
- Pausing and resuming are recorded in the activity feed, next to the member
  removal that caused the pause.

**Open**

- Whether a user may edit a single occurrence independently of its schedule.
- A durable server job that generates occurrences while the app is closed.
- Whether the occurrences that were due before a pause but not yet generated
  should be generated at the moment of the pause. The current implementation
  drops them, because generating them would make a membership change create
  expenses. **Decided in Milestone 2B as an open question, not as a rule.**
- Whether the Crib Owner can pause a schedule by hand, and whether a payer
  can be unassigned.

## 6. Currency

**Approved**

- A crib has one currency.
- The currency cannot change once the crib has financial activity (an expense
  or a settlement). It may change before that.
- No conversion or migration is part of v1.

## 7. Account deletion and retention

**Approved**

- The requirements below are documented, not invented. Legal retention periods
  are explicitly **not** set by this document; they have to come from a
  legal/privacy review.
- The full requirement list lives in `ACCOUNT_DELETION.md`.

Requirements for an account deletion implementation:

- Deactivate or hard-delete the account itself, and revoke its sessions and
  device tokens.
- Do not erase shared financial history. Expenses, settlements and cribs
  stay, because other members' records depend on them.
- Replace the display identity in historical records with a retained or
  anonymised label, while the immutable user id stays as the internal
  reference for audit and fraud handling.
- Revoke the invitations the user created, so the links stop working
  immediately. Members that already accepted keep their membership.
- The account keeps a stable, non-reusable id after deletion so audit records
  stay readable.

**Open**

- Retention periods, export requirements and jurisdiction-specific deletion
  obligations. These need legal/privacy input and are deliberately left blank.
- Whether deletion is soft (deactivate) or hard, and how long a deactivated
  account is kept before it is removed.

## 8. Activity feed

**Approved**

- Every important mutation records an activity event with the actor, the
  event type, the target id, the crib id and the timestamp:
  crib created / updated / deleted, member added / removed, expense created /
  updated / deleted / disputed, settlement created / confirmed / cancelled,
  invitation created / accepted / revoked, recurring created / cancelled /
  generated.
- The feed is newest first.
