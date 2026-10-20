# PayCal End-to-End Test Matrix

**Date:** 2026-10-20
**Purpose:** Record, per user workflow, whether it was **actually executed** or
only inspected statically. No journey in this product has been executed as a
real end-to-end user journey (real user, real device, real backend).

## Status legend

| Status | Meaning |
|---|---|
| **Passed by execution** | A test executed the workflow's assertions and they passed in the current run. *Caveat: all such tests are widget/unit tests — no device run.* |
| **Failed by execution** | A test executed and failed. |
| **Static inspection only** | Traced by reading code. Never executed. |
| **Not tested** | No coverage and no executed evidence; behavior unknown. |
| **Not applicable** | Journey does not exist in the product; reason given. |

**Execution basis:** `flutter test` → **234 passed, 0 failed** (7s).
`flutter analyze` → **No issues found!**

> **Update 2026-10-20 (pre-Supabase fixes).** The suite grew from 112 to 175
> tests. The journeys that changed: **J8** (settlements) is now backed by
> `test/settlement_pairwise_debt_test.dart` and the rule it enforces is
> correct; **J14** (restart) is unchanged, because there is still no
> persistence; the cross-crib leakage of **J4, J10 and J13** is closed on the
> client side by `test/repository_isolation_test.dart`, but only the client
> side — the database half is still untestable. The "coverage gaps" list in
> §3 shrank by four items.
>
> **Update 2026-10-20 (Milestone 2B).** The suite grew from 175 to **234**
> tests, all passing. `test/end_to_end_flows_test.dart` walks the **twelve
> product flows in one story**, with several members and two Cribs in the
> same store: it is an **integration test at the repository level**, not a
> device test. The Crib Owner permissions are proved by
> `test/owner_permissions_test.dart` (34 cases) and
> `test/owner_ui_gating_test.dart`. The recurring payer is proved by
> `test/recurring_pause_test.dart` (19 cases). The golden probe passes
> again — the baseline was verified and regenerated in Milestone 2B.
>
> **The test types in this suite:**
>
> | Type | Where | What it proves |
> |---|---|---|
> | Unit | `money_test.dart`, `financial_ledger_test.dart`, `recurring_test.dart` | The rules of the domain, in isolation |
> | Repository | `owner_permissions_test.dart`, `repository_isolation_test.dart`, `settlement_pairwise_debt_test.dart`, `active_member_enforcement_test.dart`, `recurring_pause_test.dart`, `membership_test.dart`, `invitations_test.dart`, `expense_permissions_test.dart`, `settlements_test.dart`, `crib_operations_test.dart`, `in_memory_repositories_test.dart` | The contracts and the authorisation, against the in-memory implementation |
> | Widget | `ui_flows_test.dart`, `onboarding_smoke_test.dart`, `owner_ui_gating_test.dart`, `widget_test.dart`, `golden_probe_test.dart` | What the interface renders and which controls it offers |
> | Integration (repository level) | `end_to_end_flows_test.dart` | The twelve flows, in order, with several members and two Cribs |
> | **Device / real network** | **none** | **Not available in this environment. Every platform behaviour is unverified.** |

**Absolute constraint on every row below:** the app has **no authentication** and
**no persistence**. A journey that depends on a signed-in identity or on data
surviving a restart **cannot** be executed end to end in this architecture, no
matter how many unit tests exist. Rows are marked accordingly.

---

## 1. Journey matrix

### J1 — First launch and onboarding

