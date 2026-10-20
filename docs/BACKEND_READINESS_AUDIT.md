# Backend readiness audit

Re-audited after the "v1 product-rule approval and P0 backend-readiness
implementation" milestone. `MockData` is now only the seed source of the
in-memory store. No screen writes to it any more.

## What was migrated

| Area / files | Before | Now | Priority and tests |
| --- | --- | --- | --- |
| `core/utils/deep_link.dart` | `paycal://crib/<id>` auto-added the local user to the crib. | Only `paycal://invite/<token>` changes membership, through `InvitationRepository.accept`. `paycal://crib/<id>` is rejected with a message. `paycal://user/<id>` stays read-only. | Done. `invitations_test.dart`, `ui_flows_test.dart`. |
| `features/scans/scan_flow.dart` | Mutated `crib.members` directly while scanning. | Adds a scanned person through `CribRepository.addMember`; a non-owner gets the repository error. | Done. `membership_test.dart`. |
| `features/onboarding/first_crib_screen.dart`, `cribs/create_crib_popup.dart` | Built the crib in `MockData.cribs` with `MockData.me` as a member. | `CribRepository.create`; the creator becomes the owner, the signed-in member comes from `AuthRepository`. | Done. `crib_operations_test.dart`, `ui_flows_test.dart`. |
| `features/cribs/crib_edit_sheet.dart` | Edited the crib, removed members and shared a `paycal://crib/<id>` link from one local form. | Metadata through `CribRepository.update`; membership through `addMember` / `removeMember`; invite links are real invitations that can be revoked. | Done. `ui_flows_test.dart`, `membership_test.dart`, `invitations_test.dart`. |
| `features/cribs/crib_detail_screen.dart` | Recurring configuration and generation lived in the screen; `MockData.addExpense` wrote money entries. | Recurring rules moved to `domain/recurring_scheduler.dart`; money entries go through `ExpenseRepository.create`; generation is idempotent per schedule and due date. | Done. `recurring_test.dart`, `expense_permissions_test.dart`. |
| `features/expenses/quick_add_sheet.dart`, `expense_detail_screen.dart` | Looked up cribs and member names in `MockData`. | Repository cache plus `data/member_directory.dart`; edit and delete are only offered to the creator or the payer; a dispute is its own repository call. | Done. `expense_permissions_test.dart`, `ui_flows_test.dart`. |
| `features/home`, `cribs`, `profile`, `search` | Read the current identity from `MockData.me` / `MockData.meId`. | Identity comes from `AuthRepository`; the profile update goes through `AuthRepository.updateProfile`. | Done. `activity_test.dart`. |
| `features/settlements/settle_up_sheet.dart` | Recorded a settlement for every transfer, including transfers of other members, which the repository rejects. | Only the signed-in member's own transfers are recorded; the other transfers stay visible as requests. | Done. `settlements_test.dart`. |
| `features/onboarding/invite_screen.dart` | Showed a hard-coded HTTPS link. | Shows a real invitation link with an opaque token. | Done. |

## Remaining direct dependencies

| Area / files | Current behavior | Required replacement | Priority and tests |
| --- | --- | --- | --- |
| `data/mock_data.dart`, `data/in_memory_repositories.dart` | The prototype store is still an in-memory list. The store is now injectable (`PayCalRepositories.forStore`), which is the seam a backend adapter uses. | A backend implementation of the same contracts. Remove the mock adapter after the migration. | P1. Contract-test every backend implementation. |
| `features/settlements/settle_sheet.dart` | Unused individual settlement sheet that only shows a toast instead of recording anything. | Delete it, or wire it to `SettlementRepository.create`. | P2. |
| `data/repositories.dart` | No user directory, profile projection or account deletion contract. | A `UserDirectory` and a deletion contract once the backend is picked. | P1, blocked on the backend choice. |
| `domain/recurring_scheduler.dart` | The device timezone is stored as a fixed offset, because the platform does not expose an IANA zone id without an extra plugin. | Resolve the IANA zone on the platform, or let the backend store the zone. | P2. |
| `data/in_memory_repositories.dart` | Expenses are hard-deleted from the store. | Tombstone/reversal model (see `PRODUCT_RULES.md` §2). | P1, belongs with the backend. |

