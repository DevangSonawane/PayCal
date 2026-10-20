# PayCal Crib Owner and Permission Audit

**Date:** 2026-10-20 (Milestone 2B)
**Role names:** **Crib Owner** and **Crib Member**. There is no platform role,
no platform admin, no global admin account and no administrative bypass
anywhere in this codebase.
**Sources of truth:** `docs/PRODUCT_RULES.md` §1 (roles and membership),
`docs/SECURITY_AND_DATA_INTEGRITY_FINDINGS.md` (threat model),
`docs/COMPREHENSIVE_PRODUCT_AUDIT.md` (the findings this audit closes or
confirms).

---

## 1. How the two roles are defined

| Role | Where it lives | How it is enforced |
|---|---|---|
| **Crib Owner** | `Crib.ownerId`, plus `MemberRole.owner` on the owner's member row | `CribRepository`, `InvitationRepository` and `RecurringPaymentRepository` call `_requireOwner(...)` on every owner-only operation |
| **Crib Member** | `MemberRole.member` | May take part in the crib: create expenses, record settlements, dispute, read, accept an invitation, trigger the recurring catch-up |

The creator of a Crib is its owner and the only admin in v1
(`PRODUCT_RULES.md` §1). A second admin role is **not** introduced.

**The one weakness in the role check.** `_requireOwner` falls back to the
first member whose role is `owner` when `Crib.ownerId` is `null`
(`lib/data/in_memory_repositories.dart`, `_requireOwner`). `ownerId` is
nullable in the model, so a Crib without an owner id hands the owner
permissions to whichever member comes first. The repository cannot produce
such a Crib today (`create` always sets `ownerId`, `addMember` forces
`MemberRole.member`), so the fallback is unreachable through the app — but it
is a latent hole and the database has to make `owner_id` `NOT NULL`.
Recorded as `AUD-SEC-07` / `AUD-FIN-09`.

---

## 2. Permission matrix

Legend: **Implemented** = enforced at the repository layer and covered by a
test · **Partial** = enforced, but the UI or a rule is missing ·
**Missing** = no implementation · **Broken** = implemented incorrectly ·
**N/A** = the operation does not exist in the product.

### 2.1 Crib Owner only

| # | Operation | Repository | Enforced by | UI | Tests | Status |
|---|---|---|---|---|---|---|
| O1 | Create a Crib | `CribRepository.create` | creator becomes owner; a forged `ownerId` is refused | onboarding + popup | `crib_operations_test.dart` | **Implemented** |
| O2 | Edit the Crib name and categories | `CribRepository.update` | `_requireOwner` + version conflict | crib edit sheet | `crib_operations_test.dart`, `owner_permissions_test.dart` | **Implemented** |
| O3 | Change the currency | `CribRepository.update` | refused once the crib has expenses or a settlement | crib edit sheet | `crib_operations_test.dart` (3 tests) | **Implemented** |
| O4 | Add a member | `CribRepository.addMember` | `_requireOwner`; duplicate is a conflict | crib edit sheet | `membership_test.dart`, `owner_permissions_test.dart` | **Implemented** |
| O5 | Remove a member | `CribRepository.removeMember` | `_requireOwner`; the owner cannot be removed; a soft removal keeps the history | crib edit sheet | `membership_test.dart`, `owner_permissions_test.dart` | **Implemented** |
| O6 | Create an invitation | `InvitationRepository.create` | `_requireOwner` + `createdById == actor.id` | invite screen | `invitations_test.dart`, `owner_permissions_test.dart` | **Implemented** |
| O7 | Revoke an invitation | `InvitationRepository.revoke` | `_requireOwner` | invite screen | `invitations_test.dart`, `owner_permissions_test.dart` | **Implemented** |
| O8 | Create a recurring transfer | `RecurringPaymentRepository.create` | `_requireOwner` + creator is the actor | crib detail (owner only) | `recurring_test.dart`, `recurring_pause_test.dart` | **Implemented** |
| O9 | Cancel a recurring transfer | `RecurringPaymentRepository.cancel` | `_requireOwner` | crib detail (owner only) | `recurring_pause_test.dart`, `owner_permissions_test.dart` | **Implemented** |
| O10 | **Assign the payer of a recurring transfer** | `RecurringPaymentRepository.assignPayer` | `_requireOwner`; the assignee has to be an active member | crib detail → payer button | `recurring_pause_test.dart`, `owner_permissions_test.dart` | **Implemented (new in 2B)** |
| O11 | Delete a Crib | `CribRepository.delete` | `_requireOwner` + version conflict | crib edit sheet (owner only) | `crib_operations_test.dart`, `owner_permissions_test.dart`, `owner_ui_gating_test.dart` | **Implemented** |
| O12 | Edit the membership through a Crib update | `CribRepository.update` | the membership list is rejected | n/a | `membership_test.dart`, `owner_permissions_test.dart` | **Implemented** |