| Aspect | Detail |
|---|---|
| **Status** | **Passed by execution** (render/flow coverage) / **Static inspection only** (real device behaviour) |
| **Code paths** | `lib/app/paycal_app.dart` → `lib/app/splash_screen.dart` (900 ms auto-nav) → `lib/features/onboarding/welcome_screen.dart` → `product_tour_screen.dart` → `onboarding_flow.dart` (5 steps) → `birthday_sheet.dart` → `create_account_screen.dart` → `verify_email_screen.dart` → `notifications_sheet.dart` → `first_crib_screen.dart` → `invite_screen.dart` |
| **Executed evidence** | `test/onboarding_smoke_test.dart` (5 tests): welcome, onboarding flow steps, product tour, first crib + invite, create account + sign in |
| **Controls** | Splash: none. Welcome: "Get started", "Sign in". Tour: Skip / Next / "Set up my account" (3-slide `PageView`). Onboarding: back/skip/continue, 4 gender tiles, date picker, 6 role tiles, category chips, household ±1..10. Create account: Google / email. Verify: "I verified — continue", resend (30 s cooldown), "Use a different email". Notifications: "Turn on notifications" / "Not now". First crib: 2 tabs, name, currency segmented, category chips, invite-code field, "Create crib" / "Join", "Skip for now". Invite: share/copy, "Start splitting" |
| **Data read / changed** | Reads: `AppSettings`, `OnboardingDraft` (SharedPreferences). Changes: `OnboardingDraft`, `CribRepository.create` |
| **Validation** | Step-level validation (continue blocked until the step is valid); name/category validation in `FirstCribScreen`; empty invite code → toast |
| **States** | Loading: `WedgeLoader` in `OnboardingFlow`. Success: confetti on crib creation. Error: `RepositoryException` → toast |
| **Defects** | **AUD-CTRL-02** "Turn on notifications" never requests permission or schedules anything. **AUD-CTRL-03** "Join with a link" only shows a toast — there is no token-entry path, so an invited user who skipped onboarding **cannot join**. **AUD-SEC-04** creates placeholder members `ob1…obN`. `CreateAccountScreen` hard-codes `email: 'you@gmail.com'` |
| **Unverified** | Real share-sheet delivery, real notification permission dialog, real device layout at small widths, whether the onboarding draft survives an app kill mid-flow |

### J2 — Sign-up, sign-in, session restoration, sign-out

| Aspect | Detail |
|---|---|
| **Status** | **Static inspection only** (and partially **Not tested**) |
| **Code paths** | `lib/features/auth/sign_in_screen.dart`, `create_account_screen.dart`, `verify_email_screen.dart`; `lib/data/in_memory_repositories.dart:96-123` (`AuthRepository`); `lib/features/profile/profile_screen.dart:527-564` |
| **Executed evidence** | `test/onboarding_smoke_test.dart` covers *rendering* of create-account and sign-in. `test/ui_flows_test.dart` — no sign-in flow test. **No test asserts that a user is authenticated, that a session exists, that a session is restored, or that sign-out revokes anything.** |
| **Actual behaviour** | `AuthRepository.signIn(email, displayName)` validates email *format* only, then sets `AuthUser(id: _store.currentUser?.id ?? 'me', name: …, email: …)`. No password, no token, no expiry, no server. `SignInScreen._signIn` waits 600 ms and navigates to `MainShell` **without calling `auth.signIn`**. The Google button navigates directly. `CreateAccountScreen` waits 450 ms and navigates to `VerifyEmailScreen` with a hard-coded email. `VerifyEmailScreen` simulates polling. "Log out" (`profile_screen.dart:551-564`) shows a confirm sheet and navigates to `WelcomeScreen` — **it never calls `signOut()`**, so `_store.currentUser` remains set and the user is still authenticated to every repository. "Delete account" (`:527-548`) shows the toast `Account deletion requested` and calls nothing |
| **Session restoration** | **Does not exist.** `PayCalRepositories.instance` holds a single in-memory store; a fresh process re-seeds from `MockData`. The only persisted state is `OnboardingDraft` and some `AppSettings` values |
| **Defects** | **AUD-SEC-02** (Critical), **AUD-SEC-06** (Critical), **AUD-CTRL-01** "Forgot password" has no handler |
| **Unverified** | Everything that requires a real identity |

### J3 — Create a batch/crib and configure members/currency

