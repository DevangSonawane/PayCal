# PayCal Milestone 2 Verification — Pre-Supabase Critical Fixes

**Date:** 2026-10-20
**Scope:** the confirmed high-risk issues of `docs/COMPREHENSIVE_PRODUCT_AUDIT.md`
that can be fixed without a product decision and without a backend.
**Not in scope:** Supabase integration, migrations, real authentication.

> **This document has two parts.** The first is the Milestone 2 record
> (112 → 175 tests, the golden baseline restored and *not* regenerated — the
> state at that moment). The second is **Milestone 2B**, further down, which
> took the suite to **234 tests, all passing**, regenerated the golden
> baseline after verifying it, and added the Crib Owner permission audit.
> **The current state is the Milestone 2B section.**

---

## 1. Verification results (executed)

| Command | Working tree | Clean working-tree copy |
|---|---|---|
| `flutter analyze` | **No issues found!** (2.5s) | **No issues found!** (2.8s) |
| `flutter test` | **174 passed, 1 failed** (5s) | **174 passed, 1 failed** (5s) |

The single failure is the golden probe, and it is **expected**: the previously
approved baseline was restored, so the probe now reports the known
`0.53%, 2546px` difference of the unapproved `batch` to `crib` rename. See §5.

**Test count before this milestone:** 112 · **after:** 175 (174 pass + 1
expected golden failure). **63 new tests** were added.

| New test file | Tests | Covers |
|---|---|---|
| `test/money_test.dart` | 11 | the `-0.50` parse bug, sign handling, zero, decimal boundaries, invalid input, overflow, exact formatting |
| `test/settlement_pairwise_debt_test.dart` | 14 | the pairwise overpayment rule in both directions, partial payments, retries, duplicate keys, mismatched payloads, auditable corrections |
| `test/active_member_enforcement_test.dart` | 12 | the removed-member rule at the domain level and in the repository, history that stays valid |
| `test/repository_isolation_test.dart` | 17 | one member cannot read the cribs, expenses, settlements or activity of another member |
| `test/financial_ledger_test.dart` (extended) | +9 | pairwise debt, suggested transfers, mutual debts, debt cycles |
| `test/support/harness.dart` (extended) | — | `signIn` / `signOut` helpers, a `foreignCrib` fixture |

---

## 2. What was fixed

### 2.1 Negative money parsing — `AUD-FIN-01` (was F-M1)

**Root cause.** `Money.tryParseToMinor` took the sign from the *parsed whole
part*: `final sign = whole < 0 ? -1 : 1;`. `int.tryParse('-0')` returns `0`, so
`'-0.50'` produced `0 * 100 + 1 * 50 = +50`. A negative sub-unit amount became
a **positive** amount. The uncommitted refactor in the tree was a no-op: it
produced the same `+50`.

**Changes** — `lib/core/utils/money.dart`:
* The sign is stripped from the input before the parts are parsed, so the
  sign belongs to the whole amount: `'-0.50'` → `-50`.
* The whole and the fraction are matched with `^\d+$` / `^\d{1,2}$`, so
  `'--5'`, `'++5'`, `'1.234'`, `'.50'` and `'1.'` are rejected instead of
  being read in a surprising way.
* `Money.maxMinorUnits` (2^53 - 1) is the largest accepted amount. A value
  that would overflow is **rejected**, not wrapped. This was necessary:
  `9223372036854775807 * 100` wraps to `-100` in Dart.
* `Money.format` no longer divides by `100.0`. It uses truncating division
  and `int.remainder`, so the amount is exact for every value and the
  minimum 64-bit integer cannot overflow. The fallback symbol lost its
  trailing space.
* `FinancialLedger._positiveAmount` rejects an amount above
  `Money.maxMinorUnits`, so parsing, validation and formatting agree.

**Tests.** `test/money_test.dart`.

### 2.2 Settlement validation — `AUD-FIN-02` (was F-H2)

**Root cause.** `InMemorySettlementRepository.create` compared the amount
against the **net** balance of the sender in the crib:
`(balances[from] ?? 0) + amount > 0`. That is a different question from the
approved rule in `PRODUCT_RULES.md` §4 — *"an amount that exceeds the sender's
outstanding debt to the recipient"* — and it failed in both directions:

* a debtor could settle **anybody**, including a person they never owed
  anything to;
* a member who genuinely owed a small amount could be refused because of
  unrelated netting.

**Changes**
* `lib/domain/financial_ledger.dart` gained the pairwise debt:
  * `pairwiseDebt({crib, expenses, settlements, fromId, toId})` — what
    `fromId` owes `toId`: their share in the expenses `toId` paid, minus the
    settlements that already happened. Only `confirmed` and `selfManaged`
    settlements reduce it, because a `pending` settlement is a request the
    recipient still has to confirm.
  * `pairwiseDebts({crib, expenses, settlements})` — every pair at once.
  * `sameShares(a, b)` — a content comparison of two share allocations.
* `InMemorySettlementRepository.create` now rejects
  `amountMinor > pairwiseDebt(from, to)`.
* `FinancialLedger.suggestedTransfers` is now built from the pairwise debts
  instead of the net balances, so **every transfer it suggests is inside the
  debt of that pair and can be recorded**. This was necessary, not cosmetic:
  the old net plan suggested `C → A 500` for a crib where `C` only owed `B`
  500, and the repository refused it. The plan cancels mutual debts and debt
  cycles first, so a crib that is already square does not suggest transfers
  that would cancel each other out.
