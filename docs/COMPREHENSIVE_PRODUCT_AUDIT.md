# PayCal Comprehensive Product Audit

**Date:** 2026-10-20
**Scope:** Full read-only audit of the PayCal Flutter shared-expense application.
**Method:** Multi-agent specialist audit (financial correctness, security/privacy, end-to-end journeys, data integrity/recurring/invitations, independent QA) plus lead-agent review of all documentation and source.
**Code state audited:** `HEAD 41b1213` with 56 dirty paths (uncommitted work-in-progress preserved; **nothing was modified by this audit**).

---

## 0. Executive summary

PayCal is a well-structured **prototype**, not a working product. The domain layer
(financial ledger, recurring scheduler, invitation rules) is genuinely solid and
correctly designed. The **application shell is a mock**: there is no authentication,
no persistence, and no authorization boundary. The application cannot complete a
single financial workflow in a way that a user could rely on.

**The single most important correction to the prior milestone report:** the
verification note in `docs/MILESTONE_1_VERIFICATION.md` states *"110 passed, 1
failed (`golden_probe` dialog pixel mismatch)"* and that the golden failure is
"intentional UI drift". Independent QA execution contradicts this on two points:

1. **The suite currently passes 112/112 with 0 failures.** The golden baseline was
   re-baselined **uncommitted** ~26 minutes before the audit began, which masks
   the failure locally. On a clean checkout of `HEAD` the golden test **fails**
   with a verified `0.53% / 2546px` mismatch. The "1 failed" state is real but
   historical; the current working tree passes only because of a local
   overwrite.
2. The `0.53%` mismatch is **one line of text** — the rename
   `'Your first batch is ready to roll.'` → `'Your first crib is ready to roll.'`
   at `lib/features/onboarding/invite_screen.dart:140`. It is not a
   "pixel" mystery. An earlier `44.98%` mismatch (a global card tint from the
   theme change in `8a83032`) was the real regression that got masked.

**Verdict per area:**

| # | Area | Judgment |
|---|---|---|
| 1 | Domain / financial correctness | **Ready with explicitly listed limitations** |
| 2 | UI & user-flow completeness | **Not ready** |
| 3 | Authentication & access control | **Not ready** |
| 4 | Data persistence & cross-user consistency | **Not ready** |
| 5 | Supabase integration readiness | **Not ready** |
| 6 | Production release readiness | **Not ready** |

**Residual uncertainty:** no simulator/device execution was performed in this
audit. All "passed" journeys are *widget/unit* passes, not real device runs.
Multi-user, multi-device, restart-persistence, concurrency, and true
end-to-end (real network) behaviour are **unverified** — see
`docs/END_TO_END_TEST_MATRIX.md`.

---

## 0.1 Status after the pre-Supabase fixes (2026-10-20)

The findings below are the result of the audit. A later milestone fixed the
ones that could be fixed without a backend and without a product decision.
**This document is kept as the point-in-time record of the audit; the status
of every finding is in `docs/MILESTONE_2_VERIFICATION.md` and
`docs/PRODUCT_FINDINGS.md`.**

| Finding | Severity | Status | Closed by |
|---|---|---|---|
| `AUD-FIN-01` | Medium | **Closed** | `Money.tryParseToMinor('-0.50')` → `-50`, overflow rejected, exact integer formatting. `test/money_test.dart` |
| `AUD-FIN-02` | High | **Closed (client)** | A settlement is validated against the debt of the **pair**, not the net position. `FinancialLedger.pairwiseDebt`. `test/settlement_pairwise_debt_test.dart` |
| `AUD-FIN-03` | High | **Closed** | `validateNewExpense` / `validateNewSettlement` require active members; the record-level rules keep the history valid. `test/active_member_enforcement_test.dart` |
| `AUD-SEC-01` | Critical | **Closed (client only)** | Every repository read is scoped to the memberships of the signed-in member. `test/repository_isolation_test.dart`. **The RLS policies are still required** — the client is not a boundary |
| `AUD-TST-04` | High | **Closed** | The share comparison compared map objects instead of their content, so every edit counted as a financial change. `FinancialLedger.sameShares` |
| `AUD-TST-05` | High | **Closed (client only)** | The tests that asserted the unscoped behaviour now assert the scoped behaviour |
| `AUD-TST-01` | High | **Closed (2B)** | The rename was verified in a scratch copy: with the old word restored, the current code renders pixel-identical to the approved baseline. Only `test/goldens/all_set_dialog.png` was regenerated, and the result is byte-identical to the previously preserved baseline |
| `AUD-CTRL-04` | Medium | **Closed (2B)** | The delete-crib affordance does exist in `lib/features/cribs/crib_edit_sheet.dart` — the earlier audit statement "no delete-crib affordance found" was wrong. The editor is now owner-only |
| `AUD-FIN-04` | Medium | **Closed (2B)** | A recurring schedule now has an explicit payer. When the payer leaves, the schedule pauses and generates nothing until the owner assigns an active member. `test/recurring_pause_test.dart` |
| `AUD-CTRL-01/02/03` | Medium | **Open** | "Forgot password", the notifications toggle and "Join with a link" are still inert. They need real authentication and a real notification permission |
| `AUD-SEC-01` (backend half) | Critical | **Open** | The RLS policies and the RPC authorisation checks are still the real boundary, and they are untestable without a database |
| `AUD-SEC-03`, `AUD-SEC-02`, `AUD-SEC-04`, `AUD-DAT-01` | Critical/High | **Open** | Need the backend, the schema, or a product decision |

**Milestone 2B added** the Crib Owner permission audit
(`docs/ADMIN_ROLE_AND_PERMISSION_AUDIT.md`), the recurring payer with a
paused state, the owner-only interface of the Crib editor and the Crib
detail screen, the verified golden baseline, and the twelve product flows
covered end to end at the repository level. The suite grew from 175 to **234
tests, all passing**.

**The verdict of this audit is unchanged:** the domain is sound, the
application shell is still a mock, and the product is not ready. Closing the
money rules, the owner permissions and the client-side scoping moved the
project one step closer to a safe Supabase integration, not one step closer
to production.

**One structural fact that outranks every finding above:** the entire current
architecture is **uncommitted**. `lib/data/in_memory_repositories.dart`,
`lib/data/repositories.dart`, `lib/domain/financial_ledger.dart` and every
test file of the current architecture do not exist in `HEAD`. A CI job that
checks out `HEAD` compiles and tests the *previous* app — 8 tests, not the 175
of the current tree. See `docs/MILESTONE_2_VERIFICATION.md` §4.

---

## 1. Verification results (executed, not asserted)

| Command | Result | Evidence |
|---|---|---|
| `flutter analyze` | **No issues found!** (exit 0, 2.7s) | Zero errors/warnings/infos with `analysis_options.yaml` active. |
| `flutter test` | **112 passed, 0 failed, 0 skipped** (exit 0) | JSON reporter: 126 `testStart` records, every one `result: "success"`, `errors: []`, `done: {success: true}`. 126 = 112 visible + 14 `loading <file>` pseudo-tests. |
| `flutter test` on clean `HEAD` checkout | **1 failed** — golden probe, `0.53%, 2546px` | Reproduced in an isolated copy; the repo working tree was not touched. |

**Test-file distribution (JSON reporter + `--concurrency=1`, both agree):**

| File | Tests | File | Tests |
|---|---|---|---|
| `recurring_test.dart` | 17 | `membership_test.dart` | 12 |
| `settlements_test.dart` | 11 | `ui_flows_test.dart` | 7 |
| `expense_permissions_test.dart` | 11 | `in_memory_repositories_test.dart` | 6 |
| `invitations_test.dart` | 11 | `onboarding_smoke_test.dart` | 5 |
| `crib_operations_test.dart` | 11 | `widget_test.dart` | 2 |
| `activity_test.dart` | 8 | `repro_email_path_test.dart` | 1 (**asserts nothing**) |
| `financial_ledger_test.dart` | 9 | `golden_probe_test.dart` | 1 |

> **Reporter caveat:** the default compact reporter under concurrency printed
> only 7 of 14 files across two runs, making the suite look half-missing. Do
> not trust piped compact output for coverage accounting. Use
> `--reporter json` or `--concurrency=1`.

---

## 2. The golden probe: what the evidence actually shows

**Test:** `test/golden_probe_test.dart:6` — one test, `dialog probe`. Pumps
`InviteScreen`, taps `Skip for now` (→ `showDialog`), then
`matchesGoldenFile('goldens/all_set_dialog.png')` on `find.text('You are all set!')`.

**Baseline:** `test/goldens/all_set_dialog.png`, 800×600.

