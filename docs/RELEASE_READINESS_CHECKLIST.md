# PayCal Release Readiness Checklist

**Date:** 2026-10-20
**Overall production verdict: NOT READY.**

This checklist is derived from `docs/COMPREHENSIVE_PRODUCT_AUDIT.md` and
`docs/SECURITY_AND_DATA_INTEGRITY_FINDINGS.md`. Every box is either checked
against executed evidence or left unchecked with a reason. Nothing is checked on
the basis of a handler existing.

**Current verified state**

| Check | Result |
|---|---|
| `flutter analyze` | **Pass** — no issues found |
| `flutter test` (working tree) | **234 passed, 0 failed** (7s) |
| `flutter test` (clean `HEAD` checkout, git worktree) | **8 passed** — but it tests the *previous* app; 41 files of the current implementation are untracked |
| `flutter test` (clean copy of the working tree) | **234 passed, 0 failed** |
| Real authentication | **Absent** |
| Durable persistence | **Absent** |
| Supabase / RLS / RPC | **Absent** |
| Device or simulator run | **Not performed** |
| End-to-end user journey ever executed | **Never** |

> **Update 2026-10-20 (pre-Supabase fixes).** The gates marked **closed**
> below were met by `docs/MILESTONE_2_VERIFICATION.md`. The **client-side
> scoping is not a security boundary** — the RLS policies of
> `docs/SUPABASE_MIGRATION_PLAN.md` §4 are still what enforce the rules, and
> they cannot be tested until a database exists.
>
> **Update 2026-10-20 (Milestone 2B).** The golden probe is green again, the
> Crib Owner permissions are audited and tested
> (`docs/ADMIN_ROLE_AND_PERMISSION_AUDIT.md`), the recurring payer is
> implemented, and the twelve product flows are covered
> (`test/end_to_end_flows_test.dart`). The **clean checkout still tests the
> previous app** — see gate B13.

---

## 1. Gates for Supabase integration

**Gate result: NOT MET.** 7 of 8 items are open. These are structural: the
repository contracts do not yet express the concepts the RLS policies need.

| # | Gate | Status | Finding | Evidence |
|---|---|---|---|---|
| S1 | Every read is scoped to the caller's memberships | ☐ Open | AUD-SEC-01 | `in_memory_repositories.dart:129-133, 269-271, 286-295, 393-395, 447-454, 569-576` |
| S2 | A real identity exists that the database can trust | ☐ Open | AUD-SEC-02 | `in_memory_repositories.dart:96-123`; `sign_in_screen.dart:33-44` |
| S3 | No client-supplied `user_id` is trusted for authorization | ☐ Open | AUD-SEC-02, AUD-SEC-06 | every `_requireUser` / `_requireOwner` in `in_memory_repositories.dart` |
| S4 | Members resolve to real profiles (FK target exists) | ☐ Open | AUD-SEC-04 | `models.dart:8-66`; `in_memory_repositories.dart:208-234` |
| S5 | The owner id is non-null and authoritative | ☐ Open | AUD-FIN-09 | `models.dart:204,213`; `in_memory_repositories.dart:867-873` |
| S6 | Deletion is a tombstone with a settlement guard | ☐ Open | AUD-SEC-03, AUD-DAT-03 | `in_memory_repositories.dart:196-206`; `repositories.dart:42` (stale contract) |
| S7 | The activity actor id is server-derived | ☐ Open | AUD-DAT-06 | `in_memory_repositories.dart:892-914` |
| S8 | The financial rules to mirror into SQL are settled and implemented | ☐ Open | AUD-FIN-02, AUD-FIN-03 | `in_memory_repositories.dart:504-518`; `financial_ledger.dart:93` vs `:134` |

**Definition of done for this gate**
1. `listMyCribs()` exists and every other read is membership-scoped.
2. `signUp` / `signIn` / `signOut` are real, the session persists, and "Log out"
   actually signs out.
3. `addMember` takes a `user_id` resolved from a handle; no free-text member
   names; the placeholder onboarding flow is replaced.