* The distinction is preserved and now explicit: `balances` reports the net
  position of a member, `pairwiseDebts` reports who owes whom, and the
  overpayment rule uses the pair.

**Tests.** `test/settlement_pairwise_debt_test.dart`,
`test/financial_ledger_test.dart`.

**Product rule used:** `PRODUCT_RULES.md` §4 and
`docs/SUPABASE_MIGRATION_PLAN.md` §3.5. The SQL sketch in §3.5 was wrong and
has been corrected (see §6).

### 2.3 Domain-level active-member enforcement — `AUD-FIN-03` (was F-H6)

**Root cause.** `FinancialLedger.validateExpense` checked the members of the
crib, `validateSettlement` checked the *active* members, and the repository
had its own third copy of the active check. The domain — the layer
`PRODUCT_RULES.md` §2 names as the single source of money truth, and the layer
the SQL mirror would be copied from — had no active-member rule for expenses.

**A second, related bug was found while fixing this one:** removing a member
who had a settlement made **the whole crib unbalanceable**, because
`balances()` re-validates every settlement and `validateSettlement` required
active members. This was reproduced before the fix (a probe threw
`FinancialValidationException: Settlement members must belong to the crib.`).

**Changes** — `lib/domain/financial_ledger.dart`:
* `validateExpense` / `validateSettlement` validate the **record**: the
  members have to belong to the crib, active or not. The history of a crib
  keeps validating.
* `validateNewExpense` / `validateNewSettlement` validate a **new record**:
  the payer, the participants and the members of a settlement have to be
  active. A member that left is never charged again and never takes part in a
  new financial operation.
* `InMemoryExpenseRepository` uses `validateNewExpense` when a charge
  changes and `validateExpense` for a metadata-only edit, so renaming an
  expense of somebody who left still works while keeping them in the charge
  does not.
* `InMemoryRecurringPaymentRepository.generateDue` skips a schedule whose
  creator is no longer an active member, so a recurring transfer never charges
  a member that left. **Who pays an occurrence after the creator left is
  still an open product decision (D11) and was not decided here.**

**Tests.** `test/active_member_enforcement_test.dart`.

### 2.4 Repository isolation contracts — `AUD-SEC-01` (was F-C1)

**Root cause.** No repository method scoped a read to the memberships of the
caller. `cachedCribs`, `cachedExpenses`, `cachedSettlements` and
`cachedEvents` returned everything in the store, `list()` returned everything
and `getById()` returned any record by id. The test suite **asserted that
unscoped behaviour as correct**, and no test ever created a second crib, so
the leak was structurally invisible.

**Changes**
* `lib/data/repositories.dart` — the contracts now say what the scope is.
  `ExpenseRepository.list` and `SettlementRepository.list` take a
  **mandatory** `cribId`, as `SUPABASE_MIGRATION_PLAN.md` §5 asks for.
* `lib/data/in_memory_repositories.dart`:
  * every read is scoped to the cribs the signed-in member belongs to, a
    member that was removed keeps read access to the history of that crib;
  * `getById` of a crib, an expense or a settlement of somebody else answers
    `notFound`, so the ids of other people cannot be probed;
  * `list` and `getById` require a signed-in member, the caches are empty
    without one;
  * `ActivityRepository.record` only accepts an event of a crib the caller
    belongs to;
  * `InvitationRepository.getById` requires a signed-in member.
* `test/support/harness.dart` can switch the signed-in member, so one store
  can hold several users and several cribs.

**Tests.** `test/repository_isolation_test.dart` (17 tests).

**This is not a security boundary.** A modified client skips every one of
these checks. The RLS policies and the `SECURITY DEFINER` RPCs of
`docs/SUPABASE_MIGRATION_PLAN.md` §4 are still what enforce the rules, and
they cannot be tested until a database exists. The client tests prove the
client never asks for another member's data and never receives it; they do
not prove the database refuses it.

### 2.5 The share comparison — `AUD-TST-04` (part of F-H1)

**Root cause.** `InMemoryExpenseRepository.update` decided whether an edit
was financial with `existing.shares != expense.shares`. Every `Expense` wraps
its shares in a fresh `Map.unmodifiable`, so the two maps are never the same
object and the comparison was **always** true. Every edit therefore counted
as a financial change: the settled-history freeze blocked every edit of a
settled crib, including a rename, and a member that left could not even have
the description of their expense corrected.

**Change.** `FinancialLedger.sameShares(a, b)` compares the content, and the
repository uses it.

**Tests.** `test/active_member_enforcement_test.dart` (metadata-only edit),
`test/settlement_pairwise_debt_test.dart`.

---

## 3. The golden baseline — `AUD-TST-01`

**What was found.** The baseline in the working tree was **not** a reviewed
baseline. It was the last failing render, copied over the baseline:

| File | sha256 | Meaning |
|---|---|---|
| `HEAD:test/goldens/all_set_dialog.png` | `1cf5f6e9…` | the previously approved baseline |
| `HEAD:test/failures/all_set_dialog_masterImage.png` | `1cf5f6e9…` | the same bytes — the committed baseline *is* the master image of a committed failing run |
| working tree `test/goldens/all_set_dialog.png` (before this milestone) | `db39c073…` | the last failing render, written by `--update-goldens` |
| working tree `test/failures/all_set_dialog_testImage.png` | `db39c073…` | the same bytes — the baseline was overwritten with the failing render |