### 2.2 Both Crib Owner and Crib Member

| # | Operation | Repository | Enforced by | Tests | Status |
|---|---|---|---|---|---|
| M1 | Read the Crib, its members and its settings | `CribRepository.list` / `getById` | scoped to the memberships of the caller | `repository_isolation_test.dart` | **Implemented** |
| M2 | Read the expenses | `ExpenseRepository.list` / `getById` | `cribId` is mandatory; the caller has to be a member | `repository_isolation_test.dart` | **Implemented** |
| M3 | Read the settlements and the balances | `SettlementRepository.list` | `cribId` is mandatory | `repository_isolation_test.dart` | **Implemented** |
| M4 | Read the activity | `ActivityRepository.list` / `cachedEvents` | scoped to the cribs of the caller | `repository_isolation_test.dart` | **Implemented** |
| M5 | Create an expense | `ExpenseRepository.create` | active member + the payer is the actor | `expense_permissions_test.dart` | **Implemented** |
| M6 | Edit / delete an expense | `ExpenseRepository.update` / `delete` | the creator or the payer | `expense_permissions_test.dart` | **Implemented** |
| M7 | Flag a dispute | `ExpenseRepository.flagDispute` | any active member; the money never moves | `expense_permissions_test.dart` | **Implemented** |
| M8 | Record a settlement | `SettlementRepository.create` | the sender is the actor; the amount may not exceed the pairwise debt | `settlements_test.dart`, `settlement_pairwise_debt_test.dart` | **Implemented** |
| M9 | Confirm a pending settlement | `SettlementRepository.updateStatus` | the recipient only | `settlements_test.dart` | **Implemented** — but there is no UI that creates a pending settlement (F-H8) |
| M10 | Cancel a pending settlement | `SettlementRepository.updateStatus` | the sender only | `settlements_test.dart` | **Implemented** — no UI (F-H8) |
| M11 | Accept an invitation | `InvitationRepository.accept` | a valid, unrevoked, unexpired, unused token; a signed-in member | `invitations_test.dart` | **Implemented** |
| M12 | Trigger the recurring catch-up | `RecurringPaymentRepository.generateDue` | any active member | `recurring_test.dart` | **Implemented** |
| M13 | Update their own profile | `AuthRepository.updateProfile` | the signed-in user | — | **Partial** — it works, but it is not real authentication |

### 2.3 Refused for everyone

| # | Operation | Result | Evidence |
|---|---|---|---|
| X1 | The owner removes themselves | refused | `in_memory_repositories.dart` `removeMember`; `owner_permissions_test.dart` |
| X2 | The owner is added a second time as a member | conflict | `owner_permissions_test.dart` |
| X3 | A member removes themselves (leaves the Crib) | refused — removal is an owner operation | `owner_permissions_test.dart`; **gap, see §5** |
| X4 | A confirmed settlement is overwritten | refused | `settlements_test.dart` |
| X5 | The payer or the currency of an expense is swapped | refused | `expense_permissions_test.dart` |
| X6 | The membership list is changed through `update` | refused | `membership_test.dart` |
| X7 | A Crib id used as an invitation token | refused | `invitations_test.dart` |
| X8 | A `paycal://crib/<id>` or `paycal://batch/<id>` link | grants no membership | `ui_flows_test.dart` |