4. `owner_id` is `NOT NULL`; the first-admin fallback is removed.
5. `deleted_at` exists on cribs and expenses; `delete_crib` refuses a crib with
   confirmed settlements.
6. The **per-pair** overpayment rule is decided and implemented in
   `FinancialLedger`, with `validateExpense` using `activeMembers`.
7. The `SUPABASE_MIGRATION_PLAN.md` §6 M1 acceptance list has a test for each
   item.

---

## 2. Gates for beta testing (internal / closed group)

**Gate result: NOT MET.** A closed beta still requires a working identity and
honest financial results.

| # | Gate | Status | Finding |
|---|---|---|---|
| B1 | Sign-up and sign-in work and produce a persistent session | ☐ Open | AUD-SEC-02 |
| B2 | Sign-out revokes the session and the user cannot continue | ☐ Open | AUD-SEC-02 |
| B3 | The app restores the session on relaunch | ☐ Open | AUD-SEC-02, AUD-DAT-01 |
| B4 | The overpayment rule matches the approved product rule | ☑ **Closed** | `AUD-FIN-02` — the debt of the pair, `test/settlement_pairwise_debt_test.dart` |
| B5 | A negative amount cannot become a positive expense | ☑ **Closed** | `AUD-FIN-01` — `test/money_test.dart` |
| B6 | The amount field shows the **crib** currency | ☐ Open | AUD-FIN-07 |
| B7 | Data survives an app restart | ☐ Open | AUD-DAT-01 |
| B8 | The golden baseline is reviewed and committed; CI is green on a clean checkout | ☐ Open | AUD-TST-01 — the approved baseline is restored, the rename is still unapproved |
| B9 | "Forgot password" does something | ☐ Open | AUD-CTRL-01 |
| B10 | The notifications toggle requests permission or is removed | ☐ Open | AUD-CTRL-02 |
| B11 | An invited user can join from the link without onboarding | ☐ Open | AUD-CTRL-03 |
| B12 | No double tap creates a duplicate record | ☐ Open | AUD-DAT-08 |
| B13 | The whole current architecture is committed, so CI tests this code | ☐ Open | **41 untracked files.** `docs/MILESTONE_2_VERIFICATION.md` §6 |
| B14 | A member can leave a Crib and the ownership can be transferred | ☐ Open | `docs/ADMIN_ROLE_AND_PERMISSION_AUDIT.md` P1, P2 |
| B15 | "Log out" really signs out and the account can be deleted | ☐ Open | `AUD-SEC-02` — needs real authentication |

**Note.** A beta *against the in-memory prototype* is technically possible today
and is a reasonable way to collect product feedback — but it must be labelled a
**prototype demo**, because no data persists, no identity is real, and the
overpayment rule is wrong. It must never be described as a working beta.

---

## 3. Gates for production release

**Gate result: NOT MET.** Every section has at least one open blocker.

### 3.1 Security and privacy

| # | Gate | Status | Finding |
|---|---|---|---|
| P1 | RLS enabled on every table, with membership predicates | ☐ Open | AUD-SEC-01 |
| P2 | All writes go through `SECURITY DEFINER` RPCs that re-authorize | ☐ Open | AUD-SEC-06 |
| P3 | No cross-crib read is possible (proven by a test, not by inspection) | ☐ Open | AUD-SEC-01 |
| P4 | Session tokens are short-lived, refreshable and revocable | ☐ Open | AUD-SEC-02 |
| P5 | Account deletion anonymises the profile, revokes sessions and invitations, and keeps financial history | ☐ Open | AUD-SEC-02; `ACCOUNT_DELETION.md` |
| P6 | Device-local personal data is cleared on account deletion | ☐ Open | `ACCOUNT_DELETION.md` §4; `OnboardingDraft` / `AppSettings` |
| P7 | Invitation tokens are stored hashed; raw tokens are returned once | ☐ Open | AUD-SEC-05 |
| P8 | Invitation acceptance is rate-limited and audited | ☐ Open | AUD-SEC-05 — untestable without a backend |
| P9 | No service-role credential exists in the app bundle | ☐ Open | not yet applicable |
| P10 | Errors surfaced to the user never leak server internals | ☐ Open | the UI shows `e.message` verbatim |