| Aspect | Detail |
|---|---|
| **Status** | **Passed by execution** |
| **Code paths** | `lib/features/cribs/create_crib_popup.dart`, `lib/features/onboarding/first_crib_screen.dart`; `in_memory_repositories.dart:129-195` (`create`, `update`) |
| **Executed evidence** | `test/ui_flows_test.dart` "a new crib is created through the repository"; `test/crib_operations_test.dart` (11 tests): creator becomes owner, duplicate id, non-owner update denial, stale version, currency change blocked after activity/settlement, owner-only delete, stale-version delete, not-found |
| **Rules enforced** | `create` requires an authenticated user, rejects a duplicate id, sets `owner = ownerId ?? actor.id`, **requires `owner == actor.id`**, and adds the actor as `MemberRole.owner`. `update` requires the owner, enforces a version conflict, **rejects membership changes** (directing to `addMember`/`removeMember`), and blocks a currency change once financial activity exists |
| **Defects** | **AUD-SEC-04** placeholder members. **AUD-FIN-09** `ownerId` nullable with a first-admin fallback (`in_memory_repositories.dart:867-873`; runtime-confirmed: with `ownerId = null` the first `MemberRole.owner` member may update, a non-admin is rejected). **AUD-CTRL-04** no delete-crib UI affordance found |
| **Unverified** | Whether a second device sees the new crib — impossible today |

### J4 — Invite a member, accept, reject invalid/expired tokens

| Aspect | Detail |
|---|---|
| **Status** | **Passed by execution** |
| **Code paths** | `lib/core/utils/deep_link.dart`, `lib/features/onboarding/invite_screen.dart`, `lib/features/cribs/crib_edit_sheet.dart`; `in_memory_repositories.dart:730-850`; `lib/core/config/app_config.dart` |
| **Executed evidence** | `test/invitations_test.dart` (11 tests): signed-out accept, unknown token, crib-id-is-not-a-token, revoked, expired, past expiry on create, accept adds member, double accept, existing member, owner-only create, owner-only revoke, token opacity. `test/ui_flows_test.dart`: "an invitation link joins the crib", "a crib link never grants membership" |
| **Rules enforced** | Token: 32 chars, `Random.secure()`, 62-char alphabet. `create` is owner-only, requires `createdById == actor.id`, requires a future expiry, default lifetime 7 days (`AppConfig.invitationLifetime`). `accept` chain: token → revoked → expired → used → crib → membership eligibility → add/reactivate member → mark consumed. Single-use. `revoke` is owner-only and invalidates future joins while keeping already-accepted members. `paycal://crib/<id>` and `paycal://batch/<id>` are **rejected with a toast and grant nothing** |
| **Defects** | **AUD-SEC-05** `getById(token)` needs no user and returns `cribId`/`createdById` for any token (metadata leak). Tokens stored plaintext (memory only). `invite_screen.dart` reuses an existing active invitation rather than creating a new one — not documented in `PRODUCT_RULES.md` |
| **Unverified** | Real deep-link delivery from a browser/SMS, rate limiting, real share-sheet content |

### J5 — Add an expense with equal, custom and percentage splits

| Aspect | Detail |
|---|---|
| **Status** | **Static inspection only** (the split math is **Passed by execution**; the UI paths are not) |
| **Code paths** | `lib/features/expenses/quick_add_sheet.dart`, `lib/features/expenses/split_share_editor.dart`; `lib/domain/financial_ledger.dart`; `lib/data/member_directory.dart`; `lib/features/home/home_screen.dart` |
| **Executed evidence (math only)** | `test/financial_ledger_test.dart` (9 tests): equal-split remainder, percentage-split exactness, duplicate/invalid split rejection, the expense-validation matrix, immutable share copy, balance recalculation, confirmed-vs-pending settlement effect, suggested transfers |
| **Actual behaviour** | `QuickAddSheet` selects a crib, type, amount (`AmountField`), description. With a `payeeId` the shares map entirely to the payee. Otherwise `FinancialLedger.equalSplit(totalMinor, participantIds, payerId: _meId)`. `SplitShareEditor` supports `equal` / `exact` / `percent`: exact parses each amount with `Money.tryParseToMinor` and requires all ≥ 0 and the sum == total; percent converts to basis points (×100) and calls `FinancialLedger.percentageSplit`, which throws `FinancialValidationException` unless the basis points total exactly 10 000 |
| **Defects** | **AUD-FIN-01** `Money.tryParseToMinor('-0.50')` → `+50` (negative sub-unit amount becomes a positive expense). **AUD-FIN-07** the amount field shows the **device** currency symbol while the expense is stored in the **crib** currency. **AUD-FIN-08** the editor's member count includes removed members. **AUD-FIN-03** the domain `validateExpense` allows a removed participant (the repository rejects it). **F-L3** the exact/percent controllers are built lazily and are not rebuilt when the member list changes while the sheet is open |
| **Unverified** | The custom and percentage split **UI** paths were not executed by any test |