| | bytes | sha256 (prefix) |
|---|---|---|
| `HEAD` (`a945dd9`) | 12,373 | `8a1a9fef…` |
| working tree | 12,372 | `4637d75e…` |

**The capture is not the full screen.** It is the dialog's overlay layer only:
190,237 px fully transparent, opaque content bbox `(20,115)-(779,496)` = the card.
The underlying `InviteScreen` is **not** in the golden — so the invite-link text
change in the same file is not covered by it.

**Two distinct historical mismatch states, both measured independently:**

| Baseline vs render | Differing px | Percentage | Max channel delta | Diff bbox |
|---|---|---|---|---|
| `HEAD` golden vs `HEAD` failing render (committed `8a83032`) | 215,900 / 480,000 | **44.9792 %** | 10 | (22,117)-(777,482) |
| `HEAD` golden vs current working-tree golden | 2,546 / 480,000 | **0.5304 %** | 152 | (98,347)-(701,362) |

* The **44.98 %** diff was a **global tint**: card background at (400,200) is
  `(255,255,255)` in the `HEAD` golden vs `(247,247,245)` in the failing render.
  Cause: the theme change in commit `8a83032` (`lib/core/theme/app_colors.dart`).
  A ≤10/255 delta across the whole card flipped 215,900 px.
* The **0.53 %** diff is **one line of text**: a 15-px-tall band. Row ink profile
  `HEAD` 520–648 px/row vs working tree 506–634 px/row → the word got shorter.
  This is the rename `'Your first batch is ready to roll.'` →
  `'Your first crib is ready to roll.'` at
  `lib/features/onboarding/invite_screen.dart:140`.

**Proof of reproduction** (isolated copy, repo untouched) — restoring the `HEAD`
baseline and running only the golden test:

```
Golden "goldens/all_set_dialog.png": Pixel test failed, 0.53%, 2546px diff detected.
00:00 +0 -1: dialog probe [E]
00:00 +0 -1: Some tests failed.
```

This matches the independent pixel analysis **exactly** (0.53 %, 2546 px).

### Is it pre-existing? — No. It is a *stale baseline masked by an uncommitted overwrite*.

Evidence chain:

1. `sha(HEAD:test/goldens/all_set_dialog.png) == sha(HEAD:test/failures/all_set_dialog_masterImage.png)`
   = `8a1a9fef…` → the committed baseline **is** the master image of the committed
   failing run. The baseline was valid at `a945dd9`.
2. `sha(WT:test/goldens/all_set_dialog.png) == sha(WT:test/failures/all_set_dialog_testImage.png)`
   = `4637d75e…` → the current baseline **is the last failing render**, i.e. it
   was overwritten with `--update-goldens`.
3. mtimes: `test/failures/*.png` = `2026-10-20 14:54:45`,
   `test/goldens/all_set_dialog.png` = `2026-10-20 14:54:52` — a failing run
   followed 7 s later by a baseline overwrite, ~26 minutes before this session.
4. `git status` shows **`M test/goldens/all_set_dialog.png`** — the re-baseline
   is **uncommitted**. A CI checkout of `HEAD` **fails**; the working tree passes.