### 3.2 Financial correctness

| # | Gate | Status | Finding |
|---|---|---|---|
| P11 | The overpayment rule is per-pair and matches `PRODUCT_RULES.md` §4 | ☑ **Closed (client)** | `AUD-FIN-02` — the SQL mirror still has to be written and tested |
| P12 | The domain rejects a removed participant consistently | ☑ **Closed** | `AUD-FIN-03` — `test/active_member_enforcement_test.dart` |
| P13 | Amount parsing handles the sign correctly, including `-0.xx` | ☑ **Closed** | `AUD-FIN-01` — `test/money_test.dart` |
| P14 | Money formatting is integer-based and the symbol is correct | ◐ Half closed | `AUD-FIN-06` closed (exact integers), `AUD-FIN-07` open (device symbol) |
| P15 | The recurring payer policy is decided and implemented | ◐ Decided, one question open | `AUD-FIN-04` — the payer, the pause and the assignment are implemented and tested. **Still open:** whether the occurrences that were due before a pause should be generated at the pause |
| P16 | Recurring schedules store a resolvable timezone | ☐ Open | AUD-FIN-10 |
| P17 | Concurrent settlements are serialised and cannot jointly overpay | ☐ Open | AUD-FIN (concurrency) — needs a DB lock |
| P18 | Every mutation is idempotent under a retry | ☐ Open | AUD-DAT-08 |

### 3.3 Data integrity

| # | Gate | Status | Finding |
|---|---|---|---|
| P19 | Crib and expense deletion are tombstones with a settlement guard | ☐ Open | AUD-SEC-03, AUD-DAT-03 |
| P20 | The activity feed is scoped to the caller's cribs | ☐ Open | AUD-DAT-04 |
| P21 | Activity timestamps are server-generated and displayed as a relative label | ☐ Open | AUD-DAT-04, AUD-DAT-06 |
| P22 | All screens reflect a mutation immediately | ☐ Open | AUD-DAT-05 |
| P23 | Data survives a restart and is consistent across users | ☐ Open | AUD-DAT-01 |

### 3.4 User experience and product completeness

| # | Gate | Status | Finding |
|---|---|---|---|
| P24 | A member can request a transfer and the recipient can confirm it | ☐ Open | F-H8 / AUD-FIN (§5.2) |
| P25 | Delete-crib is either reachable in the UI or intentionally absent | ☐ Open | AUD-CTRL-04 |
| P26 | Recurring can be edited and paused, or the product says it cannot | ☐ Open | AUD-CTRL-05 |
| P27 | A member can leave a crib, or the product says they cannot | ☐ Open | J12 |
| P28 | Member counts are consistent (active vs total) across the app | ☐ Open | AUD-FIN-08 |
| P29 | The split editor rebuilds when the member list changes | ☐ Open | F-L3 |
| P30 | Loading, empty, success and error states exist for every list and form | ☐ Open | `docs/END_TO_END_TEST_MATRIX.md` §1 |
| P31 | Every visible control has a working handler | ☐ Open | AUD-CTRL-01, AUD-CTRL-02, AUD-CTRL-03 |
| P32 | Every listed journey is executed, not inspected | ☐ Open | `docs/END_TO_END_TEST_MATRIX.md` |

### 3.5 Quality gates