### J6 — Edit or delete an expense before and after settlements

| Aspect | Detail |
|---|---|
| **Status** | **Passed by execution** |
| **Code paths** | `lib/features/expenses/expense_detail_screen.dart`; `in_memory_repositories.dart:286-440` |
| **Executed evidence** | `test/expense_permissions_test.dart` (11 tests): payer-only create, non-member create denial, creator/payer edit, third-party edit and delete denial, dispute by any member, dispute preserves money, version conflict, immutable payer and currency. `test/ui_flows_test.dart`: "the expense screen hides edit and delete for other members", "the payer can edit the expense". `test/settlements_test.dart`: "expenses of a settled crib cannot be edited any more" |
| **Freeze rule as implemented** | `in_memory_repositories.dart:334-339` computes `financialChanged` = `totalMinor`, `payerId` or `shares` differ. The settled-history check at `:425-440` blocks the crib's expenses when **any** `confirmed`/`selfManaged` settlement exists — but only when financial fields changed. A metadata-only edit (description/category) is therefore **allowed** |
| **Gap** | The **approved** rule in `PRODUCT_RULES.md` §2 still says "its expenses can no longer be edited or deleted" once a settlement exists. The implementation is **narrower than the approved rule** and **broader than the planned rule** in `SUPABASE_MIGRATION_PLAN.md` §3.4 (which freezes only expenses whose affected set includes a settled pair). The plan's own acceptance criteria — "allows an unrelated one" and "allows metadata-only edits" — have **no test** |
| **Defects** | **AUD-DAT-03** expense delete is a hard delete; the activity trail survives and points at a record that no longer exists (tombstone is Open in `PRODUCT_RULES.md` §2) |
| **Unverified** | — |

### J7 — Calculate balances and suggested transfers

| Aspect | Detail |
|---|---|
| **Status** | **Passed by execution** (math) / **Static inspection only** (presentation) |
| **Code paths** | `lib/domain/financial_ledger.dart`; `lib/features/settlements/settle_up_sheet.dart`; `lib/features/cribs/crib_detail_screen.dart`; `lib/domain/balance_engine.dart` |
| **Executed evidence** | `test/financial_ledger_test.dart`: balance recalculation, confirmed-vs-pending settlement effect, suggested transfers. `test/widget_test.dart`: `BalanceEngine.equalSplit` remainder |
| **Actual behaviour** | `FinancialLedger.balances(crib, expenses, settlements)` derives net per member. `suggestedTransfers` produces a minimal greedy transfer set. `SettleUpSheet` splits the result into "mine" and "theirs" and only lets the signed-in member record their own transfers — correct per `PRODUCT_RULES.md` §4 |
| **Defects** | **AUD-FIN-03** the domain's participant-activeness rule is inconsistent (expense vs settlement), so `balances()` has no authoritative guard on removed members |
| **Unverified** | — |

### J8 — Record full and partial settlements

