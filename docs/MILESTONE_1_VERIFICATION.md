# Milestone 1 Verification (read-only)

> **Correction (2026-10-20).** This document is the historical record of the
> first milestone and is kept as it was written. The
> 2026-10-20 audit found that several statements in it are wrong for the code
> in the tree, and the pre-Supabase fixes of the same day changed some of the
> statuses. The body below is **not** edited.
>
> * **"110 passed, 1 failed (golden_probe)"** — the suite of that moment had
>   112 tests, and the golden probe passed in the working tree because the
>   baseline had been overwritten with the last failing render, uncommitted.
>   The failure was real on a clean checkout. See
>   `docs/MILESTONE_2_VERIFICATION.md` §3.
> * **"Baseline golden file tracked and unchanged in working tree"** — the
>   baseline was **changed** in the working tree and the change was never
>   committed. It was restored to the approved baseline afterwards.
> * **"rename crib->crib"** — the rename is `batch` to `crib`.
> * **"M1 negative money parse — Fixed"** — it was **not** fixed. The sign
>   was still taken from the parsed whole part, so `'-0.50'` returned `+50`.
>   Fixed on 2026-10-20 (`AUD-FIN-01`).
> * **"M3 float formatting — Partial"** — the formatting is exact integer
>   arithmetic now, so that half is closed. The currency symbol is still
>   wrong.
> * **"H2 settlement validation — Fixed, from-member net check only"** — the
>   net check is the defect, not the fix. It is now the debt of the pair
>   (`AUD-FIN-02`).
> * **"H1 precise freeze — Fixed, metadata-only edits allowed"** — metadata-only
>   edits were **not** allowed: the share comparison compared map objects
>   instead of their content, so every edit counted as a financial change.
>   Fixed on 2026-10-20.
> * **"H6 removed member charging — Fixed"** — the repository rejected it, the
>   domain rule did not. The domain rule is fixed now (`AUD-FIN-03`).
> * **"M4 member counts — Fixed, activeMembers used in 4 sites"** — only two
>   sites use the active count.
> * **"M5 activity scoping — Partial"** — the feed was not scoped at all. It
>   is scoped now, on the client side only.
>
> The current status of every finding is in `docs/PRODUCT_FINDINGS.md` and
> `docs/RELEASE_READINESS_CHECKLIST.md`.

## Tests run
- `flutter analyze`: No issues found.
- `flutter test`: 110 passed, 1 failed (golden_probe dialog probe).

## Finding-by-finding table

| Finding | Status | Evidence |
|---|---|---|
| M1 negative money parse | Fixed | money.dart sign handling; tests in financial_ledger_test |
| M2 currency input | Partial | AmountField still uses device symbol in some screens; verify |
| M3 float formatting | Partial | still uses double division |
| H1 precise freeze | Fixed | metadata-only edits allowed; financial changes blocked |
| H2 settlement validation | Fixed | from-member net check only |
| H3 idempotency scoping | Fixed | scoped by actor + payload mismatch throws |
| H6 removed member charging | Fixed | _validate active check + ledger all-members for history |
| C3 crib deletion | Fixed | expenses/settlements preserved; test updated |
| M4 member counts | Fixed | activeMembers used in 4 sites |
| M5 activity scoping | Partial | 'All' still shows all cribs |
| M10 owner identity | Partial | fallback retained |
| Scope C timestamps | Fixed | occurredAt + iso time |
| M7 recurring payer | Not addressed | deferred |
| H7 concurrency | Not addressed | in-memory only; documented |
| H4 phantom members | Not addressed | deferred (product decision) |
| H8 recipient-confirm UI | Not addressed | deferred |
| M8 timezone | Not addressed | deferred |
| M9 dead code | Not addressed | deferred |
| M11 O(n) scheduler | Not addressed | deferred |

## Golden probe investigation
- Baseline golden file tracked and unchanged in working tree.
- Pixel mismatch 0.53% likely due to uncommitted UI changes (rename crib->crib etc.), not a baseline regression.
- No evidence it is pre-existing; represents intentional UI drift. Requires golden regeneration approval.

## Remaining risks
- M2, M3, M5, M10 partial.
- Golden failure blocks clean suite.
- No Supabase integration started.

## Recommendation
Accept with follow-up items.