The overwrite happened at 14:54:52 on 2026-10-20, about 26 minutes before the
audit started, and it was **never committed** — `git status` showed
`M test/goldens/all_set_dialog.png`.

**The difference was measured independently** (own PNG decoder, not the test
runner):

```
HEAD approved baseline vs working-tree baseline
differing pixels: 2546 of 480000 => 0.5304%
max channel delta: 152
diff bbox: x 98-701, y 347-362      (16 rows of a single line of text)
ink per row: HEAD 540  vs  working tree 526   (the word got shorter)
```

That is exactly the `batch` to `crib` rename in
`lib/features/onboarding/invite_screen.dart:140`
(`'Your first batch is ready to roll.'` → `'Your first crib is ready to roll.'`),
which is part of the deliberate rename of the whole app.

**What was done.** The previously approved baseline was restored with
`git restore --source=HEAD -- test/goldens/all_set_dialog.png` and the
committed failure artefacts with it. **The baseline was not regenerated.** The
unapproved baseline was kept outside the repository at
`/var/folders/v3/q1yvrzsd55l54prdsgvcdgb80000gn/T/kilo/paycal_golden_backup/all_set_dialog.png`
(sha256 `db39c0731592aa15fd65fa56c2495634f7fa98e7c0d6510ce55099bcdabd192a`)
so nothing is lost.

**The result.** The golden probe now fails with `0.53%, 2546px` — the honest
consequence of the approved baseline against an unapproved UI change. The
decision needed is one of two, and it is a product decision, not a code
change:

1. **Approve the rename** → the baseline may be regenerated with
   `flutter test --update-goldens` and committed together with the rename.
2. **Reject the rename** → the text in `invite_screen.dart` goes back to
   `batch` and the approved baseline passes as it is.

Until one of those happens, **CI is red on the golden probe** and that is the
correct state.

---

## 4. The CI question, answered

**A clean checkout of `HEAD` passes CI — but it tests a different, older
app.** This was verified by extracting `HEAD` into a scratch directory:

| | Clean `HEAD` checkout | Clean copy of the current working tree |
|---|---|---|
| `flutter analyze` | No issues found! | No issues found! |
| `flutter test` | **8 passed, 0 failed** | **174 passed, 1 failed** (the golden) |
| `lib/data/` | `mock_data.dart`, `models.dart` | + `in_memory_repositories.dart`, `repositories.dart`, `dtos.dart`, `member_directory.dart` |
| `lib/domain/` | `balance_engine.dart` | + `financial_ledger.dart`, `recurring_scheduler.dart` |
| `test/` files | 4 | 19 |
| The UI | `lib/features/batches/` | `lib/features/cribs/` |

**The whole current architecture is untracked.** `git status` shows
`lib/data/in_memory_repositories.dart`, `lib/data/repositories.dart`,
`lib/domain/financial_ledger.dart` and every test file of the current
architecture as untracked or uncommitted. A CI job that checks out `HEAD`
therefore compiles and tests the **previous** app, and none of the fixes of
this milestone exist in CI at all.

**The fixes of this milestone are not in CI until the working tree is
committed.** That is the single most important thing left to do, and it is
not a code change.

---

## 5. Documentation that was corrected

| Document | What was wrong | What it says now |
|---|---|---|
| `docs/SUPABASE_MIGRATION_PLAN.md` §3.5 | The `pairwise_debt` SQL computed `sum(total_minor) - sum(share_minor)` over the payer's expenses with the payer and share predicates the wrong way round. With three participants it reported 667 for a debt of 333, and it did not describe the debt of a pair at all. | The SQL now mirrors the Dart: the payer's share in the expenses the other member paid, minus the settlements that happened. A note records the correction and points at the Dart reference and its tests. |
| `docs/SUPABASE_MIGRATION_PLAN.md` (M1) | Listed as an open acceptance list. | Marked as covered, with the tests named, and the two items that still need the backend (`time` field, server `occurredAt`) called out. |
| `docs/BACKEND_READINESS_AUDIT.md` | "delete cascades" (false), "overpayment rejection on both sides" (there was one, and it was the net rule), "the golden probe" (passes only against an unapproved baseline), and a "not covered" list with one item. | Corrected, with the corrections dated. The "not covered" list now also states that the client-side scoping is **not** a security boundary and that the RLS policies are still required. |
| `docs/PRODUCT_FINDINGS.md` | The historical register marked stale by the audit. | The historical text is preserved. A table now states which findings this milestone closed and which stay open. |
| `lib/data/repositories.dart` | "Deletes the crib **and the records that belong to it**" — false, the financial history is kept. Every contract now states its scope. | Corrected, and the scope of every read is documented. |
| `docs/MILESTONE_1_VERIFICATION.md` | "110 passed, 1 failed" and the golden characterisation. | A dated correction note was added at the top; the body is left as the historical record. |

---

## 6. What is still open

Closed by this milestone: **F-M1, F-H1 (partly), F-H2, F-H6, F-C1 (client
side), F-H3 (now tested), F-M3 (formatting half)**.

**Still open and deliberately not touched here:**