| Aspect | Detail |
|---|---|
| **Status** | **Passed by execution** (repository) / **Static inspection only** (the UI create path) |
| **Code paths** | `lib/features/settlements/settle_up_sheet.dart`; `in_memory_repositories.dart:447-563`; `lib/data/models.dart` (`Settlement`, `SettlementStatus`) |
| **Executed evidence** | `test/settlements_test.dart` (11 tests): sender-only create, no direct confirm, overpayment rejection (×2), idempotency replay, recipient-only confirm, sender-only cancel, confirmed immutable, stale version, settled crib freezes expenses, settlement ≠ spending |
| **Actual behaviour** | `create` requires the actor to be the sender; a `confirmed` settlement cannot be created directly; the overpayment check at `:504-518` uses the **net** balance; the idempotency key is matched on `cribId && idempotencyKey && fromMemberId == actor.id` with an `amountMinor`/`toMemberId` payload comparison on replay; `updateStatus` allows the **recipient** to confirm a `pending` settlement and the **sender** to cancel one |
| **Defects** | **AUD-FIN-02** (High) **CLOSED** — the settlement is now validated against the debt of the **pair**, not the net position of the sender. `FinancialLedger.pairwiseDebt`, `test/settlement_pairwise_debt_test.dart`: a payer cannot settle a person they owe zero to, a legitimate payment is not refused because of unrelated netting, partial payments leave the rest as debt, a retry returns the original, a reused key with a different payload is a conflict, a reused key from another sender never returns their row. **AUD-CTRL/F-H8** the UI only ever creates `selfManaged` settlements — the `pending` → recipient-confirms flow is **unreachable from the UI**, so a member can neither request a transfer from somebody else nor confirm one. **AUD-DAT-08** the idempotency key embeds `DateTime.now().microsecondsSinceEpoch`, so a double tap creates two settlements rather than replaying one |
| **Unverified** | Concurrent settlements — untestable in Dart |

### J9 — Handle duplicate requests, retries and failed operations

| Aspect | Detail |
|---|---|
| **Status** | **Static inspection only** (partial test coverage of the settlement case) |
| **Code paths** | All repositories; `RepositoryException` codes `validation` / `unauthorized` / `notFound` / `conflict` / `forbidden`; `lib/core/widgets/app_toast.dart` |
| **Actual behaviour** | Repositories validate before mutating, so a thrown exception generally leaves state unchanged (**AUD-DAT-07**, a sound pattern). `ExpenseRepository.update` and `CribRepository.update` use optimistic version checks and raise `conflict` on a stale version. `SettlementRepository.create` is idempotent for the same sender + crib + key + payload |
| **Defects** | **AUD-DAT-08** expense creation has **no** idempotency key (id = `e${DateTime.now().millisecondsSinceEpoch}`), member add has none, invitation create has none. Most submit paths are **not debounced** (only `SignInScreen` has a `_busy` guard). A double tap can create two expenses. The settlement key is timestamp-derived, so a **network retry** (not a same-millisecond replay) would create a second settlement |
| **Unverified** | Real network retry semantics — there is no network layer |

### J10 — Record activity and inspect historical records

| Aspect | Detail |
|---|---|
| **Status** | **Passed by execution** (emission) / **Static inspection only** (display) |
| **Code paths** | `lib/features/activity/activity_screen.dart`; `in_memory_repositories.dart:569-590` (`ActivityRepository`), `:892-914` (`_recordActivity`); `lib/data/models.dart:392-413` (`ActivityEvent`) |
| **Executed evidence** | `test/activity_test.dart` (8 tests): activity emission for every mutation (crib created/updated/deleted, member added/removed, invitation created/accepted/revoked, expense created/updated/deleted, settlement created/confirmed/cancelled, recurring created/cancelled/generated), actor + target + crib id, newest-first ordering |
| **Actual behaviour** | `_recordActivity` sets `time: now.toIso8601String()` and `occurredAt: now`. `ActivityScreen` reads `cachedEvents`, filters by crib **name**, and renders `event.time` raw |
| **Defects** | **AUD-DAT-04** the feed displays a raw ISO-8601 string, and the "All" filter returns **every event in the store** — including events from cribs the user is not a member of. **AUD-DAT-06** the recorded actor id is the client-owned `'me'`. **AUD-TST-06** `activity_test.dart:36` asserts only `expect(event.occurredAt, isNotNull)`, which is trivially true because `occurredAt` defaults to `DateTime.now()` |
| **Unverified** | Relative-time rendering (there is none) |