**Conclusion:** the baseline was never reviewed, it was overwritten. The
`MILESTONE_1_VERIFICATION.md` characterisation ("intentional UI drift, not a
baseline regression, requires golden regeneration approval") is **not supported**
— regeneration already happened, unapproved and uncommitted.

**Two further hygiene defects:**
* `test/failures/*.png` are **tracked in git** (`8a83032`) and `.gitignore` does
  not exclude them — failure artifacts are committed.
* The golden is a **weak oracle**: it asserts a single `Text` finder inside a
  card-only layer capture, and the test file carries dead `print` diagnostics.
  Its own probe printed `dialogs: 0` because `showDialog` here builds a
  `Center(Container(...))`, not a `Dialog` widget — the diagnostic is misleading.

**Per the audit rules, the golden baseline was NOT regenerated. The working tree
was left exactly as found.**

---

## 3. Workstream A — Full feature inventory

Status legend: **V** = verified by execution · **D** = defective · **P** = partial
· **U** = unimplemented · **UV** = unverified.

### 3.1 Screens, routes, modals and sheets (27 entries)

| # | Screen / sheet | File | Entry point | Role | Status | Notes |
|---|---|---|---|---|---|---|
| 1 | `SplashScreen` | `lib/app/splash_screen.dart` | App launch | any | **V** | Auto-navigates after 900 ms; no interactive control. |
| 2 | `WelcomeScreen` | `lib/features/onboarding/welcome_screen.dart` | splash / logout | any | **V** | "Get started" → tour; "Sign in" → sign-in. |
| 3 | `ProductTourScreen` | `lib/features/onboarding/product_tour_screen.dart` | welcome | any | **V** | 3-slide `PageView`, skip/next. |
| 4 | `OnboardingFlow` | `lib/features/onboarding/onboarding_flow.dart` | tour | any | **V** | 5 steps; gender, birthday, role, categories, household size. Persists via `OnboardingDraft` (SharedPreferences). |
| 5 | `BirthdaySheet` | `lib/features/onboarding/birthday_sheet.dart` | onboarding | any | **V** | `showDatePicker`. |
| 6 | `CreateAccountScreen` | `lib/features/auth/create_account_screen.dart` | onboarding | any | **D** | Both buttons wait 450 ms then navigate with hard-coded `email: 'you@gmail.com'`, `google: true`. |
| 7 | `VerifyEmailScreen` | `lib/features/auth/verify_email_screen.dart` | create account | any | **D** | Simulated polling; `google==true` auto-advances. No email is ever sent. |
| 8 | `NotificationsPage` | `lib/features/auth/notifications_sheet.dart` | verify | any | **V** | "Turn on notifications" / "Not not" both advance. **No permission request, no notification ever scheduled.** |
| 9 | `FirstCribScreen` | `lib/features/onboarding/first_crib_screen.dart` | notifications | any | **D** | Creates **placeholder members** `ob1…obN` / "Housemate N" (F-H4). "Join with a link" only shows a toast. |
| 10 | `InviteScreen` | `lib/features/onboarding/invite_screen.dart` | first crib | owner | **V** | Real opaque invitation token + link. Golden-probe target. |
| 11 | `MainShell` | `lib/features/shell/main_shell.dart` | after auth | any | **V** | `IndexedStack` + 4-tab bottom nav. |
| 12 | `HomeScreen` | `lib/features/home/home_screen.dart` | shell | any | **D** | Reads `cachedCribs` unfiltered; member count includes removed members. |
| 13 | `CribsScreen` | `lib/features/cribs/cribs_screen.dart` | shell | any | **D** | Same unscoped read + removed-member count. |
| 14 | `CribDetailScreen` | `lib/features/cribs/crib_detail_screen.dart` | cribs/home | member | **D** | Calls `recurring.generateDue()` in `initState`; no explicit recurring **edit** or **pause** UI. |
| 15 | `CribEditSheet` | `lib/features/cribs/crib_edit_sheet.dart` | long-press crib | owner | **P** | Name/currency/member management/invites. **No delete-crib affordance found** although the repo supports it. |
| 16 | `CreateCribPopup` | `lib/features/cribs/create_crib_popup.dart` | home | any | **V** | Name + currency dropdown → `CribRepository.create`. |
| 17 | `QuickAddSheet` | `lib/features/expenses/quick_add_sheet.dart` | home/crib | member | **D** | Amount input shows the **device** currency symbol, not the crib currency (F-M2). |
| 18 | `SplitShareEditor` | `lib/features/expenses/split_share_editor.dart` | quick add / edit | member | **P** | Equal/Exact/%; controllers are built lazily and are **not rebuilt** when the member list changes (F-L3). Member count includes removed members. |
| 19 | `ExpenseDetailScreen` | `lib/features/expenses/expense_detail_screen.dart` | home/crib | member | **V** | Edit/Delete gated by `_canManage`; dispute available to all active members. |
| 20 | `SettleUpSheet` | `lib/features/settlements/settle_up_sheet.dart` | crib | member | **D** | Only creates `selfManaged` settlements — the recipient-confirm flow is unreachable (F-H8). |
| 21 | `SettleSheet` | `lib/features/settlements/settle_sheet.dart` | — | — | **U** | **Dead code.** No callers. Shows a toast instead of recording. |
| 22 | `ScanFlow` | `lib/features/scans/scan_flow.dart` | home | member | **V** | QR → `CribRepository.addMember` (owner-only enforced). |
| 23 | `ActivityScreen` | `lib/features/activity/activity_screen.dart` | shell | any | **D** | "All" filter returns **every** event in the store (F-M5); renders raw ISO timestamp (F-L2). |
| 24 | `SearchScreen` | `lib/features/search/search_screen.dart` | home | any | **D** | Searches unscoped `cachedCribs`; prints member count for cribs the user is not in. |
| 25 | `ProfileScreen` | `lib/features/profile/profile_screen.dart` | shell | any | **D** | "Log out" never calls `signOut()` (F-L6); "Delete account" is toast-only (F-L7). |
| 26 | `DesignGallery` | `lib/design_gallery.dart` | — | — | **V** | Dev-only component gallery. |
| 27 | `BalanceEngine` | `lib/domain/balance_engine.dart` | — | — | **P** | Legacy adapter duplicating the money API; only `widget_test.dart` calls it. |

### 3.2 Domain services and repositories

| Component | File | Status | Key evidence |
|---|---|---|---|
| `Money` | `lib/core/utils/money.dart` | **D** | `tryParseToMinor('-0.50')` → **+50** (F-M1). `format` divides by 100.0 into a double (F-M3). |
| `FinancialLedger` | `lib/domain/financial_ledger.dart` | **P** | Splits, balances, transfers correct. But `validateExpense` checks `crib.members` while `validateSettlement` checks `crib.activeMembers` — **internal inconsistency** (F-H6). |
| `RecurringScheduler` | `lib/domain/recurring_scheduler.dart` | **V/P** | Month-end, leap-day, DST rules correct and tested (17 tests). `nextDueDateAfter` is O(n) ≤5000 (F-M11). |
| `AuthRepository` | `lib/data/in_memory_repositories.dart:96-123` | **D** | `signIn` does not authenticate; id is `_store.currentUser?.id ?? 'me'`. |
| `CribRepository` | `…:129-260` | **P/D** | Owner-only ops enforced. `list()`/`getById()` unscoped (F-C1). `ownerId` nullable with first-admin fallback (F-M10). `delete` hard-deletes the crib (orphans expenses/settlements) and has **no guard against confirmed settlements**. |
| `ExpenseRepository` | `…:286-440` | **P** | Creator/payer permissions, version conflicts, dispute path, immutable payer/currency all correct. Rejects removed members as participants (F-H6 fixed at repo layer). |
| `SettlementRepository` | `…:447-563` | **D** | Overpayment uses **net** balance, not per-pair debt (F-H2). Idempotency now sender-scoped + payload-checked (F-H3 fixed). No lock (F-H7). |
| `ActivityRepository` | `…:569-590` | **P** | `record()` requires only a signed-in user; `list()`/`cachedEvents` unscoped (F-C1/F-M5). `time` is an ISO string in the domain (F-L2). |
| `InvitationRepository` | `…:730-850` | **P** | Token generation, expiry, revocation, single-use, acceptance chain all correct. `getById(token)` has **no auth check** → metadata leak (F-L4). Tokens stored plaintext. |
| `RecurringPaymentRepository` | `…:640-720` | **D** | `generateDue` always pays `schedule.createdById` even if removed (F-M7); any active member triggers generation. |

### 3.3 Control-level observations (not all listed — full list in `docs/END_TO_END_TEST_MATRIX.md`)

Every visible interactive control in the 27 surfaces was enumerated. Notable
control-level defects:

* **"Forgot password" on `SignInScreen`** — no handler at all. Dead control.
* **"Turn on notifications"** — no permission prompt, no notification ever
  scheduled. The user is told something happens that does not.
* **"Join with a link"** in `FirstCribScreen` — only shows a toast; no token
  entry path, so a user who was invited but skipped onboarding cannot join.
* **Delete-crib** — repository method exists and is owner-guarded, but **no UI
  affordance** was found in `CribEditSheet` or `CribDetailScreen`. Either the
  capability is unreachable or the audit's static read missed it; both are
  product-level problems (a half-implemented destructive action).
* **Recurring "pause" and "edit"** — only "cancel" exists. `PRODUCT_RULES.md` §5
  describes `active` state, so a "pause" is a product concept the UI never
  offers.

---

## 4. Workstream B — End-to-end user journeys (summary)

Full matrix with per-journey status, code paths and evidence:
**`docs/END_TO_END_TEST_MATRIX.md`**.

Headline: of 15 journeys, **0 are "Passed by execution" in a real end-to-end
sense**. 5 are covered by widget/unit tests that exercise repository and widget
layers but not the full journey; 10 are **static inspection only**. The two
journeys most likely to reveal production failures — *session restoration* and
*multi-user consistency* — have **no coverage at all**, because the
architecture cannot support them yet (single in-memory store, no persistence).

---

## 5. Workstream C — Financial invariants

### 5.1 What is provably correct (verified by execution)

| Invariant | Evidence |
|---|---|
| Integer minor-unit arithmetic in the ledger | `lib/domain/financial_ledger.dart`; `test/financial_ledger_test.dart` (9 tests) |
| Equal-split deterministic remainder to the payer first | `FinancialLedger.equalSplit`; `financial_ledger_test.dart` "equal split remainder" |
| Percentage split exactness, basis points must total 10 000 | `FinancialLedger.percentageSplit`; `financial_ledger_test.dart` |
| Duplicate participant / sum ≠ total / currency mismatch rejected | `financial_ledger_test.dart`; `expense_permissions_test.dart` |
| `pending`/`cancelled` settlements do not affect balances; `confirmed`/`self_managed` do | `financial_ledger_test.dart` "confirmed vs pending settlement effect" |
| Expense shares are an immutable copy | `financial_ledger_test.dart` "immutable share copy" |
| Suggested transfers recalculated after every ledger change | `FinancialLedger.suggestedTransfers`; `settlements_test.dart` |
| Settlements never alter tracked spending | `settlements_test.dart` "settlement ≠ spending" |
| Payer cannot be changed; currency cannot be changed | `expense_permissions_test.dart` "immutable payer+currency" |
| Crib currency cannot change once financial activity exists | `crib_operations_test.dart` |
| Occurrence idempotency per (schedule, due date) | `test/recurring_test.dart` (17 tests) |
| Month-end / leap-day / DST / unknown-zone / fixed-offset rules | `test/recurring_test.dart` |
| Removed member's **historical** expenses stay valid | `membership_test.dart` "the ledger still validates expenses of a removed member" |
| Settlement is sender-only to create, recipient-only to confirm, sender-only to cancel | `settlements_test.dart` |
| Confirmed/self-managed settlement cannot be overwritten | `settlements_test.dart` "confirmed immutable" |
| Payer/creator-only expense edit and delete; any member may dispute | `expense_permissions_test.dart`; `ui_flows_test.dart` |
| Idempotency key replay returns the original settlement (same sender) | `settlements_test.dart` "the idempotency key replays the same settlement" |

### 5.2 Confirmed defects

**AUD-FIN-01 — `Money.tryParseToMinor('-0.50')` returns `+50`. (Medium, confirmed)**

`lib/core/utils/money.dart:48-49`. `whole = int.tryParse('-0')` → `0`, so the sign
is taken as positive, then the fraction is added as `+50`. Runtime:
`"-0.50" => 50`, `"-0.5" => 50`, `"-1.50" => -150` (correct), `"-0.00" => 0`.
A negative sub-unit amount becomes a **positive expense**.
The uncommitted refactor in the working tree (`sign = whole < 0 ? -1 : 1`) is a
**no-op** — it produces the same `+50`. The bug is live.
**Impact:** any amount field that accepts a leading `-` and a sub-unit value
silently records income instead of a charge.
**Coverage:** **zero** tests exist for `lib/core/utils/money.dart` anywhere.
**Blocks:** Supabase — no; beta — yes if negative amounts are reachable; production — yes.

**AUD-FIN-02 — Settlement overpayment uses net balance, not per-pair debt. (High, confirmed)**

`lib/data/in_memory_repositories.dart:504-518` computes
`FinancialLedger.balances(...)` (net) and rejects when
`(balances[from] ?? 0) + amount > 0`.
Runtime proof from QA: a debtor with net `-600` who owes `r` 600 and owes `me`
**0** successfully created a **600** settlement to `me` — a settlement of money
that was never owed, in the wrong direction, to the wrong party. Conversely, a
net creditor (`+500`) can create **no** settlement at all, even for 1 minor unit.
Neither behaviour is specified or tested.
`PRODUCT_RULES.md` §4 says the check is against "the sender's outstanding debt
**to the recipient**", and `SUPABASE_MIGRATION_PLAN.md` §3.5 designs a
`pairwise_debt()` function for exactly this. The rule as implemented contradicts
the approved rule and the planned schema.
**Existing coverage:** two tests in `settlements_test.dart` (`:75`, `:102`) — but
both are built on a two-member crib where net debt == pairwise debt, so they
**cannot distinguish the two rules**. The test at `:102` ("cannot overpay the
receiver") is actually rejected by the *sender-side* net check, not by any
receiver-side rule; the test name asserts a rule the code does not implement.
**Missing coverage:** the exact P3 scenario from the migration plan's M1
acceptance criteria has no test, even though it passes in code today.
**Blocks:** Supabase — yes (the RPC needs the per-pair function); beta — yes; production — yes.

**AUD-FIN-03 — `FinancialLedger.validateExpense` uses `crib.members`, `validateSettlement` uses `crib.activeMembers`. (High, confirmed)**

`lib/domain/financial_ledger.dart:93` (expense) vs `:134` (settlement).
The repository layer rejects a non-active participant
(`in_memory_repositories.dart:410-417`), so the *repository* is safe. The
*domain* rule — the one `balances()` depends on and the one that is supposed to
be the single source of money truth per `PRODUCT_RULES.md` §2 — accepts an
expense charging a removed member (`error = null` at runtime).
The guard therefore lives in exactly one of the two layers, and the layer
`PRODUCT_RULES.md` names as authoritative does not have it.
**Missing coverage:** `financial_ledger_test.dart` uses a crib whose members are
all active, so the `activeMembers` vs `members` distinction is never exercised.
**Blocks:** Supabase — yes (the SQL mirror would inherit whichever rule is
copied); beta — no; production — yes.

**AUD-FIN-04 — Recurring occurrences are paid by the schedule creator even after removal; any member can trigger generation. (Medium, confirmed)**

`in_memory_repositories.dart:685` sets `payerId: schedule.createdById`;
`generateDue` is callable by any active member (`:649`).
A removed creator leaves a recurring schedule that keeps charging a departed
member. The `PRODUCT_RULES.md` §5 approved rules do not decide the payer
policy, so this is a **missing rule** as much as a defect.
**Missing coverage:** none.

**AUD-FIN-05 — `nextDueDateAfter` is O(n) with a 5000-iteration guard. (Low, confirmed)**

`lib/domain/recurring_scheduler.dart` — walks up to 5000 occurrences from the
start date on every call. For an old schedule this is a measurable stall on
crib open. Performance-only.

**AUD-FIN-06 — `Money.format` divides by 100.0 into a double. (Low, confirmed)**

`lib/core/utils/money.dart` — `minorUnits / 100.0` loses precision above 2^53
minor units (≈ 90 trillion currency units) and the fallback symbol is `'$code '`
with a trailing space. No test covers `money.dart` at all.

### 5.3 UI ↔ domain ↔ repository mismatches

| # | Layer | Mismatch |
|---|---|---|
| 1 | UI vs domain | Amount input shows the **device** currency symbol (`AppSettings.instance.currencySymbol`) while the expense is created with `crib.currency` (F-M2). A USD crib shows `₹`. |
| 2 | UI vs domain | `SplitShareEditor` reports a member count that includes removed members (F-M4); the ledger charges only active ones. |
| 3 | Domain vs repository | AUD-FIN-03 above — removed-member charging is blocked in the repository but allowed by the domain rule. |
| 4 | Repository vs planned DB | AUD-FIN-02 — the net rule is implemented, but the planned schema and the approved product rule both specify per-pair debt. A literal port of the Dart code to SQL would ship the wrong rule. |
| 5 | UI vs repository | `SettleUpSheet` can only create `selfManaged`; `SettlementRepository.updateStatus` (recipient confirm / sender cancel) is **unreachable from the UI** (F-H8). The approved rule "only the recipient may confirm" exists only in the repository. |
| 6 | UI vs repository | `CribRepository.delete` is implemented and owner-guarded, but no UI affordance was found. |

### 5.4 Concurrency

**Not tested, and not testable in the current architecture.** `settlement.create`
computes balances and then appends with no lock
(`in_memory_repositories.dart:456-522`). Two concurrent settlements can both
pass the overpayment check and jointly exceed the debt. Two concurrent expense
edits can lose one another's change (version checks are single-process only).
This is F-H7, still open, and it **requires** `pg_advisory_xact_lock` or row
locks in Postgres — it cannot be fixed in Dart.

---

## 6. Workstream D — Security and privacy (summary)

Full matrix with the RLS/RPC control mapping:
**`docs/SECURITY_AND_DATA_INTEGRITY_FINDINGS.md`**.

### 6.1 The threat model that matters

Every repository check in this codebase is a **client-side** check. Per
`docs/BACKEND_SECURITY_REQUIREMENTS.md:3-6`, "the Flutter client, custom URI
parameters, local repository checks, and `FinancialLedger` validation are not
authorization boundaries." A modified client, a replayed HTTP request, or a
guessed identifier bypasses **every** check in `lib/`. The Dart checks are
useful for fast feedback and for the UI; they are not a security boundary and
must not be reported as one.

### 6.2 Confirmed security findings

**AUD-SEC-01 — No repository method scopes a read to the caller's memberships. (Critical, confirmed)**

`in_memory_repositories.dart`: `cachedCribs` `:129`, `list()` `:131`,
`getById()` `:133`/`:269-271`; `cachedExpenses` `:286`, `list()` `:288-290`
(unfiltered when `cribId` is null), `getById()` `:292-295`/`:393-395`;
`cachedSettlements` `:447-454`; `cachedEvents` `:569`, `list()` `:571-576`;
`invitations.getById()` `:759-761`.
Any signed-in user who learns or guesses a crib id can read every expense
description, amount, participant list, settlement and activity event of that
crib. The screens inherit this: home, cribs, search and the activity feed all
iterate `cachedCribs` unfiltered, and `SearchScreen` prints
`${b.members.length} members` for cribs the user is not in.
**Why it blocks Supabase:** the interface has no notion of "my cribs", so there
is nothing for an RLS policy to bind to. Every list/get contract must become
membership-scoped *before* a backend can implement it safely.
**Missing coverage:** **none**, and worse — `test/in_memory_repositories_test.dart`
**asserts the unscoped behaviour as correct** (`:110 expect(await expenses.list(), isEmpty)`;
`:142`, `:145`, `:146` call `list()` with no `cribId`). No test in the suite
ever creates a second crib, so cross-crib leakage is **structurally
undetectable**.

**AUD-SEC-02 — There is no authentication, and the user id is client-owned. (Critical, confirmed)**

`in_memory_repositories.dart:96-123` — `signIn(email, displayName)` validates
the *format* of the email and then sets
`AuthUser(id: _store.currentUser?.id ?? 'me', ...)`. There is no password, no
token, no session, no expiry.
`sign_in_screen.dart:33-44` waits 600 ms and navigates **without calling
`auth.signIn` at all**; the Google button (`:124-128`) does the same.
`create_account_screen.dart:24-38` navigates with a hard-coded
`email: 'you@gmail.com'`.
`profile_screen.dart:551-564` — "Log out" navigates to the welcome screen and
**never calls `signOut()`**, so the in-memory `currentUser` stays set. A user
who taps "Log out" is still authenticated to every repository.
`profile_screen.dart:527-548` — "Delete account" shows the toast
`Account deletion requested` and calls nothing.
**Consequence:** `auth.uid()` is the only identity Postgres RLS can trust, and
nothing in this app can produce one. The string `'me'` is a client-controlled
value that would be trivially spoofable in any implementation that copied this
design.
**Blocks:** Supabase — yes; beta — **yes** (the "Log out" button is a lie);
production — yes.

**AUD-SEC-03 — `CribRepository.delete` hard-deletes the crib, orphaning its financial history, with no guard against confirmed settlements. (High, confirmed)**

`in_memory_repositories.dart:196-206`. The current implementation *does*
preserve `expenses` and `settlements` (the comment at `:204` says so, and
`crib_operations_test.dart:180-182` asserts it). **The prior finding F-C3 as
written in `docs/PRODUCT_FINDINGS.md` — "delete removes expenses/settlements" —
is refuted by the current code and is stale in two places:**
* `lib/data/repositories.dart:42` still documents "Deletes the crib **and the
  records that belong to it**" — the interface contract lies.
* `docs/SUPABASE_MIGRATION_PLAN.md:67-72` and
  `docs/BACKEND_READINESS_AUDIT.md:56` ("delete cascades") describe the
  destructive behaviour that no longer exists.

The **live** problem is different and real: deleting a crib removes the crib
row while its expenses, settlements and membership rows keep pointing at a
`cribId` that no longer resolves. There is **no guard** preventing deletion of a
crib that has `confirmed`/`selfManaged` settlements, and no tombstone, so the
audit trail points at records that can no longer be reached. `PRODUCT_RULES.md`
§2 lists tombstone/reversal as explicitly **Open**.

**AUD-SEC-04 — Members can be invented. (High, confirmed)**

`Member` (`lib/data/models.dart:8-66`) accepts an arbitrary `id` and `name`.
`CribRepository.addMember` (`:208-234`) takes a client-supplied `Member` and
never checks that the id belongs to a real user.
`FirstCribScreen` manufactures `ob1…obN` / "Housemate N" placeholders from the
household-size step. `CreateCribPopup` lets the creator type a free-text name.
The QR flow (`scan_flow.dart:200-210`) copies a **display name** from one crib
into another, so a member can be added under a name they never claimed.
**Blocks:** Supabase — yes (a FK to `profiles` makes this impossible, and the
onboarding flow must be replaced with real invitations).

**AUD-SEC-05 — Invitation metadata is readable by anyone, and tokens are stored in plaintext. (Medium, confirmed)**

`in_memory_repositories.dart:759-761` — `getById(token)` requires **no** user
and no membership; it returns `cribId` and `createdById` for any token. The
token is the only credential, so its metadata should not be readable to anyone
(already noted as F-L4). Tokens are also stored in plaintext — acceptable in
memory, but the database must store `sha256(token)` only.

**AUD-SEC-06 — Every authorization check is client-side only. (Critical by implication, confirmed)**

See §6.1. Listed explicitly because it is the root cause that makes every other
"High" finding here a **Critical** in production.

### 6.3 Behaviours that are correct (verified)

| Control | Evidence | Verdict |
|---|---|---|
| `paycal://crib/<id>` grants no membership | `deep_link.dart:132-140` → toast, no mutation; `ui_flows_test.dart` "a crib link never grants membership" | **Correct** |
| `paycal://invite/<token>` joins only via `InvitationRepository.accept` | `deep_link.dart:142-174` | **Correct** |
| Invitation token: 32 chars, `Random.secure()`, 62-char alphabet | `in_memory_repositories.dart:833-841` | **Correct** |
| Acceptance chain: token → revoked → expired → used → crib → membership eligibility | `in_memory_repositories.dart:790-817`; `invitations_test.dart` (11 tests) | **Correct** |
| Invitation is single-use; a second accept is rejected | `invitations_test.dart` | **Correct** |
| Owner-only create/revoke of invitations | `in_memory_repositories.dart:734-739`, `:820-831` | **Correct** |
| QR scan mutates membership only through owner-only `addMember` | `scan_flow.dart:200-210`; `membership_test.dart:9-26` | **Correct** |
| Removed member cannot create expenses or settlements | `in_memory_repositories.dart` active-member guards; `membership_test.dart` | **Correct** |
| Owner cannot be removed; owner cannot be added as a member | `in_memory_repositories.dart:216-218`, `:244-246` | **Correct** |
| Membership cannot be changed through `CribRepository.update` | `in_memory_repositories.dart:170-175`; `membership_test.dart` | **Correct** |
| Owner-only crib update/delete, with version conflict | `crib_operations_test.dart` | **Correct** |
| Settlement idempotency is scoped to the sender and payload-checked | `in_memory_repositories.dart:469-488` | **Correct** (F-H3 fixed) |
| Dispute never changes money | `expense_permissions_test.dart` | **Correct** |
| Activity timestamps are ISO-8601, not the literal `'now'` | `in_memory_repositories.dart:905` — **the prior claim F-H5 is refuted** | **Correct in substance**; F-L2 (display string in domain) remains |

### 6.4 Production-security claims that CANNOT be tested (no backend exists)

The following are **untestable in this repository** and must not be claimed as
working: RLS policies; `SECURITY DEFINER` RPCs; `auth.uid()`-derived identity;
server-side share-sum enforcement; per-pair debt in SQL; advisory/row locks;
compare-and-swap on `version`; token hashing; invitation rate limiting; audit
logging of auth/invitation/mutation attempts; session revocation on sign-out or
account deletion; service-role isolation; encryption at rest/in transit;
cross-device consistency; concurrent settlement serialization; account-deletion
anonymisation and retention purge.

---

## 7. Workstream E — State and data integrity

**AUD-DAT-01 — Nothing persists across an app restart. (Critical for production, confirmed)**

`PayCalRepositories.instance` holds a single `InMemoryStore` in memory
(`in_memory_repositories.dart:38-45`). A fresh process re-seeds from
`MockData`. The only persisted state is `OnboardingDraft` (SharedPreferences)
and some `AppSettings` values. **There is no durable storage for cribs,
expenses, settlements, invitations, schedules or activity.**
**Consequence:** the app loses all financial data on restart. This is a
prototype characteristic, not a bug in the current code — but it means **no
claim of "the app works" can be made**, and it is the reason Workstream B can
never produce a real end-to-end pass in this architecture.
This must not be confused with persistence: `PRODUCT_RULES.md` §2 and
`BACKEND_SECURITY_REQUIREMENTS.md` both anticipate a tombstone model; there is
currently **neither** a tombstone nor a hard-delete-with-guard.

**AUD-DAT-02 — Deleting a crib leaves orphaned financial rows and no tombstone. (High, confirmed)** — see AUD-SEC-03.

**AUD-DAT-03 — Expense deletion is a hard delete; the activity trail survives and points at a record that no longer exists. (Medium, confirmed)**

`ExpenseRepository.delete` removes the row from the store and records an
`expense_deleted` activity event. The financial effect is *correct* (balances
recompute), but the audit trail references a record that no longer exists, and
there is no reversal/tombstone. `PRODUCT_RULES.md` §2 lists this as **Open**,
so it is a *product decision* recorded as a defect, not a code bug.

**AUD-DAT-04 — The activity feed renders a raw ISO-8601 string, and the "All" filter returns every event in the store. (Medium, confirmed)**

`lib/data/models.dart:406` keeps `time` as a display `String` in the domain
model; `activity_screen.dart:86` renders it raw. `ActivityRepository.list()`
returns the entire cache when `cribName` is null (`:571-576`). The "All" filter
is therefore a **global feed across every crib**, including cribs the user is
not a member of (F-M5) — the same root cause as AUD-SEC-01 but visible in the
UI.
**Missing coverage:** `activity_test.dart:36` asserts only
`expect(event.occurredAt, isNotNull)`, which is **trivially true** because
`ActivityEvent.occurredAt` defaults to `DateTime.now()` (`models.dart:403`).

**AUD-DAT-05 — Screens do not all react to repository mutations. (Medium, confirmed by inspection)**

Updates propagate through `onSaved` / `onDone` / `setState` callbacks and, in
some screens, by re-reading the repository cache. `MainShell` uses an
`IndexedStack`, so the four tabs stay mounted and can show **stale** data
after a mutation performed in a pushed route (for example an expense added
from the crib detail screen may not appear in the Home tab until the tab is
rebuilt). No reactive invalidation layer exists.

**AUD-DAT-06 — Actor identity in the activity trail is the client-owned id. (Medium, confirmed)**

`_recordActivity` (`:892-914`) records `actorId: actor.id`, which is the
client-controlled `'me'` string. Actor identity is therefore **not** reliable
in the current architecture, and `PRODUCT_RULES.md` §8 requires an accurate
actor. Server-generated actor ids and server timestamps are required.

**AUD-DAT-07 — Failures generally do not leave partially mutated state. (Positive, confirmed by inspection)**

Repositories validate before mutating and throw `RepositoryException` with
codes `validation` / `unauthorized` / `notFound` / `conflict` / `forbidden`;
the UI applies local state changes only after a successful call. This is a
sound pattern and is worth preserving through the backend port.

**AUD-DAT-08 — Repeated taps are not uniformly debounced. (Low, confirmed)**

`SignInScreen` has a `_busy` guard. Most other submit paths do not. The
idempotency key in `SettleUpSheet` embeds
`DateTime.now().microsecondsSinceEpoch`, so a double tap produces **two
different keys** and therefore two settlements rather than a replay. Expense
creation has no idempotency key at all (`e${DateTime.now().millisecondsSinceEpoch}`),
so a double tap can create two expenses.

---

## 8. Workstream F — Testing and execution

**AUD-TST-01 — The golden baseline is stale and was silently overwritten, uncommitted. (High, confirmed)** — see §2.

**AUD-TST-02 — `test/failures/*.png` are tracked in git and `.gitignore` does not exclude them. (Medium, confirmed)** — failure artifacts are committed (`8a83032`).

**AUD-TST-03 — `test/repro_email_path_test.dart` asserts nothing. (Medium, confirmed)** — it taps "Continue with email" and `print`s a text dump (`:20`). It passes on any code path that does not throw and emits ~22 lines of reporter noise.

**AUD-TST-04 — The overpayment tests cannot distinguish the implemented rule from the approved rule. (High, confirmed)** — see §5.2 AUD-FIN-02.

**AUD-TST-05 — The unscoped-read behaviour is asserted as correct by the test suite. (High, confirmed)** — see AUD-SEC-01.

**AUD-TST-06 — Six live defects have zero test coverage.** F-M1 (`-0.50` → +50), F-M10 (`ownerId` fallback), F-M5 (unscoped activity feed), F-M4 (removed members in counts), F-H4 (inventable members), F-L4 (invitation metadata readable by anyone). None of these is exercised anywhere in `test/`.

**AUD-TST-07 — `test/golden_probe_test.dart` carries dead `print` diagnostics and a misleading assertion. (Low, confirmed)** — its own probe printed `dialogs: 0` because `showDialog` here builds a `Center(Container(...))`, not a `Dialog`.

**AUD-TST-08 — `BACKEND_READINESS_AUDIT.md` overstates and understates coverage. (Medium, confirmed)**
* *Overstates (3 places):* "Crib operations: … delete cascades" (line 56) — the
  implementation and the test both **preserve** expenses/settlements.
  "Settlements: … overpayment rejection on both sides" (line 61) — only the net
  rule is exercised; the "receiver" test is rejected by the sender-side check.
  "Onboarding smoke tests and the golden probe" (line 70) — the golden passes
  only because of an uncommitted overwrite.
* *Understates:* the "Not covered, and why" list (line 72) contains exactly one
  item, but at least eight in-scope areas are uncovered — money parsing,
  `ownerId` fallback, per-pair settlement debt, cross-sender idempotency,
  removed-member charging, activity timestamp semantics, invitation metadata
  leakage, and every UI-level settlement path.

**AUD-TST-09 — No device or simulator execution was performed. (Coverage gap, confirmed)**
No simulator/device was available in the audit environment. Platform behaviours
that remain unverified are listed in `docs/END_TO_END_TEST_MATRIX.md` §4.

### 8.1 Prior claims — verified status

| Prior claim | Source | Verdict |
|---|---|---|
| "110 passed, 1 failed (golden_probe)" | `MILESTONE_1_VERIFICATION.md` | **FALSE as of now** — 112/112 pass in the working tree; the failure reproduces on a clean `HEAD` checkout |
| Golden failure is "intentional UI drift, not a baseline regression" | `MILESTONE_1_VERIFICATION.md:33` | **UNSUPPORTED** — the diff is one renamed string; the baseline was overwritten uncommitted |
| "No evidence it is pre-existing" | `MILESTONE_1_VERIFICATION.md:34` | **CORRECT** — and it is not pre-existing either; it is a stale baseline from an unapproved regeneration |
| `Money.tryParseToMinor('-0.50')` → +50 | `PRODUCT_FINDINGS.md` F-M1 | **TRUE** — `money.dart:48-49`; runtime confirmed |
| Settlement overpayment uses net not per-pair | `PRODUCT_FINDINGS.md` F-H2 | **TRUE** — `in_memory_repositories.dart:504-518` |
| Idempotency key unscoped to sender | `PRODUCT_FINDINGS.md` F-H3 | **FALSE in current code** — sender-scoped + payload-checked (`:469-488`); the finding is stale |
| `CribRepository.delete` removes expenses/settlements | `PRODUCT_FINDINGS.md` F-C3 | **FALSE in current code** — they are preserved; but two docs still claim otherwise and the real problem (orphans, no guard, no tombstone) is unrecorded |
| Activity events stamped `'now'` | `PRODUCT_FINDINGS.md` F-H5 | **FALSE as literally stated** — ISO-8601 strings are used; the real defect is F-L2 (display string in the domain model) |
| Removed member can still be charged | `PRODUCT_FINDINGS.md` F-H6 | **FALSE at the repository layer, TRUE at the domain layer** — see AUD-FIN-03 |
| `ownerId` nullable with first-admin fallback | `PRODUCT_FINDINGS.md` F-M10 | **TRUE** — `models.dart:204,213`; `in_memory_repositories.dart:867-873`; runtime confirmed |

---

## 9. Reconciliation of contradictory findings

| Topic | Contradiction | Resolution |
|---|---|---|
| Golden probe | "1 failed" vs "112 pass" | Both true at different times. The `110+1` state is historical; the current tree passes only because the baseline was overwritten uncommitted. Evidence in §2. |
| Crib delete | F-C3 says history is destroyed; code preserves it | **F-C3 as written is refuted.** The interface docstring (`repositories.dart:42`) and two docs are stale. The live defect is recorded as AUD-SEC-03 / AUD-DAT-02. |
| Idempotency | F-H3 says unscoped; code scopes it | **F-H3 is stale.** Code is correct; the cross-sender case is merely untested. Recorded as AUD-TST-04 coverage gap, not a defect. |
| Activity time | F-H5 says `time: 'now'` | **Refuted as literal**; substituted by F-L2 (display string in domain) and AUD-DAT-04. |
| Removed-member charging | Repo blocks it; domain allows it | **Both true, different layers.** Recorded as AUD-FIN-03 — the domain rule, which `PRODUCT_RULES.md` names authoritative, lacks the guard. |
| Overpayment rule | `PRODUCT_RULES.md` says per-pair; code says net; tests "cover both sides" | **Code contradicts the approved rule.** The tests cannot distinguish them. Recorded as AUD-FIN-02 + AUD-TST-04. |
| Test count | "110" / "111" / "112" across docs | 112 is the real visible count; 126 JSON records include 14 `loading` pseudo-tests. |
| `balance_engine.dart` dead | F-M9 says dead | **Partly false** — `test/widget_test.dart` calls `BalanceEngine.equalSplit`. `settle_sheet.dart` is genuinely dead. |
| Member counts | F-M4 says "3 sites" | 2 confirmed sites in the current tree (`split_share_editor.dart:179`, `crib_detail_screen.dart:216`); the previously cited `home_screen.dart:1044` / `cribs_screen.dart:452` / `search_screen.dart:172` are not the current locations. |

---

## 10. Feature-level status summary

| Status | Features |
|---|---|
| **Verified / sound** | Financial ledger math, split algorithms, balances, suggested transfers, recurring date rules, invitation lifecycle, ownership & membership rules, expense permission model, version conflicts, deep-link rejection of legacy crib links, `paycal://invite/` acceptance, QR membership path |
| **Partial** | Activity feed (timestamps, scoping), Settlement UI (no pending/confirm), Crib edit sheet (no delete affordance), Recurring (no edit/pause), Split editor (controller rebuild), Money formatting, Timezone handling |
| **Defective** | Auth flow, Session handling, Logout, Account deletion, Expense amount currency, Activity filtering, Member counts, Money parsing, Overpayment rule, Domain participant activeness, Recurring payer policy, Crib delete orphaning, Owner id nullability, Member count consistency, Invitation metadata exposure, Golden baseline, Test suite hygiene |
| **Unimplemented** | Real authentication, Session restoration, Durable persistence, Recipient-confirm UI, Leave-crib, Archive-crib, Ownership transfer, Real notifications, Password reset, Directory lookup, Account deletion backend, Supabase/RLS/RPC, `UserDirectoryRepository`, `LedgerRepository.balances`, `RecurringPaymentRepository.catchUp`, `AccountRepository.requestDeletion` |
| **Unverified** | Device/simulator behaviour, platform deep-link delivery, real share-sheet delivery, real notification permission flow, multi-device consistency, concurrent-write behaviour, cross-user consistency |

---

## 11. Consolidated findings register

Severity definitions: **Critical** = data loss, data exposure, or a control that
cannot be fixed later without a backend change · **High** = wrong financial
result, a broken user journey, or a control that silently fails ·
**Medium** = incorrect information, missing capability with a workaround ·
**Low** = quality, hygiene, performance.

Confirmed = reproduced by execution or proven by direct code reading. Suspected
= strongly indicated but not reproduced.

| ID | Sev | Finding | Workflow affected | Evidence | Conf. | Blocks Supabase | Blocks Beta | Blocks Prod |
|---|---|---|---|---|---|---|---|---|
| AUD-SEC-01 | Critical | No read is scoped to caller memberships | Home, cribs, search, activity | `in_memory_repositories.dart:129,131,133,269-271,286,288-290,292-295,393-395,447-454,569,571-576` | Confirmed | **Yes** | **Yes** | **Yes** |
| AUD-SEC-02 | Critical | No authentication; client-owned user id; logout is a no-op | Sign-up/in, sign-out, all writes | `in_memory_repositories.dart:96-123`; `sign_in_screen.dart:33-44,124-128`; `create_account_screen.dart:24-38`; `profile_screen.dart:551-564` | Confirmed | **Yes** | **Yes** | **Yes** |
| AUD-SEC-06 | Critical | Every authorization check is client-side only | All | `docs/BACKEND_SECURITY_REQUIREMENTS.md:3-6` | Confirmed | **Yes** | **Yes** | **Yes** |
| AUD-DAT-01 | Critical | No durable persistence; all data lost on restart | Everything | `in_memory_repositories.dart:38-45`; `main.dart` | Confirmed | **Yes** | **Yes** | **Yes** |
| AUD-FIN-02 | High | Settlement overpayment uses net balance, not per-pair debt | Record settlement | `in_memory_repositories.dart:504-518`; runtime: 600-unit settlement to a party with 0 debt accepted; creditor cannot settle 1 unit | Confirmed | **Yes** | **Yes** | **Yes** |
| AUD-FIN-03 | High | `validateExpense` allows removed members; `validateSettlement` does not | Add expense / balances | `financial_ledger.dart:93` vs `:134` | Confirmed | **Yes** | No | **Yes** |
| AUD-SEC-04 | High | Members can be invented (placeholder members) | Onboarding, add member, QR | `models.dart:8-66`; `in_memory_repositories.dart:208-234`; `first_crib_screen.dart` | Confirmed | **Yes** | No | **Yes** |
| AUD-SEC-03 | High | Crib delete hard-deletes, orphans financial rows, no settlement guard | Delete crib | `in_memory_repositories.dart:196-206`; stale contract at `repositories.dart:42` | Confirmed | **Yes** | No | **Yes** |
| AUD-TST-01 | High | Golden baseline stale, overwritten uncommitted; CI fails | Build | `test/goldens/all_set_dialog.png` (`M`); `invite_screen.dart:140`; 0.53% / 2546 px reproduced | Confirmed | No | No | **Yes** |
| AUD-TST-04 | High | Overpayment tests cannot distinguish the implemented rule from the approved rule | Settlement correctness | `settlements_test.dart:75,102` | Confirmed | No | No | **Yes** |
| AUD-TST-05 | High | Test suite asserts the unscoped-read behaviour as correct | Data isolation | `in_memory_repositories_test.dart:110,142,145,146` | Confirmed | No | No | **Yes** |
| AUD-DAT-03 | Medium | Expense delete is a hard delete; trail points at a missing record | Delete expense | `ExpenseRepository.delete` | Confirmed | No | No | **Yes** |
| AUD-DAT-04 | Medium | Activity feed shows raw ISO strings; "All" returns every event | Activity | `models.dart:406`; `activity_screen.dart:86`; `in_memory_repositories.dart:571-576` | Confirmed | No | No | **Yes** |
| AUD-DAT-05 | Medium | Screens do not all react to repository mutations | Cross-screen consistency | `main_shell.dart` `IndexedStack`; callback-based refresh | Confirmed | No | No | **Yes** |
| AUD-DAT-06 | Medium | Activity actor id is the client-owned `'me'` | Activity / audit | `in_memory_repositories.dart:892-914` | Confirmed | **Yes** | No | **Yes** |
| AUD-SEC-05 | Medium | Invitation metadata readable by anyone; tokens plaintext | Invitations | `in_memory_repositories.dart:759-761` | Confirmed | **Yes** | No | **Yes** |
| AUD-FIN-01 | Medium | `tryParseToMinor('-0.50')` → `+50` | Amount input | `money.dart:48-49`; runtime confirmed | Confirmed | No | **Yes** | **Yes** |
| AUD-FIN-04 | Medium | Recurring payer is the creator even after removal; any member triggers generation | Recurring | `in_memory_repositories.dart:649,685` | Confirmed | No | No | **Yes** |
| AUD-DAT-08 | Low | Repeated taps not debounced; expense create has no idempotency key | Add expense / settle | `settle_up_sheet.dart` key uses `microsecondsSinceEpoch`; `quick_add_sheet.dart` id `e${millisecondsSinceEpoch}` | Confirmed | No | No | No |
| AUD-FIN-05 | Low | `nextDueDateAfter` O(n) ≤ 5000 | Crib open | `recurring_scheduler.dart` | Confirmed | No | No | No |
| AUD-FIN-06 | Low | `Money.format` float division; trailing-space fallback symbol | Amount display | `money.dart` | Confirmed | No | No | No |
| AUD-TST-02 | Medium | `test/failures/*.png` tracked in git | Repo hygiene | `git ls-files test/failures` | Confirmed | No | No | No |
| AUD-TST-03 | Medium | `repro_email_path_test.dart` asserts nothing | Test suite | `test/repro_email_path_test.dart:20` | Confirmed | No | No | No |
| AUD-TST-08 | Medium | `BACKEND_READINESS_AUDIT.md` overstates (3) and understates coverage | Documentation | lines 56, 61, 70, 72 | Confirmed | No | No | No |
| AUD-TST-09 | Low | No device or simulator execution was performed; platform behaviour unverified | All UI | `docs/END_TO_END_TEST_MATRIX.md` §4 | Confirmed | No | No | **Yes** |
| AUD-TST-07 | Low | Golden probe carries dead/misleading diagnostics | Test suite | `test/golden_probe_test.dart:13-16` | Confirmed | No | No | No |
| AUD-CTRL-01 | Medium | "Forgot password" has no handler | Sign in | `sign_in_screen.dart` | Confirmed | No | **Yes** | **Yes** |
| AUD-CTRL-02 | Medium | "Turn on notifications" never requests permission or schedules anything | Onboarding | `notifications_sheet.dart` | Confirmed | No | **Yes** | **Yes** |
| AUD-CTRL-03 | Medium | "Join with a link" only shows a toast; no token entry path | Onboarding | `first_crib_screen.dart` | Confirmed | No | **Yes** | **Yes** |
| AUD-CTRL-04 | Medium | No UI affordance for delete-crib although the repo supports it | Crib management | `crib_edit_sheet.dart`, `crib_detail_screen.dart` | Suspected | No | No | **Yes** |
| AUD-CTRL-05 | Medium | No recurring "edit" or "pause" — only "cancel" | Recurring | `crib_detail_screen.dart`; `PRODUCT_RULES.md` §5 | Confirmed | No | No | No |
| AUD-FIN-07 | Medium | Currency input shows device symbol, not crib currency | Add/edit expense | `amount_field.dart` + `AppSettings.instance.currencySymbol` vs `crib.currency` | Confirmed | No | No | **Yes** |
| AUD-FIN-08 | Medium | Member counts include removed members | Split editor, crib detail | `split_share_editor.dart:179`; `crib_detail_screen.dart:216` | Confirmed | No | No | No |
| AUD-FIN-09 | Medium | `Crib.ownerId` nullable with first-admin fallback | Ownership | `models.dart:204,213`; `in_memory_repositories.dart:867-873` | Confirmed | **Yes** | No | **Yes** |
| AUD-FIN-10 | Medium | Recurring schedules store a fixed UTC offset; DST not followed | Recurring | `recurring_scheduler.dart`; `BACKEND_READINESS_AUDIT.md:28` | Confirmed | No | No | No |
| AUD-SEC-07 | Low | `MemberRole`/`isAdmin` stored twice; no explicit admin role | Membership | `models.dart:33`; `PRODUCT_RULES.md` §1 | Confirmed | No | No | No |
| AUD-UI-01 | Low | Light theme only; no dark mode | All | `app_theme.dart`; `ThemeMode.light` | Confirmed | No | No | No |

**Totals:** Critical 4 · High 7 · Medium 19 · Low 7 — **37 findings**.

(`AUD-DAT-02` is a cross-reference to `AUD-SEC-03` — the same defect, seen from
the data-integrity side — and is deliberately not counted twice.)

---

## 12. Final decision

### 1. Domain / financial correctness
**Ready with explicitly listed limitations.**
The ledger, split algorithms, balance derivation, suggested transfers, recurring
date rules, invitation lifecycle and permission model are sound and tested. The
limitations are: the overpayment rule contradicts the approved product rule
(AUD-FIN-02), the domain participant-activeness rule is inconsistent with the
repository (AUD-FIN-03), the recurring payer policy is undecided (AUD-FIN-04),
money parsing/formatting defects remain (AUD-FIN-01, AUD-FIN-06), and the
domain has **no concurrency** story.

### 2. UI and user-flow completeness
**Not ready.**
Authentication, session, sign-out, account deletion, password reset, member
join, notifications, delete-crib, recurring edit/pause, and the recipient-confirm
settlement flow are all missing or inert. Every visible interactive control was
enumerated; the defects are listed in §3.3 and the findings register.

### 3. Authentication and access control
**Not ready.**
There is no authentication. The identity is a client-owned string. "Log out"
does not sign out. Every authorization check is client-side.

### 4. Data persistence and cross-user consistency
**Not ready.**
Nothing persists across a restart. There is no cross-user or cross-device
consistency model, because there is no shared store.

### 5. Supabase integration readiness
**Not ready.**
Blocked by AUD-SEC-01 (contracts are not membership-scoped, so there is nothing
for RLS to bind to), AUD-SEC-02 (no `auth.uid()`), AUD-SEC-06 (client-side-only
checks), AUD-SEC-04 (inventable members, no FK target), AUD-SEC-03 (no
tombstone, no settlement guard on delete), AUD-DAT-06 (client-owned actor ids),
AUD-FIN-09 (nullable owner id), and AUD-FIN-02 (the overpayment rule must be
decided and mirrored in SQL). The schema design in
`docs/SUPABASE_MIGRATION_PLAN.md` is sound; the *client contracts* it must
bind to are not.

### 6. Production release readiness
**Not ready.**
A Critical data-exposure path, no authentication, no persistence, an
incorrect-by-construction financial rule, and a failing CI golden baseline are
each independently disqualifying.

---

## 13. Top ten next actions, in priority order

| # | Action | Why first | Closes |
|---|---|---|---|
| **1** | Add real authentication and a session gate: split `signIn` into `signUp`/`signIn`/`signOut`, persist the session, restore it on launch, and make "Log out" actually sign out. | Nothing else can be tested honestly without a real identity, and every RLS policy depends on `auth.uid()`. | AUD-SEC-02, AUD-SEC-06 |
| **2** | Make every repository contract membership-scoped: add `listMyCribs()`, make `cribId` mandatory on expense/settlement/activity reads, scope every `getById` to the caller's memberships, and **delete the tests that assert the unscoped behaviour**. | This is the structural blocker for RLS. Until it is done, the interface cannot be safely backed by a database. | AUD-SEC-01, AUD-TST-05 |
| **3** | Decide and implement the **per-pair** overpayment rule in `FinancialLedger` (a `pairwiseDebt(from, to)` function), replace the net check, and add the P3 acceptance test plus the two missing settlement tests (cross-sender idempotency, key reused with a different payload). | The current rule both rejects legitimate settlements and accepts settlements of money that was never owed. It must be decided before the SQL mirror is written. | AUD-FIN-02, AUD-TST-04 |
| **4** | Unify participant activeness: make `FinancialLedger.validateExpense` use `crib.activeMembers` (as `validateSettlement` already does) and add a test that a removed member cannot be charged. | The rule lives only in the repository; the domain layer that the SQL mirror would be copied from does not have it. | AUD-FIN-03 |
| **5** | Replace the placeholder-member onboarding with real invitations, and add a `UserDirectoryRepository` that resolves a handle to a user id so `addMember` never accepts a client-supplied name. | Inventable members are a hard FK blocker and undermine the whole membership model. | AUD-SEC-04, AUD-FIN-09 |
| **6** | Implement the tombstone/soft-delete model for cribs and expenses, and refuse to delete a crib that has `confirmed`/`selfManaged` settlements. Add a `deleted_at` to the planned schema. | Prevents irreversible destruction of other members' financial records and closes AUD-SEC-03/AUD-DAT-03. | AUD-SEC-03, AUD-DAT-03 |
| **7** | Fix the golden baseline properly: review the one-line text diff, **regenerate with approval**, and commit the new baseline together with the `invite_screen.dart` rename. Add `test/failures/` to `.gitignore` and untrack the committed artifacts. | CI currently fails on a clean checkout, and the current local pass is an accident of an uncommitted overwrite. | AUD-TST-01, AUD-TST-02, AUD-TST-07 |
| **8** | Fix the money layer: correct `tryParseToMinor` sign handling (including `-0.xx`), make `Money.format` integer-based, remove the trailing-space fallback symbol, and use the **crib** currency symbol in `AmountField` instead of the device symbol. | The `-0.50` → `+50` bug silently turns a charge into income; the currency mismatch shows the wrong symbol. | AUD-FIN-01, AUD-FIN-06, AUD-FIN-07 |
| **9** | Add idempotency keys to **all** mutations (expense create, member add, invitation create) and debounce every submit path, so a double tap or a network retry cannot create two records. | Idempotency is currently only implemented for settlements, and the settlement key itself is derived from a timestamp, so it does not survive a retry. | AUD-DAT-08, AUD-SEC-05 |
| **10** | Repair the activity feed: derive the display label from `occurredAt` in the UI and remove `time` from the domain model, scope the feed to the caller's cribs, and tighten `invitations.getById` so token metadata is not readable without a valid session. | The feed currently shows raw ISO strings and, in the "All" filter, events from cribs the user is not in. | AUD-DAT-04, AUD-DAT-06, AUD-SEC-05 |

**Secondary, after the above:** recipient-confirm settlement UI (AUD-FIN /
F-H8), recurring payer policy + edit/pause UI (AUD-FIN-04, AUD-CTRL-05),
owner-id non-nullability (AUD-FIN-09), member-count consistency (AUD-FIN-08),
dead code removal (`settle_sheet.dart`, `balance_engine.dart`), timezone
resolution (AUD-FIN-10), `nextDueDateAfter` complexity (AUD-FIN-05), and
correction of the three stale documentation claims (AUD-TST-08, `repositories.dart:42`).

---

## 14. Residual uncertainty and the evidence still needed

**A zero-known-bug result is not proof of zero bugs.** This audit found 34
findings in a codebase that `flutter analyze` reports as clean and that passes
112/112 tests. The following is explicitly **not** established:

1. **Device and platform behaviour is unverified.** No simulator or device was
   available. Deep-link delivery from a real browser/SMS, the platform share
   sheet, the notification permission flow, keyboard behaviour, safe-area and
   small-screen layouts, and the "Forgotten password" dead control were only
   read, never run.
2. **The journeys in `docs/END_TO_END_TEST_MATRIX.md` marked "Passed by
   execution" are widget/unit passes**, not real user journeys. A full
   end-to-end run — real user, real device, real backend — has never happened
   for any journey in this product.
3. **Cross-user and cross-device behaviour is entirely unexamined.** The
   architecture makes it impossible today.
4. **Concurrency is untested and untestable here.** The Dart implementation
   cannot demonstrate that two simultaneous settlements serialize correctly.
5. **The financial rule set is only as correct as the approved rules.** If
   `PRODUCT_RULES.md` §4's "outstanding debt **to the recipient**" wording is
   itself wrong for a multi-party crib, then AUD-FIN-02's fix is also wrong.
   This needs a product decision, not just a code change.
6. **The test suite's blind spots are structural, not incidental.** No test
   creates two cribs, no test uses `money.dart`, and the "overpayment" tests
   cannot fail for the right reason. The suite would go green against a
   materially different implementation.
7. **The `MILESTONE_1_VERIFICATION.md` claim of 110+1 was not independently
   reproducible as a current state.** It was reproduced as a *historical* state
   on a clean `HEAD` checkout. Any other past-state claims in the repository's
   documentation that were not re-derived here remain unverified.

**Evidence needed to raise confidence, in order:**
1. A real authentication implementation with a session gate and an
   end-to-end device test of sign-up → sign-in → restore → sign-out.
2. A second user in a second device session against one shared store, with
   cross-crib reads attempted from each — this is the only way to prove or
   disprove AUD-SEC-01 end to end.
3. The per-pair debt decision (product), its implementation, and the three
   settlement tests named in action #3.
4. A Postgres instance with the RLS suite from `SUPABASE_MIGRATION_PLAN.md` §6
   M3, executed as user A against user B's crib.
5. A concurrency test that fires two settlements simultaneously against the
   RPC and asserts one success and one rejection.
6. A golden baseline that is reviewed and committed, with CI running the full
   suite on a clean checkout.
7. A coverage report (`flutter test --coverage`) reviewed for the
   `money.dart`, `models.dart` and `activity` lines that are currently
   unexercised.

---

## 15. Cross-references

* `docs/END_TO_END_TEST_MATRIX.md` — journey-by-journey execution status
* `docs/SECURITY_AND_DATA_INTEGRITY_FINDINGS.md` — threat model, abuse cases, RLS/RPC control map
* `docs/RELEASE_READINESS_CHECKLIST.md` — go/no-go gates
* `docs/PRODUCT_FINDINGS.md` — historical register (unchanged; this audit
  supersedes individual entries, see §9)
* `docs/SUPABASE_MIGRATION_PLAN.md` — schema and RPC design (still valid; the
  *client contracts* it binds to are not, per action #2)
* `docs/PRODUCT_RULES.md` — the approved rule set, which AUD-FIN-02 shows the
  code does not yet implement