## Gaps that need a backend, not more in-memory code

- Row/document security rules for cross-crib reads and writes.
- Token/session revocation and account deletion.
- Atomic concurrent updates, invitations, settlements and recurring jobs.
- Database uniqueness/idempotency under network retries and parallel clients.
- Server timestamps, audit immutability, rate limits and observability.
- A durable recurring job that generates occurrences while the app is closed.

## Test plan

### Covered today

- Financial arithmetic, exact splits, ledger recalculation, settlement status
  balance effect: `financial_ledger_test.dart`.
- In-memory crib/expense/settlement CRUD, validation, conflict/not-found,
  unauthenticated write, activity and DTO round trips:
  `in_memory_repositories_test.dart`.
- Invitations: unauthorized, unknown token, revoked, expired, duplicate
  acceptance, existing member, owner-only create/revoke, opaque token:
  `invitations_test.dart`.
- Membership: owner-only add/remove, soft removal with intact history, ledger
  validation after removal, removed member loses access, no membership change
  through `update`: `membership_test.dart`.
- Crib operations: owner on create, member denial, stale version, currency
  change blocked after activity, owner-only delete, delete keeps the financial
  history: `crib_operations_test.dart`.
- Expenses: payer-only create, creator/payer edit, dispute by any member,
  version conflict, immutable payer and currency:
  `expense_permissions_test.dart`.
- Settlements: sender/recipient authorization, overpayment rejection against
  the debt of the pair, idempotency key replay, a reused key with a different
  payload is a conflict, confirmed settlements cannot be overwritten, settled
  cribs freeze their expenses: `settlements_test.dart` and
  `settlement_pairwise_debt_test.dart`.
- Recurring: month-end and leap-day rules, timezone offsets and daylight
  saving, unknown timezone, occurrence idempotency, catch-up of missed runs,
  cancellation: `recurring_test.dart`.
- Activity emission for every mutation: `activity_test.dart`.
- UI flows after the migration, including the deep link paths:
  `ui_flows_test.dart`.
- Onboarding smoke tests, and the golden probe.

> **Corrected 2026-10-20.** Three statements above were wrong for the code
> that is in the tree now:
>
> * *"delete cascades"* — the delete keeps the expenses and the settlements of
>   the crib. The real problem is different: the delete is a hard delete, so
>   the financial rows are left pointing at a crib that no longer resolves,
>   and there is no guard against deleting a crib that has confirmed
>   settlements. See `AUD-SEC-03` in `docs/COMPREHENSIVE_PRODUCT_AUDIT.md`.
> * *"overpayment rejection on both sides"* — there was one rule, and it was
>   the net rule, not a per-pair one. It is now the debt of the pair, and both
>   directions are covered by `test/settlement_pairwise_debt_test.dart`.
> * *"the golden probe"* — the probe passes only against a baseline that was
>   regenerated without review. The approved baseline has been restored, so
>   the probe now fails with the known `0.53%, 2546px` diff of the
>   `batch` to `crib` rename, and needs an explicit approval before the
>   baseline may be regenerated again.

### Not covered, and why

- Cross-crib security rules, concurrency under parallel clients and
  server-side enforcement: these need a backend or a backend emulator, which
  is out of scope until a provider is picked.
- The server side of the rules the client now enforces. The client scopes
  every read to the memberships of the signed-in member and validates the
  money rules in the domain, but **that is not a security boundary**. A
  modified client skips all of it. The RLS policies and the `SECURITY
  DEFINER` RPCs of `docs/SUPABASE_MIGRATION_PLAN.md` §4 are what enforce the
  same rules, and they cannot be tested until a database exists. The client
  side tests in `test/repository_isolation_test.dart` prove the client never
  asks for another member's data and never receives it — they do not prove
  the database refuses it.

## Minimum work before backend integration

1. Pick the backend provider and its auth model.
2. Resolve the open product rules in `PRODUCT_RULES.md` (invitation reuse,
   approval policy, tombstone model, deletion retention).
3. Implement the repository contracts against the backend and contract-test
   them against the same expectations the in-memory tests use.
4. Replace the remaining mock adapter and the seed data.