| Finding | Why not |
|---|---|
| F-C2 / `AUD-SEC-02` | Real authentication is a separate milestone (M4). The task forbids fake authentication. |
| F-C3 / `AUD-SEC-03` | The tombstone model and the delete guard need the schema. |
| F-H4 / `AUD-SEC-04` | Inventable members need the placeholder onboarding to be replaced by real invitations. |
| F-H5 / F-L2 | The activity `time` field needs the server timestamp and the UI change of M9. |
| F-H7 | The serialisation of concurrent settlements needs a database lock. |
| F-H8 | The recipient confirmation has no UI. |
| F-M2 | The amount field shows the device currency instead of the crib currency. |
| F-M4, F-M5, F-M6 | Member counts, the activity filter and the removed-member display. |
| F-M7 / D11 | **Needs a product decision:** who pays a recurring occurrence after the creator left. The unsafe behaviour (charging a removed member) is stopped, the replacement is not decided. |
| F-M8, F-M10, F-M11, F-L1, F-L3, F-L4, F-L5, F-L6, F-L7 | Unchanged. |
| `AUD-DAT-01` | There is still no durable persistence. This is the biggest remaining gap and it needs the backend. |
| `AUD-TST-02` | `test/failures/*.png` is still tracked in git. The artefacts were restored to their committed state, but untracking them is a change to the repository layout and was not made here. |
| `AUD-TST-03` | `test/repro_email_path_test.dart` still asserts nothing. |
| `AUD-TST-08` | The documentation of `docs/BACKEND_READINESS_AUDIT.md` is corrected; the other stale statements of the historical documents are left as the historical record. |
| `AUD-TST-09` | No device or simulator run was possible. |

---

## 7. Residual risk

1. **The client-side scoping is not a boundary.** It is a strong signal and a
   good contract, and it is exactly what the RLS policies have to mirror. A
   compromised client bypasses all of it. The RLS suite of
   `docs/SUPABASE_MIGRATION_PLAN.md` §6 M3 is the only thing that can close
   this, and it needs a database.
2. **The pairwise rule is implemented in one place.** The SQL mirror is
   written but untested. A literal port of the old Dart would have shipped the
   wrong rule, and the plan's own SQL sketch had the same bug until this
   milestone corrected it. The contract suite that runs against both
   implementations is the only thing that keeps them honest.
3. **The pairwise rule is a product interpretation.** "What A owes B" is
   defined as A's share in the expenses B paid. That is the reading of
   `PRODUCT_RULES.md` §4 and of §3.5, and it is the one the migration plan
   always meant, but it is a decision worth confirming before the schema is
   frozen.
4. **The suggested transfers are now pair by pair.** A crib with several
   payers can produce more transfers than the old net plan. Each one is a real
   debt between two people, and every one of them can be recorded, but the
   number of transfers the sheet shows is a product question.
5. **Concurrency is still untested.** Nothing in this milestone changes that.
6. **No device run.** The golden probe and the widget tests are the only
   checks of the UI.
7. **CI is red on the golden probe, on purpose,** and the fixes of this
   milestone are not in CI at all until the working tree is committed.

---

## 8. Commands and results

```
$ flutter analyze
Analyzing paycal...
No issues found! (ran in 2.5s)

$ flutter test
00:05 +174 -1: Some tests failed.
Failing tests:
  /Users/devangsonawane/paycal/test/golden_probe_test.dart: dialog probe
Golden "goldens/all_set_dialog.png": Pixel test failed, 0.53%, 2546px diff detected.

$ git show HEAD:test/goldens/all_set_dialog.png | shasum -a 256
1cf5f6e99dffa97a3e644fc8267a3c1cdcfb0f86e02b00816491c564f7bd06cd

$ shasum -a 256 test/goldens/all_set_dialog.png
1cf5f6e99dffa97a3e644fc8267a3c1cdcfb0f86e02b00816491c564f7bd06cd
```

---

---

# Milestone 2B — Product completeness, Crib Owner permissions, Git integrity and CI readiness

**Date:** 2026-10-20
**Scope:** the approved decisions A, B and C, the Crib Owner permission audit,
the Git integrity workstream, the golden-test decision, and the end-to-end
readiness of the twelve product flows.
**Not in scope:** Supabase integration, migrations, a platform role.

---

## 1. Verification results (executed)

| Command | Working tree | Clean checkout of `HEAD` (git worktree) |
|---|---|---|
| `flutter analyze` | **No issues found!** (2.2s) | **No issues found!** (2.8s) |
| `flutter test` | **234 passed, 0 failed** (7s) | **8 passed, 0 failed** (1s) |
| Test count | 234 (was 175 after Milestone 2) | 8 |
| Golden probe | **Passing** | **Passing** |

**59 new tests** in this milestone, in six new files:

| File | Tests | Covers |
|---|---|---|
| `test/owner_permissions_test.dart` | 34 | The whole Crib Owner / Crib Member matrix at the repository layer |
| `test/recurring_pause_test.dart` | 19 | Decision B: pause, assign a payer, resume |
| `test/settlement_pairwise_debt_test.dart` (+2) | 16 | Decision C: the net position agrees with the pairwise debt; a rejected settlement leaves the ledger untouched |
| `test/repository_isolation_test.dart` | 17 | Unchanged from Milestone 2 |
| `test/owner_ui_gating_test.dart` | 3 | The owner-only controls are not shown to a member |
| `test/end_to_end_flows_test.dart` | 1 | The twelve product flows in one story, with several members and two Cribs |

---

## 2. Decision A — the Crib name in the UI

**The rename was reviewed, not accepted blindly.**