---

## 3. Owner capabilities, end to end

| Capability | Works end to end? | Notes |
|---|---|---|
| Create a Crib | **Yes** | `crib_operations_test.dart`, `end_to_end_flows_test.dart` flow 1 |
| Edit name and categories | **Yes** | Owner only, version checked |
| Manage the currency | **Yes** | Changeable until there is financial activity, then locked |
| Invite members | **Yes** | Token is 32 random bytes, opaque, single use, expiring |
| Revoke invitations and enforce expiry | **Yes** | Revoked and expired tokens are refused |
| Accept an invitation | **Yes** | The acceptance chain is token → revoked → expired → used → Crib → eligibility |
| Remove a member and keep the history | **Yes** | Soft removal; the balances keep working |
| Manage recurring transfers | **Yes, extended in 2B** | The owner can set up, cancel, **assign the payer** and resume a paused schedule |
| **Assign an active payer when the payer leaves** | **Yes — new in 2B** | Decision B, see §4 |
| Correct expenses and settlements without rewriting history | **Partly** | A metadata-only edit is allowed; a financial change is refused once the pair is settled; a confirmed settlement is immutable and has no correction path at all |
| Read the expenses, settlements, balances, members and activity | **Yes** | Scoped to the caller's memberships |
| Delete a Crib | **Yes, with a caveat** | The owner can delete it from the crib editor. The financial rows are kept but **orphaned**, and the delete is refused nowhere when the Crib has confirmed settlements. See P5 |
| Leave / archive a Crib | **No** | Archive does not exist, leave does not exist. See P1 |
| Ownership transfer | **No** | Out of scope for v1 (`PRODUCT_RULES.md` §1) |
| Owner account deletion | **No** | The profile screen shows a toast and changes nothing |

---

## 4. Decision B — the payer of a recurring transfer

**The rule that was approved:** when the creator of a recurring schedule leaves
the Crib or is removed, the schedule pauses until an active payer/manager is
explicitly assigned.

### 4.1 What the model could not represent, and the smallest change

The approved `PRODUCT_RULES.md` §5 describes a schedule as holding *"its
timezone, its scheduled local time, its start date, its recurrence rule, its
original day of month, **its creator** and its active state"*. There was no
payer and no paused state, so the behaviour could not be expressed.

**The smallest model change** (`lib/data/models.dart`, `RecurringPayment`):

| Field | Type | Meaning |
|---|---|---|
| `payerId` | `String?` | The member who pays the generated occurrences. `null` means **paused**. Defaults to the creator. |
| `resumeFrom` | `DateTime?` | The local due date the schedule continues from after a pause. |
| `isPaused` | getter | `payerId == null`. |

A derived pause state means the two can never disagree. `copyWith` uses a
sentinel (`Object? payerId = _unset`) so `null` can be set explicitly — a
plain `??` would have silently turned "paused" back into "the creator pays".
That was a real bug during the implementation and it is covered by
`recurring_pause_test.dart`.

### 4.2 The behaviour

| Situation | Behaviour | Test |
|---|---|---|
| The creator leaves | The schedule is **paused**: `payerId` is cleared, `resumeFrom` is the first due date after the pause | `the schedule is paused` |
| A paused schedule is due | **Nothing is generated** | `a paused schedule generates nothing` |
| The pause happens | `recurring_paused` is written to the activity feed | `the pause is recorded in the activity feed` |
| The generated expenses and occurrences | They **stay intact** | `the generated expenses and occurrences stay intact` |
| The owner assigns an active member | The schedule **resumes**; `recurring_payer_assigned` and `recurring_resumed` are recorded | `the owner can assign an active member and the schedule resumes` |
| A member tries to assign | **Refused** | `a member cannot assign a payer` |
| The assignee is not an active member | **Refused** | `only an active member can be assigned` |
| The assignee is outside the Crib | **Refused** | `a member outside the crib cannot be assigned` |
| The schedule was cancelled | **Refused** | `a cancelled schedule cannot be resumed` |
| The schedule runs again | The **new** payer pays the new occurrences | `the schedule generates again and the new payer pays` |
| The schedule is resumed | **No occurrence is duplicated** — the key is `schedule id + due date` | `resuming does not duplicate an occurrence that exists already` |
| The schedule resumes | It continues at the first due date after the pause; the missed occurrences are **not** generated as a backlog | `a pause does not create a backlog of the missed occurrences` |
| The new payer leaves later | The schedule is **paused again** | `a payer that leaves later` |