### J11 — Create, edit, pause and generate recurring expenses

| Aspect | Detail |
|---|---|
| **Status** | **Passed by execution** (generation rules) / **Static inspection only** (edit & pause) |
| **Code paths** | `lib/features/cribs/crib_detail_screen.dart` (`_maybeGenerateRecurring` in `initState`); `lib/domain/recurring_scheduler.dart`; `in_memory_repositories.dart:640-720` |
| **Executed evidence** | `test/recurring_test.dart` (**17 tests** — the best-covered area of the product): month-end and leap-day anchor rules, local-hour retention, the occurrence key, timezone offsets, DST, the fixed-offset zone, an unknown zone, due→exactly one expense, generation idempotency, catch-up of missed runs, not-due, cancel, owner-only create, non-member catch-up denial |
| **Actual behaviour** | Generation is on demand — `CribDetailScreen.initState` calls `recurring.generateDue()`. Occurrences are idempotent per `(scheduleId, dueDate)` and the generated expense id is derived from that key. Cancelling stops future occurrences only; generated expenses stay. The zone is an explicit IANA id or a fixed offset, with the **device offset** used at creation time |
| **Defects** | **AUD-FIN-04** `generateDue` always sets `payerId: schedule.createdById`, so a recurring schedule keeps charging a **removed** creator; and any active member can trigger generation. **AUD-CTRL-05** there is **no "edit" and no "pause"** — only "cancel", although `PRODUCT_RULES.md` §5 defines an `active` state. **AUD-FIN-05** `nextDueDateAfter` is O(n) ≤ 5000. **AUD-FIN-10** the device zone is stored as a fixed offset, so DST is not followed for the device zone |
| **Unverified** | Behaviour while the app is closed — the product explicitly claims nothing is generated then |

### J12 — Remove or leave a batch, archive it, handle owner departure

| Aspect | Detail |
|---|---|
| **Status** | **Passed by execution** (remove member) / **Not tested** (leave, archive, owner departure) / **Static inspection only** (delete) |
| **Code paths** | `in_memory_repositories.dart:196-260`; `lib/features/cribs/crib_edit_sheet.dart` |
| **Executed evidence** | `test/membership_test.dart` (12 tests): owner-only add/remove, duplicate add, soft removal keeps history, the ledger still validates a removed member's expenses, a removed member cannot create, the owner is unremovable, double removal, unknown member, membership is immutable via `update`, re-add. `test/crib_operations_test.dart`: owner-only delete, stale-version delete, not-found |
| **Actual behaviour** | `removeMember` is owner-only, cannot remove the owner, and performs a **soft removal** (`isActive == false`, `leftAt` set) so history stays reconstructable. The owner cannot be removed and there is no ownership transfer (per `PRODUCT_RULES.md` §1, v1 scope). `delete` is owner-only with a version check, removes the crib, and **preserves** `expenses` and `settlements` |
| **Defects** | **AUD-SEC-03 / AUD-DAT-02** delete hard-deletes the crib and **orphans** its expenses, settlements and membership rows; there is **no guard** against deleting a crib with `confirmed`/`selfManaged` settlements, and no tombstone. **AUD-CTRL-04** no UI affordance for delete-crib was found, although the repository supports it |
| **Not applicable / not implemented** | **Leave a crib** — no functionality exists for a non-owner to leave. **Archive** — no archived flag exists anywhere in the models. **Owner departure** — impossible by design in v1 (`PRODUCT_RULES.md` §1); `PRODUCT_RULES.md` §7 requires an ownership-transfer-or-tombstone decision for account deletion, which is not implemented |
| **Unverified** | — |

### J13 — Handle empty batches, one-member batches, removed members, unavailable data

