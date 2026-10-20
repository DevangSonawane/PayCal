# PayCal Product Findings Register

> **Status note (added 2026-10-20).** This register is the **historical** record
> and is preserved unchanged below. It has **not** been re-verified against the
> current code, and several entries are now known to be stale. The
> 2026-10-20 comprehensive audit supersedes it for decision-making:
>
> * `docs/COMPREHENSIVE_PRODUCT_AUDIT.md` — full audit, 37 findings (AUD-*), with
>   the reconciliation of every historical entry in its §9.
> * `docs/END_TO_END_TEST_MATRIX.md` — per-journey execution status.
> * `docs/SECURITY_AND_DATA_INTEGRITY_FINDINGS.md` — threat model, abuse-case
>   matrix, RLS/RPC control map.
> * `docs/RELEASE_READINESS_CHECKLIST.md` — go/no-go gates.
> * `docs/MILESTONE_2_VERIFICATION.md` — the pre-Supabase fixes of
>   2026-10-20 and what they closed.
>
> **Entries below confirmed stale by the 2026-10-20 audit** (the register text
> is left as written, for history):
> * **F-C3** — "delete removes expenses/settlements" is **no longer true**; the
>   current code preserves them. The live defect is different: the delete
>   orphans the financial rows, has no confirmed-settlement guard, and is not a
>   tombstone. See `AUD-SEC-03`.
> * **F-H3** — the idempotency key **is** scoped to the sender with a payload
>   check in the current code. The cross-sender case is merely untested. See
>   `AUD-TST-04`.
> * **F-H5** — events are **not** stamped the literal `'now'`; ISO-8601 strings
>   are used. The live defect is that a display string lives in the domain
>   model. See `AUD-DAT-04` / F-L2.
> * **F-H6** — the repository **does** reject a removed member as a participant;
>   the **domain** rule does not. See `AUD-FIN-03`.
> * **F-H1** — the freeze is narrower than this entry states: a metadata-only
>   edit is allowed. It remains broader than the affected-set rule proposed in
>   `SUPABASE_MIGRATION_PLAN.md` §3.4. See `AUD-TST-04` and the matrix J6 row.
> * **F-H2** — still true, but now with a runtime proof in both directions:
>   a debtor can settle a party they owe nothing to, and a net creditor cannot
>   settle at all. See `AUD-FIN-02`.
> * **F-M4** — the cited locations are stale; the current sites are
>   `split_share_editor.dart:179` and `crib_detail_screen.dart:216`. See
>   `AUD-FIN-08`.
> * **F-M9** — `balance_engine.dart` is still referenced by
>   `test/widget_test.dart`; only `settle_sheet.dart` is genuinely dead.
> * **F-M1** — still true, and the working-tree refactor does not fix it.
>   See `AUD-FIN-01`.
>
> **Also corrected by the audit:** `docs/MILESTONE_1_VERIFICATION.md` reports
> "110 passed, 1 failed (golden_probe)". The suite currently passes 112/112 in
> the working tree; the golden failure reproduces only on a clean `HEAD`
> checkout, because the baseline was overwritten **uncommitted**. See
> `AUD-TST-01` and §2 of the comprehensive audit.
>
> **Status after the pre-Supabase fixes of 2026-10-20**
> (`docs/MILESTONE_2_VERIFICATION.md`). The findings below are closed:
>
> | ID | Closed by | Note |
> |---|---|---|
> | **F-M1** | `AUD-FIN-01` | `Money.tryParseToMinor('-0.50')` returns **-50**. The sign belongs to the whole amount, overflow is rejected instead of wrapping, and `Money.format` is exact integer arithmetic. `test/money_test.dart`. |
> | **F-H2** | `AUD-FIN-02` | A settlement is validated against the **debt of the pair**, not the net position of the sender. `FinancialLedger.pairwiseDebt` is the new rule. `test/settlement_pairwise_debt_test.dart`. |
> | **F-H6** | `AUD-FIN-03` | The domain rule now matches the repository: `validateNewExpense` and `validateNewSettlement` require active members, the record level rules keep the history valid. `test/active_member_enforcement_test.dart`. |
> | **F-C1** | `AUD-SEC-01` | Every repository read is scoped to the memberships of the signed-in member. `test/repository_isolation_test.dart`. **The client is not a security boundary — the RLS policies are still required.** |
> | **F-H1** | `AUD-TST-04` | The share comparison compared map objects instead of their content, so every expense counted as changed and the freeze blocked every edit. It is compared by content now, and a metadata-only edit is allowed. |
> | **F-H7** (partly) | `AUD-FIN-02` | The key is scoped to the sender and the payload is compared, and the cross-sender case now has a test. The database lock is still missing. |
>
> **Update 2026-10-20 (Milestone 2B).** Closed since the table above:
> F-M7 (the recurring payer — a schedule now has an explicit payer, it pauses
> when the payer leaves and the owner assigns an active member again,
> `test/recurring_pause_test.dart`), and the "no delete-crib affordance"
> statement of F-C3 and `AUD-CTRL-04` — **the delete does exist**, in
> `lib/features/cribs/crib_edit_sheet.dart`; the earlier audit missed it. The
> golden baseline was verified and regenerated, so `AUD-TST-01` is closed.
> The Crib Owner permissions are audited in
> `docs/ADMIN_ROLE_AND_PERMISSION_AUDIT.md`.
>
> Still open and **not** touched by that milestone: F-C2 (no authentication),
> F-C3 (hard delete, no tombstone), F-H4 (inventable members), F-H5/F-L2
> (activity timestamp), F-H8 (no recipient confirmation in the UI), F-M2
> (currency symbol), F-M3 (money formatting, partly), F-M4, F-M5, F-M6, F-M7,
> F-M8, F-M10, F-M11, F-L1, F-L3, F-L4, F-L5, F-L6, F-L7, and the whole
> backend half of F-C1.

