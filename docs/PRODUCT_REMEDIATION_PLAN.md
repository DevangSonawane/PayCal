# PayCal Remediation Plan

## Milestone 1: Security & data integrity (blocks Supabase)
- Findings: C1, C2, C3, H3, H4, H7
- Areas: repositories, auth, member model
- Acceptance: scoped reads, real auth identity, no hard delete with settlements, scoped idempotency key, FK members, concurrency guards
- Risks: breaking existing tests

## Milestone 2: Financial correctness (blocks launch)
- Findings: H1, H2, H6, M1, M2, M3, M6, M7
- Areas: financial_ledger, money, settlements, recurring
- Acceptance: per-pair overpayment rule, freeze rule refined, negative parse fixed, currency input fixed, removed-member charging blocked or explicit, recurring payer handling

## Milestone 3: Auth, navigation, core journeys
- Findings: C2, H8, M4, M5
- Areas: auth screens, settle UI, member counts, activity filter
- Acceptance: real sign-in/out, recipient-confirm UI, correct counts, crib-scoped activity

## Milestone 4: Usability & error recovery
- Findings: M8, M10, M11, L*
- Acceptance: timezone plugin decision, owner non-null, scheduler perf

## Milestone 5: Visual consistency & accessibility
- Findings: L5 (dark mode optional), overflow, touch targets

## Milestone 6: Performance & maintainability
- Findings: M9 dead code removal, M11

## Milestone 7: Optional enhancements
- Dark mode, push notifications

## Essential v1 vs nice-to-have
Essential: M1-M6 security/financial/auth. Nice-to-have: dark mode, notifications, handle system.