| # | Gate | Status | Finding |
|---|---|---|---|
| P3 | No cross-crib read is possible (proven by a test, not by inspection) | ◐ Client closed | `AUD-SEC-01` — `test/repository_isolation_test.dart` proves the client never asks for and never receives another member's data. **The database half is untestable until a backend exists.** |
| P34 | `flutter test` green on a **clean checkout** | ☐ Open | The golden probe fails against the approved baseline until the rename is approved or reverted. `AUD-TST-01` |
| P35 | The golden baseline was reviewed, approved and committed | ☐ Open | AUD-TST-01 — **the previously approved baseline is restored and was not regenerated**; the decision is one of two, see `docs/MILESTONE_2_VERIFICATION.md` §3 |
| P36 | `test/failures/` is git-ignored and untracked | ☐ Open | AUD-TST-02 |
| P37 | No test asserts nothing | ☐ Open | AUD-TST-03 — `repro_email_path_test.dart` |
| P38 | The test suite would fail against a wrong implementation | ◐ Partly closed | AUD-TST-04, AUD-TST-05 — the pairwise rule and the removed-member rule now have tests that fail against the old behaviour. The unscoped reads are scoped; the RLS half is untestable without a backend |
| P39 | The documentation matches the code | ☐ Open | AUD-TST-08; `repositories.dart:42`; `BACKEND_READINESS_AUDIT.md:56,61,70,72`; `PRODUCT_FINDINGS.md` F-C3, F-H3, F-H5 |
| P40 | Coverage reviewed for the currently unexercised modules (`money.dart`, `models.dart`, activity) | ☐ Open | AUD-TST-06 |

---

## 4. The eight missing assertions

These are the specific tests that would have prevented the confirmed defects.
Each is small, and each is currently absent.

| # | Assertion | Would have caught |
|---|---|---|
| 1 | `Money.tryParseToMinor('-0.50')` must be negative or rejected | AUD-FIN-01 |
| 2 | A settlement must not exceed the **per-pair** debt; a debtor who owes `r` 600 and `me` 0 must not be able to settle 600 with `me` | AUD-FIN-02 |
| 3 | A removed member must not be a share participant, in the **domain** rule as well as the repository | AUD-FIN-03 |
| 4 | A second user in a second crib must not be able to read crib A's expenses, settlements or activity | AUD-SEC-01 |
| 5 | A settlement idempotency key reused by a **different sender** must be rejected, and the same key with a **different payload** must conflict | AUD-TST-04 |
| 6 | A metadata-only expense edit must be allowed after a settlement, and an unrelated expense must be editable | §3.4 of the migration plan |
| 7 | `Crib.ownerId == null` must not silently grant the first admin the owner role | AUD-FIN-09 |
| 8 | The activity feed's "All" filter must contain only the caller's cribs | AUD-DAT-04 |

**Plus the one hygiene fix:** `grep -rn "activity.list()" test/` should show no
call without a `cribId` — the current calls in `in_memory_repositories_test.dart`
are the reason AUD-SEC-01 is invisible to the suite.

---

## 5. Pre-launch verification procedure

Run in this order once the gates above are closed.

1. `flutter analyze` — must report no issues.
2. `flutter test` — must be green **on a clean checkout**, not only in a dirty
   working tree. Verify with `git stash` or a fresh clone.
3. `flutter test --coverage` — review the `lib/core/utils/money.dart`,
   `lib/data/models.dart` and `lib/features/activity/` lines.
4. The **RLS suite** from `SUPABASE_MIGRATION_PLAN.md` §6 M3 against a real
   Postgres, as user A against user B's crib.
5. The **concurrency test** from §6 M6 — two simultaneous settlements that
   together exceed the debt must yield one success and one rejection.
6. A **device or simulator run** of journeys J1, J5, J8, J10, J13 and J15 —
   the six with no executed UI coverage.
7. A **two-device, two-user** run: user A creates a crib, user B accepts an
   invitation, A adds an expense, B sees it. This is the first real test of
   the product's core promise.
8. A **restart test**: kill and relaunch; confirm the session, the crib and the
   expense are all still there.
9. A **tombstone test**: delete a crib with confirmed settlements; confirm it is
   refused, and that a deleted expense leaves a trail.
10. **Manual security pass**: attempt to read another crib's data by editing an
    id in a request; attempt to replay a settlement request; attempt to log out
    and continue.

---

## 6. Release decision