## Critical

### F-C1 Unscoped repository reads
- Severity: Critical
- Category: Security/Authorization
- Evidence: in_memory_repositories.dart list/get; migration plan C1
- Expected: reads scoped to caller memberships
- Actual: all cribs/expenses/settlements/activity returned
- Impact: data leakage across cribs
- Blocks Supabase: yes

### F-C2 No real authentication; client-owned user id
- Severity: Critical
- Category: Auth
- Evidence: AuthRepository.signIn keeps id; screens navigate without auth
- Blocks Supabase: yes

### F-C3 Owner can hard-delete crib with financial records
- Severity: Critical
- Category: Data integrity
- Evidence: CribRepository.delete removes expenses/settlements
- Blocks launch: yes

## High

### F-H1 Settlement freezes all edits in crib
### F-H2 Legitimate settlement rejected (net vs per-pair)
### F-H3 Idempotency key unscoped to sender/payload
### F-H4 Members can be invented (placeholder members)
### F-H5 Activity events stamped 'now'
### F-H6 Removed member can still be charged
### F-H7 No concurrency control
### F-H8 Recipient-confirm flow has no UI

## Medium

### F-M1 Money.tryParseToMinor('-0.50') returns +50
### F-M2 Amount input uses device currency symbol vs crib currency
### F-M3 Money.format float division precision loss
### F-M4 Member counts include removed members (3 sites)
### F-M5 Activity feed shows other cribs' events
### F-M6 expense.update may add removed member; settlements counterparty may be removed
### F-M7 Recurring occurrence paid by creator even after removal; any member triggers generation
### F-M8 Device timezone stored as fixed offset (DST)
### F-M9 Dead code: balance_engine.dart, settle_sheet.dart
### F-M10 Crib.ownerId nullable; fallback to first admin
### F-M11 nextDueDateAfter O(n) up to 5000

## Low

### F-L1 MemberRole has no admin; role stored twice
### F-L2 ActivityEvent.time is display string in domain
### F-L3 Split editor controllers not rebuilt on member change
### F-L4 invitations.getById readable by anyone (token metadata leak)
### F-L5 Only light theme
### F-L6 Logout doesn't call signOut
### F-L7 Account deletion toast-only

## Cross-references to the 2026-10-20 comprehensive audit

| Historical ID | Current status | Superseding finding |
|---|---|---|
| F-C1 | **Fixed on the client 2026-10-20** — every read is scoped to the memberships of the signed-in member. The database still has to enforce it | `AUD-SEC-01` |
| F-C2 | Still true (Critical) | `AUD-SEC-02`, `AUD-SEC-06` |
| F-C3 | Stale as written | `AUD-SEC-03`, `AUD-DAT-02` |
| F-H1 | **Fixed 2026-10-20** — the share comparison was comparing map objects instead of their content, so every edit counted as a financial change | `AUD-TST-04`; matrix J6 |
| F-H2 | **Fixed 2026-10-20** — a settlement is validated against the debt of the pair | `AUD-FIN-02` |
| F-H3 | Fixed in code, now tested | `AUD-TST-04` |
| F-H4 | Still true (High) | `AUD-SEC-04` |
| F-H5 | Stale as written | `AUD-DAT-04`, `AUD-DAT-06` |
| F-H6 | **Fixed 2026-10-20** — the domain rule now matches the repository | `AUD-FIN-03` |
| F-H7 | Still true — needs a DB lock | `AUD-FIN-02` (concurrency) |
| F-H8 | Still true — no UI | matrix J8; `AUD-CTRL-05` neighbourhood |
| F-M1 | **Fixed 2026-10-20** | `AUD-FIN-01` |
| F-M2 | Still true | `AUD-FIN-07` |
| F-M3 | Partly fixed — the formatting is exact integer arithmetic now, the device currency symbol is still wrong | `AUD-FIN-06`, `AUD-FIN-07` |
| F-M4 | Still true, locations stale | `AUD-FIN-08` |
| F-M5 | Still true | `AUD-DAT-04` |
| F-M6 | **Fixed 2026-10-20** at the domain layer and in the repository | `AUD-FIN-03` |
| F-M7 | Still true | `AUD-FIN-04` |
| F-M8 | Still true | `AUD-FIN-10` |
| F-M9 | Partially stale | — |
| F-M10 | Still true | `AUD-FIN-09`, `AUD-SEC-07` |
| F-M11 | Still true (Low) | `AUD-FIN-05` |
| F-L1 | Still true | `AUD-SEC-07` |
| F-L2 | Still true | `AUD-DAT-04` |
| F-L3 | Still true | matrix J5 |
| F-L4 | Still true | `AUD-SEC-05` |
| F-L5 | Still true | `AUD-UI-01` |
| F-L6 | Still true | `AUD-SEC-02` |
| F-L7 | Still true | `AUD-SEC-02` |
| — | New in this audit | `AUD-DAT-01` (no persistence), `AUD-DAT-05` (stale screens), `AUD-DAT-07` (partial mutation — positive), `AUD-DAT-08` (retries), `AUD-TST-01`…`AUD-TST-09`, `AUD-CTRL-01`…`AUD-CTRL-05` |