| Aspect | Detail |
|---|---|
| **Status** | **Static inspection only** |
| **Code paths** | `in_memory_repositories.dart`; `lib/features/expenses/expense_detail_screen.dart` ("This crib is not available any more"); `lib/data/member_directory.dart` |
| **Actual behaviour** | The owner is always added at creation, so a crib has ≥ 1 member. `create` adds any non-actor members supplied by the caller. One-member cribs are permitted and the balance/split code path handles them. Repositories throw `notFound` for a missing crib/expense; the UI surfaces these as toasts. `MemberDirectory` lookups may return `null` |
| **Defects** | **AUD-FIN-08** member counts include removed members in `split_share_editor.dart:179` and `crib_detail_screen.dart:216` (the `CribEditSheet` uses the active count — inconsistent). **AUD-DAT-05** a removed member's row stays in the member list, so "one member" is ambiguous between active and total counts |
| **Unverified** | — |

### J14 — Navigate away and return; restart the app and inspect state restoration

| Aspect | Detail |
|---|---|
| **Status** | **Not tested** (restart) / **Static inspection only** (navigation) |
| **Code paths** | `lib/features/shell/main_shell.dart` (`IndexedStack`), `lib/app/paycal_app.dart`, `lib/main.dart`, `lib/core/settings/app_settings.dart`, `lib/features/onboarding/onboarding_draft.dart` |
| **Actual behaviour** | `MainShell` keeps the four tabs mounted in an `IndexedStack`, so a tab can show **stale** data after a mutation performed in a pushed route until it is rebuilt. `PayCalRepositories.instance` holds a single in-memory store; a fresh process re-seeds from `MockData` — **all financial data is lost on restart**. Only `OnboardingDraft` (SharedPreferences) and some `AppSettings` values persist. There is no session restore |
| **Defects** | **AUD-DAT-01** (Critical) no durable persistence. **AUD-DAT-05** no reactive invalidation across tabs. **AUD-SEC-02** no session restoration |
| **Unverified** | Everything — there is no persistence layer to verify |

### J15 — Handle invalid input, offline/network failure, repeated taps, stale screens

| Aspect | Detail |
|---|---|
| **Status** | **Static inspection only** |
| **Code paths** | `lib/core/utils/validators.dart`; repository exceptions; `lib/core/widgets/app_toast.dart`; `lib/features/settlements/settle_up_sheet.dart`; `lib/features/expenses/quick_add_sheet.dart` |
| **Actual behaviour** | Form validation exists in `SignInScreen` (`Validators.email` / `password`), `FirstCribScreen` and `SplitShareEditor`. Repository errors are surfaced as toasts. **There is no network layer, so "offline" has no meaning today** and no offline handling exists. Version conflicts prevent silent overwrites |
| **Defects** | **AUD-DAT-08** repeated taps are not debounced outside `SignInScreen`; expense create has no idempotency key. **AUD-CTRL-01** "Forgot password" has no handler |
| **Unverified** | All real network failure modes, including the retry/idempotency semantics a backend would require |

---

## 2. Execution-status roll-up

| Status | Journeys |
|---|---|
| Passed by execution | J1 (partial), J3, J4, J6, J7 (partial), J8 (partial), J10 (partial), J11 (partial), J12 (partial) |
| Failed by execution | none in the current working tree — **but the golden probe fails on a clean `HEAD` checkout** (0.53%, 2546 px) |
| Static inspection only | J2, J5 (UI), J8 (UI), J9, J11 (edit/pause), J13, J14 (navigation), J15 |
| Not tested | J14 (restart/state restoration) — no persistence exists to test |
| Not applicable | J12 leave-crib, archive, owner departure — no such features exist (reason given per row) |

**No journey was executed as a real end-to-end user journey.** Every "passed"
row is a widget or unit test that exercises a repository or a widget in
isolation, inside a single process, with a single in-memory store.

> **After the pre-Supabase fixes of 2026-10-20.** The 63 new tests raised the
> confidence in **J3, J4, J6, J8, J10 and J13** — the rules behind them are
> now proven against the wrong implementation. **J2, J14 and J15 are
> unchanged**, because they need a real identity, a durable store and a
> network that do not exist yet. **No journey moved to a higher status
> category**, because the status of a journey is decided by what was
> executed, and no new *journey* was executed.