### 4.3 Two consequences that need a product decision

1. **The owner cannot be removed**, so the creator of a schedule can only
   leave through an ownership transfer or an account deletion — neither
   exists. The reachable path is: the owner hands the schedule to a member
   (`assignPayer`), and that member leaves. This is why `assignPayer` is
   allowed on a running schedule and not only on a paused one.
2. **A pause drops the occurrences that were due before it but not yet
   generated.** They are not in the ledger before the pause either, so
   nothing is corrupted, but the payer's contribution to the ledger is
   lower than it would have been. The alternative — generating them at the
   moment of the pause — was not chosen, because it would make a membership
   change create expenses. **This needs a product decision.**

### 4.4 What is still missing

* There is no way to pause a schedule by hand. Only the departure of the
  payer pauses it.
* There is no "unassign" — a payer can be replaced, but a schedule cannot be
  sent back to the paused state on purpose.
* A schedule whose recurrence rule cannot be resolved (an unknown timezone
  that was accepted earlier) is paused without a resume point and has to be
  looked at by the owner.

---

## 5. Missing or broken capabilities

| # | Gap | Severity | Why it matters | Status |
|---|---|---|---|---|
| P1 | **A member cannot leave a Crib.** `removeMember` is owner-only, so a member cannot remove themselves | High | A member who wants out has no path. The owner has to do it, which puts the owner in the position of expelling people | **Open — product decision** |
| P2 | **No ownership transfer.** The owner cannot hand a Crib over | High | The owner is stuck with a Crib they cannot leave, and an account deletion would orphan it | **Open — out of scope for v1** (`PRODUCT_RULES.md` §1) |
| P3 | **Owner account deletion is a toast.** `profile_screen.dart` shows "Account deletion requested" and calls nothing | High | The user believes something happened | **Open — needs the backend** |
| P4 | **"Log out" does not sign out.** The screen navigates but never calls `AuthRepository.signOut` | High | The in-memory session stays alive | **Open — needs the backend** |
| P5 | **Deleting a Crib orphans the financial rows.** The expenses and the settlements stay in the ledger but point at a Crib that no longer resolves, and there is no guard against deleting a Crib with confirmed settlements | Medium | The other members lose access to their financial history without a tombstone and without a reversal | **Open** |
| P6 | **A removed member keeps full read access.** `PRODUCT_RULES.md` §1 lists this as **Open** | Medium | The current implementation keeps the read access, which is the friendlier behaviour, but it is not a decided rule | **Open — product decision** |
| P7 | **The owner id fallback.** `_requireOwner` falls back to the first `MemberRole.owner` when `ownerId` is null | Medium | Latent: a Crib without an owner id would hand the owner permissions to the first member | **Open — `owner_id` must be `NOT NULL`** |
| P8 | **The owner-only controls of the Crib editor were shown to every member.** The name, the currency, the member management, the invite link, the revoke button and the delete button were all visible to a member, and every one of them failed with an error toast | Low | A member was offered a set of buttons that could not work | **Closed in 2B** — the editor is now read-only for a member, `test/owner_ui_gating_test.dart` |
| P9 | **A member was labelled as the owner.** The member list showed `You (owner)` for whoever was signed in, not for the owner | Low | A member reading the roster would believe they own the Crib | **Closed in 2B** — the owner is marked as such and everybody else is marked as "You" |
| P9 | **A confirmed settlement has no correction path.** It is immutable and there is no compensating settlement | Medium | A wrong settlement can only be fixed by a new one | **Open — product decision (D4)** |
| P10 | **There is no audit role.** A member who disputes an expense cannot be answered by anybody but the owner | Low | Accepted for v1 | **By design** |
| P11 | **The delete confirmation said the expenses go with the Crib.** They do not: the implementation keeps them and orphans them | Low | The user was told their financial history was destroyed, which was not what the code does — and the real problem (orphaned rows) was hidden | **Closed in 2B** — the text now says the expenses and settlements stay in the ledger |