| Target | Decision | Blocking items |
|---|---|---|
| **Internal prototype demo** | **Ready with explicitly listed limitations** | Usable for product feedback. Data does not persist, there is no real identity, and the overpayment rule is wrong. Must be labelled a prototype. |
| **Closed beta** | **Not ready** | B1–B12. At minimum: real auth, sign-out, the per-pair overpayment rule, the negative-amount fix, a green CI suite, and working "Forgot password" / notifications / join-by-link. |
| **Supabase integration** | **Not ready** | S1–S8. The contracts do not yet express membership-scoped reads, real identity, profile-backed members, non-null ownership, or tombstones. |
| **Production release** | **Not ready** | Every section in §3 has open blockers. Four Critical findings remain: AUD-SEC-01, AUD-SEC-02, AUD-SEC-06, AUD-DAT-01. |

**Overall: Not ready.**

---

## 7. Explicitly not decided

The following are product decisions, not code defects, and the audit did not
resolve them. They must be answered before the schema is frozen, because each
changes a table or a rule (`SUPABASE_MIGRATION_PLAN.md` §2).

| # | Decision | Current behaviour kept | Consequence if unanswered |
|---|---|---|---|
| D1 | Single-use or reusable invitations | Single-use (documented) | `invitations.max_uses` / `use_count` columns |
| D2 | Do invitees enter a `pending` membership | No — accepted directly | `crib_members.status` column |
| D3 | The precise settled-history freeze rule | Implemented narrower than the approved rule | The SQL predicate; also whether the code must be widened to match `PRODUCT_RULES.md` §2 or the rule narrowed to match the code |
| D4 | Are confirmed settlements immutable; how is a mistake corrected | Immutable | `compensates_settlement_id` |
| D5 | Per-pair or net overpayment | **Net (wrong per the approved rule)** | The balance function and `pairwise_debt` |
| D6 | Placeholder members | Kept | `crib_members.user_id` FK — currently the biggest onboarding blocker |
| D7 | Account deletion: soft or hard, and the retention period | Not implemented | `profiles.deleted_at`, the purge job |
| D8 | Does a removed member keep read-only access to their history | Keeps full access in the current code | The read policies |
| D9 | May an owner delete a crib that has settlements | **Yes, today** | The `delete_crib` RPC — must become a tombstone and a refusal |
| D10 | Device timezone: platform plugin or fixed offset | Fixed offset | `recurring_schedules.time_zone` |

Two additional decisions the audit surfaced that are not on the original list:

| # | Decision | Consequence |
|---|---|---|
| **D11** | Who pays a recurring occurrence after the schedule creator is removed? | `recurring_schedules` needs an explicit payer, or the schedule must be cancelled on removal |
| **D12** | May a member leave a crib, and what happens to their share of settled debts? | `crib_members.left_at` semantics for self-removal; there is no leave path today |

---

## 8. Traceability

| Finding | Document | Section |
|---|---|---|
| AUD-SEC-01, AUD-SEC-02, AUD-SEC-06, AUD-DAT-01 | `SECURITY_AND_DATA_INTEGRITY_FINDINGS.md` | §2, §6 |
| AUD-SEC-03 … AUD-SEC-07 | `SECURITY_AND_DATA_INTEGRITY_FINDINGS.md` | §2 |
| AUD-DAT-02 … AUD-DAT-08 | `SECURITY_AND_DATA_INTEGRITY_FINDINGS.md` | §6 |
| AUD-FIN-01 … AUD-FIN-10 | `COMPREHENSIVE_PRODUCT_AUDIT.md` | §5 |
| AUD-TST-01 … AUD-TST-09 | `COMPREHENSIVE_PRODUCT_AUDIT.md` | §8 |
| AUD-CTRL-01 … AUD-CTRL-05, AUD-UI-01 | `COMPREHENSIVE_PRODUCT_AUDIT.md` | §3 |
| Journey status | `END_TO_END_TEST_MATRIX.md` | §1, §2 |
| Prior-claim reconciliation | `COMPREHENSIVE_PRODUCT_AUDIT.md` | §9 |
| Top-ten actions | `COMPREHENSIVE_PRODUCT_AUDIT.md` | §13 |
| Residual uncertainty | `COMPREHENSIVE_PRODUCT_AUDIT.md` | §14 |