* No user-visible "batch" string is left in `lib/`. The two remaining hits are
  deliberate: the persisted settings keys `batchesFilterIndex` /
  `batchesSortIndex` (internal identifiers, kept so the stored settings of an
  existing install survive) and the legacy `paycal://batch/<id>` deep link,
  which is **rejected** on purpose and must stay.
* The golden failure was **verified in a scratch copy** rather than assumed:
  with the old word restored, the current code renders **pixel-identical** to
  the approved baseline (`0 %` difference, the test passes). With the new
  word, the difference is exactly the `0.53 %, 2546 px` of that one line.
  So the rename is the **only** visual change and there is **no** layout,
  theme, typography or spacing regression.
* The baseline was then regenerated with `flutter test --update-goldens
  test/golden_probe_test.dart` — **only** `test/goldens/all_set_dialog.png`.
  The regenerated file is **byte-identical** to the unapproved baseline that
  was preserved in Milestone 2 (`db39c073…`), which is an independent
  confirmation that the approved baseline was the correct rendering of the
  current code.
* No other golden file exists and none was touched.

---

## 3. Decision B — the payer of a recurring transfer

**The rule:** when the member who pays a recurring schedule leaves the Crib or
is removed, the schedule pauses until an active payer/manager is explicitly
assigned.

### 3.1 The model change that was needed

`PRODUCT_RULES.md` §5 described a schedule as holding its timezone, its local
time, its start date, its recurrence rule, its anchor day, **its creator** and
its active state. There was no payer and no paused state, so the approved
behaviour could not be expressed.

**The smallest change** (`lib/data/models.dart`):

| Field | Meaning |
|---|---|
| `payerId` (`String?`) | The member who pays the generated occurrences. `null` means **paused**. Defaults to the creator. |
| `resumeFrom` (`DateTime?`) | The local due date the schedule continues from after a pause. |
| `isPaused` (getter) | `payerId == null` — derived, so the two can never disagree. |

`copyWith` needs a sentinel so `null` can be set explicitly. A plain `??`
silently turned "paused" back into "the creator pays" — that was a real bug
during the implementation and it is covered by a test.

### 3.2 The behaviour

| Situation | Behaviour |
|---|---|
| The payer is removed | The schedule is **paused**, `recurring_paused` is recorded |
| A paused schedule is due | **Nothing is generated** |
| The owner assigns an active member | The schedule **resumes**, `recurring_payer_assigned` and `recurring_resumed` are recorded |
| A member tries to assign | **Refused** |
| The assignee is not an active member, or is outside the Crib | **Refused** |
| A cancelled schedule | **Refused** |
| The schedule runs again | The **new** payer pays the new occurrences |
| The schedule is resumed | **No occurrence is duplicated** — the key is `schedule id + due date` |
| The schedule resumes | It continues at the first due date after the pause. The missed occurrences are **not** generated as a backlog |

The generated expenses and occurrences that already exist stay in the ledger.

### 3.3 Two consequences that need a product decision

1. **The owner cannot be removed**, so the creator of a schedule can only
   leave through an ownership transfer or an account deletion — neither
   exists in v1. The reachable path is that the owner hands the schedule to a
   member (`assignPayer`) and that member leaves. This is why `assignPayer`
   works on a running schedule and not only on a paused one.
2. **A pause drops the occurrences that were due before it but not yet
   generated.** Nothing is corrupted — they were not in the ledger before the
   pause either — but the payer contributes less to the ledger than they
   would have. The alternative (generating them at the moment of the pause)
   was not chosen, because it would make a membership change create
   expenses. **This needs a product decision.**

### 3.4 A deterministic clock

`InMemoryStore` gained a `clock` seam, and the moment a member leaves, the
moment an invitation expires and the timestamps of the activity feed all come
from it. Without it the pause point was the real wall clock and the test was
not reproducible. `TestHarness` can pin the moment.

---

## 4. Decision C — the pairwise debt is the source of truth

**Verified, not assumed.** The whole model was re-read and the behaviour
proved by execution:

| Requirement | Where it is proved |
|---|---|
| Only `confirmed` and `selfManaged` settlements reduce the debt | `financial_ledger_test.dart` "a pending settlement does not reduce the debt" |
| A pending request does not use up the debt | `settlement_pairwise_debt_test.dart` "a pending request does not use up the debt" |
| The validation is about the pair, not the net balance | `settlement_pairwise_debt_test.dart` (both failure directions) |
| **The net balance is the pairwise debt of every pair, summed up** | `settlement_pairwise_debt_test.dart` "the net balance is the pairwise debt of every pair, summed up" — **new in 2B** |
| The suggested transfers are valid and **recordable** | `settlement_pairwise_debt_test.dart` "every suggested transfer can actually be recorded" and "recording the suggested transfers brings the crib to zero" |
| Mutual debts, cycles, remainders, partial payments, overpayments | `financial_ledger_test.dart` (9 tests) and `settlement_pairwise_debt_test.dart` |
| An invalid settlement does not corrupt the ledger | `settlement_pairwise_debt_test.dart` "a rejected settlement does not touch the ledger" — **new in 2B** |

**The documentation was corrected with the code.** The `pairwise_debt` SQL in
`docs/SUPABASE_MIGRATION_PLAN.md` §3.5 computed `sum(total_minor) -
sum(share_minor)` over the payer's expenses with the payer and share
predicates the wrong way round: it reported the claim of the *group* on the
payer, not the claim of the participant on the payer. With three participants
it reported 667 for a debt of 333. The SQL now mirrors the Dart, and a dated
note records the correction.

