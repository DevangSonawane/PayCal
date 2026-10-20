# PayCal Product Audit

## 1. Application overview and feature inventory

PayCal is a Flutter shared-expense app using in-memory repositories (no backend). 111 tests pass; flutter analyze clean.

### Features present
- Auth: sign-in/create account (prototype, no real auth), verify email, notifications sheet, welcome, onboarding flow, product tour, first crib, invite screen
- Home, Cribs list, Crib detail/edit, Create crib popup
- Expenses: quick add sheet, split share editor, expense detail
- Settlements: settle up sheet, settle sheet (dead)
- Scans: scan flow (QR)
- Activity, Search
- Profile (settings, logout, account deletion)
- Recurring: scheduler
- Deep links, splash

### Screens inventory (25+)
1. SplashScreen (lib/app/splash_screen.dart)
2. WelcomeScreen
3. SignInScreen
4. CreateAccountScreen
5. VerifyEmailScreen
6. NotificationsPage
7. OnboardingFlow
8. ProductTourScreen
9. FirstCribScreen
10. InviteScreen
11. BirthdaySheet
12. MainShell (bottom nav)
13. HomeScreen
14. CribsScreen
15. CribDetailScreen
16. CribEditSheet
17. CreateCribPopup
18. ExpenseDetailScreen
19. QuickAddSheet
20. SplitShareEditor
21. SettleUpSheet
22. SettleSheet (dead)
23. ScanFlow
24. ActivityScreen
25. SearchScreen
26. ProfileScreen
27. DesignGallery

## 2. Screen-by-screen audit summary

All screens reviewed against code. Key recurring issues: no real auth, no loading/empty states in places, member counts include removed members (M4), activity feed shows other cribs' events (M5), money parsing bug (M1), amount input uses device currency (M2).

## 3. Feature-level findings

See PRODUCT_FINDINGS.md. Critical: C1 (unscoped reads), C2 (no auth), C3 (owner destroys records). High: H1-H8. Medium: M1-M11. Low listed.

## 4. Role/permission matrix

- Signed-out: can still reach MainShell via sign-in prototype; no real gating
- Owner: full crib control; can delete crib incl. expenses/settlements (C3)
- Active member: can add expenses, view; cannot edit others' expenses (tested)
- Removed member: still in member list; can be charged (H6); retains history (D8)
- Invited user: joins via token
- Non-member: reads via unscoped list/get (C1)

## 5. Financial integrity findings

- M1 negative parse bug
- M3 float division
- M2 currency mismatch in input
- H2 overpayment rule uses net not per-pair
- H1 freeze too broad
- H3 idempotency key unscoped
- H7 no concurrency control
- Recurring: creator pays even after removal (M7); generation on any member open

## 6. UX/accessibility

- Only light theme (AppTheme.light only, ThemeMode.light) — no dark mode
- No session expiry handling
- Logout doesn't call signOut
- Account deletion is toast-only
- Dead buttons: settle_sheet unused; balance_engine dead

## 7. Performance/reliability

- nextDueDateAfter O(n) up to 5000 (M11)
- Duplicate repository requests possible
- No disposal issues noted beyond controllers

## 8. Tests and missing coverage

111 tests pass. Missing: concurrency, auth, removed-member charging, negative money parse (M1 likely untested), multi-currency.

## 9. Feature status

Complete: ledger calc, repos, invitations structure, recurring scheduler.
Partial: auth, settlements recipient-confirm (no UI), activity (wrong timestamps).
Prototype-only: sign-in, account deletion, member placeholders.
Absent: real Supabase, push notifications, dark mode.

## 10. Recommended changes

See remediation plan.