---

## 3. Coverage gaps with no test at all

> **Update 2026-10-20.** The first, the third and the fourth row below are
> **closed** by the pre-Supabase fixes: `test/money_test.dart` (11 tests),
> `test/settlement_pairwise_debt_test.dart` (12 tests) and
> `test/repository_isolation_test.dart` (17 tests). The rows that remain are
> still open.

| Area | Why it matters |
|---|---|
| ~~Cross-crib / cross-member read scoping~~ | **Closed on the client** by `test/repository_isolation_test.dart`. The database half still needs the RLS suite of `SUPABASE_MIGRATION_PLAN.md` §6 M3 |
| Authentication / identity | A client can claim any identity |
| ~~`lib/core/utils/money.dart`~~ | **Closed** by `test/money_test.dart` |
| ~~Per-pair settlement debt~~ | **Closed** by `test/settlement_pairwise_debt_test.dart` and `test/financial_ledger_test.dart` |
| Cross-sender idempotency / same key with a different payload | **Closed** by `test/settlement_pairwise_debt_test.dart` |
| ~~Removed member as a **share participant**~~ | **Closed** by `test/active_member_enforcement_test.dart` (domain level and repository level) |
| `Crib.ownerId == null` fallback | The first-admin fallback path is never exercised — `testCrib` always sets `ownerId: 'me'` |
| Activity timestamp semantics | Only `isNotNull` is asserted, which is trivially true |
| Metadata-only expense edit after a settlement | **Closed** — it needed a real fix (the share comparison compared map objects instead of their content) and is covered by `test/active_member_enforcement_test.dart` |
| Invitation `getById` authorisation | `getById` needs a signed-in user now, but a token holder can still read the metadata of a token they hold |
| Money formatting | **Closed** by `test/money_test.dart` |
| Custom / percentage split **UI** | Only the math is tested |
| Owner departure / leave / archive | No features exist |
| Real notifications | The permission flow is never invoked |
| Concurrency | Impossible in a single-process in-memory store |

---

## 4. Platform / device behaviour that remains unverified

No simulator or device was available in the audit environment, so the following
were **read but never run**:

* Deep-link delivery from a real browser, SMS, or another app (only the
  in-process `DeepLinks.handle` path is tested)
* The platform share sheet and the actual text it receives
* The notification permission request, the permission result, and whether any
  notification is ever scheduled
* Keyboard appearance, focus order, and obscuring of the amount field
* Safe-area handling, small-screen and large-text layouts, and orientation change
* Scroll and overflow behaviour in the long member/share lists
* The `ConfettiBurst` / `WedgeLoader` / `PartyTap` animation performance
* Platform channel failures for `SharedPreferences`
* Process death and app backgrounding, and whether the onboarding draft survives it
* Real share of an invitation link to a third-party app
* Any behaviour that differs on iOS vs Android (there is no platform-specific
  code in the audited paths, but this was not exercised)

---

## 5. What is required to turn "Static inspection only" into "Passed by execution"

1. **A real authentication implementation and a session gate** (J2, and the
   precondition for every identity-dependent row).
2. **A second, independent user context** so cross-crib reads can be attempted
   from the wrong account — the only way to prove or disprove the Critical
   exposure path.
3. **A shared durable store** so J14 (restart) can be executed and so J3/J4 can
   be verified across users.
4. **A device/simulator run** of J1, J5, J8, J10, J13, J15 — the six journeys
   whose UI paths have no executed coverage.
5. **A contract suite parameterised over the in-memory and Supabase
   implementations**, as proposed in `SUPABASE_MIGRATION_PLAN.md` §5 — this is
   the mechanism that keeps the two implementations honest, and it is what
   would have caught AUD-SEC-01, AUD-FIN-02 and AUD-FIN-03.
6. **The eight missing assertions** listed in `docs/RELEASE_READINESS_CHECKLIST.md` §4.