---

## 5. The Crib Owner permission audit

The full matrix, the code references, the tests and the open decisions are in
`docs/ADMIN_ROLE_AND_PERMISSION_AUDIT.md`.

**The owner permissions are enforced at the repository layer for every
owner-only operation**, and `test/owner_permissions_test.dart` proves each one
for a member, for a stranger and for a signed-out caller.

**Two defects were found and fixed in the interface:**

| Defect | Fix |
|---|---|
| The Crib editor showed the name, the currency, the member management, the invite link, the revoke button and the delete button to **every** member. Every one of them failed with an error toast | The editor is now read-only for a member; `test/owner_ui_gating_test.dart` |
| The member list showed `You (owner)` for whoever was signed in, not for the owner. A member reading the roster would believe they own the Crib | The owner is marked as such, everybody else is marked as "You" |

**One misleading message was corrected:** the delete confirmation said
*"Everyone loses access and its expenses go with it"*. The implementation
**keeps** the expenses and settlements — it orphans them. The text now says
what actually happens.

**A previous audit statement was wrong and is corrected here:** the earlier
audit recorded "no delete-crib affordance found". The delete **does** exist,
in `lib/features/cribs/crib_edit_sheet.dart`.

---

## 6. Git integrity and the clean checkout

### 6.1 The state that was found

| | Files | Detail |
|---|---|---|
| **Committed** (`HEAD 41b1213`) | the previous app | `lib/features/batches/`, `lib/domain/balance_engine.dart`, `lib/data/{mock_data,models}.dart`, 4 test files |
| **Staged** | 5 pure renames | `lib/features/batches/` → `lib/features/cribs/` (0 content change in the index) |
| **Unstaged** | 32 files, +1647/−825 | the content of the rename, the expanded models, the new features, `pubspec` |
| **Untracked** | **41 files** | all of `docs/`, the whole new architecture (`in_memory_repositories.dart`, `repositories.dart`, `financial_ledger.dart`, `recurring_scheduler.dart`, `dtos.dart`, `member_directory.dart`) and 16 test files |

**Nothing was reset, discarded, staged or committed.** The index and the
working tree are exactly as they were found, except for the files this
milestone changed.

### 6.2 The clean-checkout verification

A **git worktree** was used, which is non-destructive:

```
$ git worktree add --detach <scratch> HEAD
HEAD is now at 41b1213 some final touces
```

| | Clean checkout of `HEAD` | Working tree |
|---|---|---|
| `flutter analyze` | No issues found! | No issues found! |
| `flutter test` | **8 passed** | **234 passed** |
| `lib/data/` | `mock_data.dart`, `models.dart` | + `in_memory_repositories.dart`, `repositories.dart`, `dtos.dart`, `member_directory.dart` |
| `lib/domain/` | `balance_engine.dart` | + `financial_ledger.dart`, `recurring_scheduler.dart` |
| `test/` files | 4 | 21 |
| The UI | `lib/features/batches/` | `lib/features/cribs/` |

**The clean checkout passes — but it is the previous app.** A CI job that
checks out `HEAD` compiles and tests the *old* code base with 8 tests. **None
of the fixes of Milestone 2 or 2B exist in CI**, because 41 of the files that
make up the current implementation are untracked.

### 6.3 The files that have to be tracked for CI to be meaningful

Nothing was staged or committed. The exact list of the files that belong to
this project and are currently untracked:

```
docs/ACCOUNT_DELETION.md                docs/PRODUCT_AUDIT.md
docs/BACKEND_READINESS_AUDIT.md         docs/PRODUCT_FINDINGS.md
docs/BACKEND_SECURITY_REQUIREMENTS.md   docs/PRODUCT_REMEDIATION_PLAN.md
docs/COMPREHENSIVE_PRODUCT_AUDIT.md     docs/PRODUCT_RULES.md
docs/END_TO_END_TEST_MATRIX.md          docs/RELEASE_READINESS_CHECKLIST.md
docs/FINANCIAL_RULES.md                 docs/SECURITY_AND_DATA_INTEGRITY_FINDINGS.md
docs/MILESTONE_1_VERIFICATION.md        docs/SUPABASE_MIGRATION_PLAN.md
docs/MILESTONE_2_VERIFICATION.md        docs/ADMIN_ROLE_AND_PERMISSION_AUDIT.md
lib/data/dtos.dart                      lib/domain/recurring_scheduler.dart
lib/data/in_memory_repositories.dart    test/active_member_enforcement_test.dart
lib/data/member_directory.dart          test/activity_test.dart
lib/data/repositories.dart               test/crib_operations_test.dart
lib/domain/financial_ledger.dart         test/end_to_end_flows_test.dart
                                         test/expense_permissions_test.dart
                                         test/financial_ledger_test.dart
                                         test/golden_probe_test.dart (tracked)
                                         test/in_memory_repositories_test.dart
                                         test/invitations_test.dart
                                         test/membership_test.dart
                                         test/money_test.dart
                                         test/owner_permissions_test.dart
                                         test/owner_ui_gating_test.dart
                                         test/recurring_pause_test.dart
                                         test/recurring_test.dart
                                         test/repository_isolation_test.dart
                                         test/repro_email_path_test.dart
                                         test/settlement_pairwise_debt_test.dart
                                         test/settlements_test.dart
                                         test/support/harness.dart
                                         test/ui_flows_test.dart
```