---

## 6. Security limitations of these permissions

**Every check in this document lives in the client.** The rules are proved
against the in-memory repository, which is the test implementation of the
repository interfaces. That is not a security boundary:

* a modified client skips every check;
* a replayed request is not identified as a replay of an owner action;
* the actor id is client-owned, so the identity behind "the owner" is only as
  trustworthy as the client.

`docs/BACKEND_SECURITY_REQUIREMENTS.md:3-6` says it plainly. The database has
to enforce the same rules:

| Operation | The database has to enforce |
|---|---|
| Read a Crib, an expense, a settlement, an event | RLS `using (public.was_member(crib_id))` |
| Update / delete a Crib | `is_crib_owner(crib_id)` inside the RPC |
| Add / remove a member | `is_crib_owner(crib_id)` inside the RPC; `left_at` is written by the server |
| Create / revoke an invitation | `is_crib_owner(crib_id)` inside the RPC; the token is generated and hashed server-side |
| Create a recurring schedule, assign its payer, cancel it | `is_crib_owner(crib_id)` inside the RPC; the assignee has to be an active member, checked in the transaction |
| Every write | `auth.uid()`, never a client-supplied `user_id` |

The full mapping is in `docs/SUPABASE_MIGRATION_PLAN.md` §4 and
`docs/SECURITY_AND_DATA_INTEGRITY_FINDINGS.md` §5.

---

## 7. Relevant tests

| File | Tests | What it proves |
|---|---|---|
| `test/owner_ui_gating_test.dart` | 3 | The owner-only controls of the Crib editor are not shown to a member |
| `test/owner_permissions_test.dart` | 34 | The whole matrix: every owner-only operation is refused for a member, a stranger and a signed-out caller; every member operation is allowed; a removed member loses every write right and keeps the history; a repeated action cannot bypass a check |
| `test/recurring_pause_test.dart` | 19 | Decision B end to end |
| `test/recurring_test.dart` | 17 | The recurrence rules, the timezones, the occurrence idempotency |
| `test/membership_test.dart` | 12 | Owner-only add and remove, soft removal, the history |
| `test/invitations_test.dart` | 11 | The invitation lifecycle |
| `test/expense_permissions_test.dart` | 11 | Who may create, edit, delete and dispute an expense |
| `test/settlements_test.dart` | 11 | Who may create, confirm and cancel a settlement |
| `test/repository_isolation_test.dart` | 17 | The reads are scoped to the caller |
| `test/crib_operations_test.dart` | 11 | The Crib operations and their versions |
| `test/end_to_end_flows_test.dart` | 1 | The twelve product flows in one story, with several members and two Cribs |

**Total: 232 tests, all passing.**

---

## 8. Summary

The **Crib Owner** is the only admin, and the owner permissions are enforced
at the repository layer for **every** owner-only operation, each of them with
a test that fails for a member, a stranger and a signed-out caller. The
**Crib Member** can do everything a member is allowed to do, and nothing
more. A removed member keeps the history of the Crib and loses every write
right.

The gaps that matter are not permission gaps but **lifecycle** gaps: a member
cannot leave, ownership cannot be transferred, the owner cannot delete their
account, and there is no authentication, so "the owner" is only as trustworthy
as the client. All four are documented above and in
`docs/RELEASE_READINESS_CHECKLIST.md`.