**Proposed action, not taken:** one commit that adds the current
implementation and the tests, so that CI tests the code that is actually
being developed. It needs approval.

### 6.4 The generated artefacts

`test/failures/` holds four PNG files that Flutter writes when a golden test
fails. **They are tracked in git and `.gitignore` does not exclude them.**

* They were **not** deleted. After the baseline was regenerated they hold the
  comparison "approved baseline → new render": the `masterImage` is still the
  previously approved baseline and the `testImage` is the new render, which is
  exactly the evidence of the change that was approved.
* **Proposed action, not taken:** untrack `test/failures/` and add it to
  `.gitignore`. It is a change to the repository layout and to the index, so
  it needs approval.

---

## 7. What was audited and confirmed

| Area | Result | Evidence |
|---|---|---|
| Money parsing | Negative, zero, boundaries, invalid input, overflow, exact formatting | `test/money_test.dart` (11) |
| Splits | Equal, custom, percentage, deterministic remainders | `test/financial_ledger_test.dart` |
| Pairwise debt and the settlement rule | Both failure directions, partial payments, retries, duplicate keys, mismatched payloads | `test/settlement_pairwise_debt_test.dart` (16) |
| Suggested transfers | Inside the debt, recordable, bring the crib to zero, mutual debts and cycles cancelled | `test/financial_ledger_test.dart`, `test/settlement_pairwise_debt_test.dart` |
| Active-member enforcement | The domain rule for a new record, the record rule for the history | `test/active_member_enforcement_test.dart` (12) |
| Historical preservation | Removing a member keeps the expenses, the shares, the settlements and the balances intact | `test/active_member_enforcement_test.dart`, `test/end_to_end_flows_test.dart` |
| Repository isolation | Cribs, expenses, settlements, activity, invitations, removed members, signed-out | `test/repository_isolation_test.dart` (17) |
| Owner permissions | 34 cases | `test/owner_permissions_test.dart` |
| Account lifecycle | Sign-out does **not** sign out, account deletion is a toast, the owner cannot be removed, a member cannot leave | `test/owner_permissions_test.dart`, `docs/ACCOUNT_DELETION.md` |
| Activity history | Every mutation writes an event with an action, a target, a Crib and an actor | `test/activity_test.dart` (8) |
| The twelve product flows | One story, several members, two Cribs | `test/end_to_end_flows_test.dart` |

---

## 8. The remaining risks

1. **The client is not a security boundary.** Every permission check lives in
   the client. The RLS policies and the RPC authorisation checks have to
   enforce the same rules, and they cannot be tested until a database exists.
2. **The current implementation is not in CI.** 41 files are untracked. A
   clean checkout tests the previous app.
3. **There is no authentication and no durable storage.** The account
   lifecycle, the session and the cross-device behaviour are untestable in
   this architecture.
4. **The activity trail is client-written.** The actor is the client-owned id
   and the timestamp is the client clock. Both have to move to the server.
5. **A pause drops the missed occurrences** (§3.3). A product decision.
6. **A member cannot leave a Crib and ownership cannot be transferred** — the
   two lifecycle gaps that block the owner story.
7. **Deleting a Crib orphans its financial rows** and is not refused when the
   Crib has confirmed settlements.
8. **No device or simulator run.** Every UI claim comes from a widget test or
   from reading the code, never from a real device.

---

---

# Milestone 2C — Finishing the app and preparing for Supabase

**Date:** 2026-10-20
**Scope:** the Crib Owner controls, the Git and CI tracking, the release
journeys, and the Supabase preparation.

## 1. Verification (executed)

| Where | `flutter analyze` | `flutter test` |
|---|---|---|
| Working tree | **No issues found!** | **249 passed, 0 failed** |
| **Clean checkout of the intended revision** | **No issues found!** | **249 passed, 0 failed** |
| `--platform chrome` (real web platform) | — | **248 passed, 1 failed** (the golden, see §4) |
| Clean checkout of `HEAD 2fe68eb` | No issues found! | 8 passed (the previous app) |

## 2. What was implemented

| Change | Where | Tests |
|---|---|---|
| **The Crib Owner may edit and delete any expense of their own crib** | `in_memory_repositories.dart` `_canManageExpense`, `expense_detail_screen.dart` `_canManage` | `expense_permissions_test.dart` (4 new), `ui_flows_test.dart` (1 new) |
| **Recurring transfers can be edited** — amount, description, category, frequency, recipient, first date | `RecurringPaymentRepository.update`, `crib_detail_screen.dart` | `recurring_pause_test.dart` (5 new) |
| The Crib editor, the recurring controls and the scan picker show the owner-only actions only to the owner | `crib_edit_sheet.dart`, `crib_detail_screen.dart`, `scan_flow.dart`, `option_tile.dart` | `owner_ui_gating_test.dart`, `release_journeys_test.dart` |
| A double tap on "Record my transfer" cannot record twice | `settle_up_sheet.dart` `_RecordTransfersButton` | — |
| The delete confirmation says what actually happens to the expenses | `crib_edit_sheet.dart` | `release_journeys_test.dart` |

## 3. Git and CI

* **Everything is tracked.** The previous milestone's 41 untracked files were
  committed by the user in `2fe68eb`; this milestone adds the remaining
  changes to the index.
* **`test/failures/` is no longer tracked** and is in `.gitignore`. Those are
  generated failure artefacts, not source. They stay on disk.
* **A clean checkout of the intended revision passes the whole suite.** That
  was the open item, and it is now closed. The check was done with
  `git checkout-index -a --prefix=<dir>/`, which writes exactly the tracked
  files into an empty directory — a true clean checkout without a commit.
* Nothing was committed or pushed. **The index needs one commit.**

## 4. The golden baseline is platform-specific

The single baseline was rendered on macOS. On Chrome the same layout renders
with a different font rasterisation. Measured with an independent PNG
decoder:

* **identical card bounds** in both,
* **identical ink profile** on every sampled row (delta 0, except the one
  text row that differs by 20 pixels),
* 10,535 differing pixels of 480,000 — **2.19 %**.

That is a rasterisation difference, **not a layout regression**. For a CI
that runs several platforms, either keep a baseline per platform or run the
golden test on the reference platform only.

## 5. Supabase preparation

`docs/SUPABASE_MIGRATION_PLAN.md` §0 now carries the practical plan: the
minimum nine tables, the authentication requirements, the three rules the
database has to enforce, the owner permissions as server-side RPCs, the
constraints that protect the money, the order to build it in, and the tests
that have to pass against the database.

The RPC authorisation now mirrors the product decision: `update_expense` and
`delete_expense` accept the Crib Owner, not only the payer and the author.

---

# Milestone 2D — Final pre-Supabase product verification

**Date:** 2026-10-20
**Scope:** the last verification pass before the backend work. The app was run
on a real device, the money rules were checked against hand-computed numbers,
and the deletion behaviour was made consistent.

## 1. Verification (executed)

| Where | `flutter analyze` | `flutter test` |
|---|---|---|
| Working tree | **No issues found!** | **274 passed, 0 failed** |
| Clean checkout of the intended revision | **No issues found!** | **274 passed, 0 failed** |
| `flutter test --platform chrome` | — | 273 passed, 1 failed (the golden, platform specific) |
| **macOS desktop, a real device** | — | **both integration tests pass** |
| **iOS 18.0 simulator, a real device** | — | the app **launches and renders**; the scripted runner does not finish in this headless environment |
| Android | — | **unverified, no AVD on this machine and the Android licences are not accepted** |

The two integration tests have to be run **one file at a time**: the runner
starts the app once per command, and a second app cannot be foregrounded while
the first one is running.

## 2. What was fixed

| Defect | Fix | Tests |
|---|---|---|
| **Deleting a Crib orphaned its financial rows.** The expenses, the settlements and the activity pointed at a crib that no longer existed, so the balances of a deleted crib could not be computed any more | The delete is a **tombstone** now: the row stays with `deleted_at`, so the history still resolves, and the members lose access to the crib and to its records | `crib_operations_test.dart` (4 new), `release_journeys_test.dart` |
| **A deleted Crib could be deleted again**, which wrote a second `crib_deleted` event | The owner operations refuse a deleted crib | `crib_operations_test.dart` |
| **A deleted Crib could still be updated**, and its membership could still be changed | Same guard | `crib_operations_test.dart` |
| The `test/failures/` artefacts were tracked in git | They are generated output, so they are ignored and untracked now | — |
| The `integration_test` package was missing | Added as an SDK dev dependency, so the device smoke test can run | `integration_test/app_smoke_test.dart` |

## 3. The money rules, checked by hand

`test/financial_scenarios_test.dart` works the expected numbers out by hand
instead of calling the ledger again. It covers the equal split with the
remainder, the percentage split, two payers, editing and deleting an expense,
a partial settlement, the suggested transfers, a repeated submission and the
currency precision.

Two findings came out of it, both in the **test**, not in the code:

* The percentage split gives the remainder to the payer, the same rule as the
  equal split. The test now says so.
* The suggested transfers settle the **mutual** debt first: "me" and "a" owe
  each other 333 and 300, so only the 33 that "me" is owed stays, and the plan
  is `a → me 33`, `b → me 333`, `b → a 300`. Recording it brings every
  member to exactly zero.

## 4. The recurring transfers

`test/recurring_pause_test.dart` now also checks the generated occurrences: a
monthly schedule runs on the fifteenth of every month, every occurrence carries
the amount, the currency and the payer, running the generation twice does not
create a second expense, a schedule that is not due yet generates nothing and a
cancelled schedule generates nothing any more.

## 5. The deletion, decided

The rules did not say what happens to the financial history of a deleted Crib.
The simplest consistent behaviour is now in place and in the product rules:

* the Crib keeps its row, so the expenses, the settlements and the activity
  of it still point at something that exists and the balances still add up;
* the members lose access to the Crib and to all of its records;
* a deleted Crib cannot be changed, deleted again, or have its membership
  touched.

This is the same model the backend uses (`deleted_at` plus RLS), so the
in-memory implementation previews the database behaviour.

## 9. Cross-references

* `docs/COMPREHENSIVE_PRODUCT_AUDIT.md` — the audit and the finding register
* `docs/SECURITY_AND_DATA_INTEGRITY_FINDINGS.md` — the RLS and RPC control map
* `docs/END_TO_END_TEST_MATRIX.md` — per-journey execution status
* `docs/RELEASE_READINESS_CHECKLIST.md` — the go/no-go gates
* `docs/SUPABASE_MIGRATION_PLAN.md` — the schema and the rules this milestone
  made concrete
* `docs/MILESTONE_1_VERIFICATION.md` — the previous milestone, corrected
