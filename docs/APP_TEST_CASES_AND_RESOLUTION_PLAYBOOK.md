# PayCal app test cases and resolution playbook

**Date:** 2026-10-20  
**Purpose:** a practical backlog for taking PayCal from its current Flutter
prototype to a dependable shared-expense product. It covers more than 100
user, failure, and abuse cases, including the important question: *what happens
when an owner wants to leave a crib?*

## Read this first

The financial rules and in-memory repository tests are a useful base, but they
do **not** prove a production workflow. The app currently has no real identity,
durable database, server-side authorization, or network retry behaviour. A
modified client can bypass client checks. The source of truth for the eventual
backend must be database constraints/RLS plus transactional RPCs, as outlined
in `SUPABASE_MIGRATION_PLAN.md`.

The test cases below use these priority labels:

- **P0**: data loss, money loss, privacy/security, or a launch blocker.
- **P1**: a core workflow or material trust issue.
- **P2**: important UX, resilience, or support coverage.

For each case, automate the rule at the lowest useful level (unit/RPC), then
cover the most important path in an integration/device test. For every rejected
write, assert both the correct error and that **no partial state changed**.

## Product decisions required before implementation

| Decision | Recommended v1 rule | Why |
| --- | --- | --- |
| Member leaves with an open debt | Block self-leave until all pairwise debt involving that member is zero; offer **Settle up** first. | A departed user must not leave an uncollectable payable/receivable. |
| Owner leaves a crib | Owner cannot leave until they transfer ownership to one selected active member, who explicitly accepts. No automatic successor. | Prevents an ownerless crib and surprise privilege escalation. |
| Owner deletes their account | For every active crib, transfer ownership through the accepted flow or tombstone/archive the crib; never hard-delete shared history. | Account deletion cannot strand shared data. |
| Removed-member access | Keep read-only history access in v1; revoke all writes. | Lets a person see and settle their history while protecting current activity. |
| Crib deletion | Tombstone/archive only; prohibit hard delete when financial history exists. | Preserves the ledger and audit trail. |
| Expense correction after settlement | Preserve original; permit metadata edits; correct monetary errors with an explicit reversing/correction entry. | Keeps settled/auditable history trustworthy. |
| Invitations | Single-use, hashed opaque tokens, expiry/revocation, and rate limits. | Least surprising and safest v1 model. |

## A. Identity, onboarding, and account lifecycle (TC-001–TC-015)

| ID | Scenario / expected result | Priority | How to solve and prove it |
| --- | --- | --- | --- |
| TC-001 | New email sign-up creates exactly one account/profile. | P0 | Use Supabase Auth plus a profile trigger; test duplicate-email response and profile creation atomically. |
| TC-002 | Wrong password, unverified email, expired verification link, and reset-password link are handled safely. | P0 | Implement Auth flows/server redirects; device-test each error and never disclose whether an unknown email exists. |
| TC-003 | Logout revokes local session and returns to signed-out state. | P0 | Call `signOut`, clear secure/local caches, and restart the app in the test. |
| TC-004 | Relaunch restores a valid session but not an expired/revoked one. | P0 | Use auth session refresh; integration-test restart, remote revocation, and token expiry. |
| TC-005 | A user cannot claim another user's id by changing client payloads. | P0 | Derive actor exclusively from `auth.uid()` in RLS/RPC; run malicious direct-API tests. |
| TC-006 | Google/email sign-in maps to one profile without duplicate cribs/memberships. | P1 | Use stable auth UUID and provider-linking rules; test linked identities and conflict handling. |
| TC-007 | Onboarding can be abandoned and resumed without creating placeholder people or duplicate cribs. | P1 | Persist only an onboarding draft; create the crib once through an idempotent RPC. |
| TC-008 | Invalid names, blank names, very long names, Unicode/emoji and whitespace normalize correctly. | P2 | Add shared server/client validation and boundary/property tests. |
| TC-009 | Notification permission allow, deny, deny-then-enable, and unsupported platform all remain usable. | P2 | Request actual OS permission, persist preference, and test simulator/device branches. |
| TC-010 | Deep link arrives while signed out. | P1 | Store only the invite token as pending navigation; authenticate, then explicitly validate/accept. |
| TC-011 | Deep link arrives when the app is cold, backgrounded, or already open. | P1 | Use platform deep-link integration tests; make token handling idempotent. |
| TC-012 | Account deletion requires recent authentication and clear confirmation. | P0 | Add authenticated deletion RPC and re-auth prompt; test cancel, confirm, and session revocation. |
| TC-013 | Account deletion clears local profile/cache but preserves/anonymises shared ledger identity. | P0 | Transactionally deactivate profile, revoke tokens/invites, end memberships, anonymise display data; test history remains balanced. |
| TC-014 | Re-registration after deletion follows a documented policy. | P1 | Decide soft-delete reuse/restore versus a fresh identity; test both allowed and refused outcomes. |
| TC-015 | A data-export request contains only the caller's permitted data. | P2 | Add authenticated export job with membership scoping and audit event; test a foreign crib is absent. |

## B. Cribs, roles, joining, leaving, and owner departure (TC-016–TC-035)

| ID | Scenario / expected result | Priority | How to solve and prove it |
| --- | --- | --- | --- |
| TC-016 | Creator becomes the crib owner; exactly one active owner exists. | P0 | `cribs.owner_id NOT NULL` + create RPC; constraint/RPC test. |
| TC-017 | Non-members cannot list, discover, or fetch a crib by guessed id. | P0 | Membership RLS; test with two users and direct REST/SDK calls. |
| TC-018 | A normal member cannot rename crib, edit categories/currency, manage invites, or remove members. | P0 | Owner-only RPCs/RLS; test UI hiding *and* forged requests. |
| TC-019 | Owner can rename/categories update with optimistic version conflict feedback. | P1 | Version compare-and-swap in RPC; simulate two-device stale writes. |
| TC-020 | Currency can change only before all financial activity. | P0 | DB check inside update RPC against expenses/settlements; test activity and no-activity paths. |
| TC-021 | A real user is added only by accepted invite or verified profile lookup—not a typed placeholder. | P0 | Foreign key to `profiles`; remove placeholder-member onboarding; test invalid/unknown user. |
| TC-022 | Removing a member is soft, records `left_at`, and preserves their old ledger rows. | P0 | Membership state transition + activity event transaction; test balances and history after removal. |
| TC-023 | A removed member cannot create/edit/delete/dispute new records or manage the crib. | P0 | Active-membership checks in every write RPC; test each mutation using their session. |
| TC-024 | A removed member's permitted read-only history is scoped to their former crib only. | P1 | RLS policy explicitly includes historical membership for reads; test read/no-write and foreign crib denial. |
| TC-025 | Owner cannot remove themself through the remove-member endpoint. | P0 | Reject `member_id == owner_id`; test forged request. |
| TC-026 | **Member self-leave with zero outstanding debt** soft-removes them, pauses their recurring payer schedules, and revokes current invites as appropriate. | P0 | Add `leave_crib` RPC; lock membership/schedules, verify pairwise debt is zero, write events, test retry. |
| TC-027 | **Member self-leave with any receivable/payable** is blocked and gives a precise settle-up path. | P0 | Compute pairwise debts in the same transaction; test partial, mutual, and multi-person debts. |
| TC-028 | A leaving member cannot bypass TC-027 with offline/stale UI or direct API calls. | P0 | Server-side check with row lock; race a settlement and leave request in an integration test. |
| TC-029 | **Owner starts transfer** to one active member; target sees who/which crib and must accept. | P0 | Add `ownership_transfers` pending record or a two-phase RPC; test target rejection, expiry, and cancellation. |
| TC-030 | **Owner completes transfer then leaves** only after successor accepts and the owner has zero pairwise debt. | P0 | Transactionally change `owner_id`, record audit events, then call leave flow; test no moment with zero/multiple owner. |
| TC-031 | Owner cannot transfer ownership to removed, non-member, deleted, or self user. | P0 | Validate active membership and distinct user server-side; malicious-request tests. |
| TC-032 | Two simultaneous ownership-transfer attempts cannot elect two owners. | P0 | Lock crib row/version; only one pending transfer allowed; concurrency integration test. |
| TC-033 | Owner account deletion requires completed transfer for every active crib, or archival/tombstoning by a documented policy. | P0 | Preflight deletion report; block deletion until resolved; test multiple cribs and partial completion. |
| TC-034 | Archiving hides a crib from normal current views but leaves permitted history/audit readable. | P1 | Add `archived_at`/tombstone state and RLS; test restore/access/search. |
| TC-035 | Deleting a crib never destroys financial rows, settlements, or activity. | P0 | Replace hard delete with owner-authorized tombstone and retention policy; test attempted hard delete after settlement. |

## C. Invitations and deep links (TC-036–TC-047)

| ID | Scenario / expected result | Priority | How to solve and prove it |
| --- | --- | --- | --- |
| TC-036 | Only active owner creates an invitation with future expiry. | P0 | Owner RPC plus server timestamp; test member/removed/signed-out callers. |
| TC-037 | Raw invite token is high entropy, shown once, and only its hash is stored. | P0 | Generate server-side, store SHA-256 hash; test DB never returns raw token. |
| TC-038 | Unknown, malformed, expired, revoked, and consumed tokens reveal no crib metadata. | P0 | Return same safe invalid response; test token enumeration and `getById` denial. |
| TC-039 | A crib id or old `paycal://crib/...` link never grants membership. | P0 | Route only `invite/<token>` to acceptance; regression-test legacy routes. |
| TC-040 | Valid invite acceptance is explicit, signed-in, single-use, and creates one active membership. | P0 | Transaction locks invitation + membership; test double-click and two-device race. |
| TC-041 | Existing/previously removed member accepts invite according to policy without duplicate membership rows. | P1 | Prefer reactivation with a fresh joined event; test existing active, removed, and deleted profile. |
| TC-042 | Revocation blocks future accept immediately but keeps prior joiners. | P0 | Atomic revoked timestamp check; test revocation/accept race. |
| TC-043 | Invite expiry uses server time, not device clock/timezone. | P0 | `now()` inside RPC; test client clock skew. |
| TC-044 | Repeated share/create actions do not make multiple active invitations unexpectedly. | P1 | Define reuse vs rotate rule; use idempotency key and UI busy state. |
| TC-045 | Invitation creation/validation/acceptance are rate-limited and audited. | P1 | DB/edge rate limiter plus activity/security logs; abuse test token guessing. |
| TC-046 | An invitation to an archived/deleted crib cannot be accepted. | P0 | Check crib lifecycle state in acceptance transaction. |
| TC-047 | Copy/share failure leaves a recoverable, non-secret UI state. | P2 | Test unsupported share sheet/clipboard failure and revocation/rotation option. |

## D. Expenses, split rules, and corrections (TC-048–TC-067)

| ID | Scenario / expected result | Priority | How to solve and prove it |
| --- | --- | --- | --- |
| TC-048 | Expense amount is positive integer minor units; negative, zero, overflow, malformed decimals rejected. | P0 | `bigint` DB validation plus shared parser; property tests around boundaries. |
| TC-049 | Expense currency equals crib currency and UI displays the crib symbol. | P1 | Server equality check; pass crib currency to every amount control; widget test USD/INR. |
| TC-050 | Only active member who is the payer can create an expense. | P0 | RPC derives actor and checks active payer; forged actor/payer test. |
| TC-051 | All new split participants are distinct active members in that crib. | P0 | Validate shares in a transaction; test removed/foreign/duplicate IDs. |
| TC-052 | Shares add exactly to total and have no negative amounts. | P0 | DB/RPC aggregate validation; property/fuzz tests. |
| TC-053 | Equal split remainder is deterministic and documented. | P1 | Keep current payer-first rule; unit test every remainder/participant ordering. |
| TC-054 | Percentage split totals exactly 10,000 basis points; rounding is deterministic. | P1 | Keep integer basis-point implementation; test 99.99%, 100.01%, and rounding edges. |
| TC-055 | Exact/percentage editor updates safely after membership changes while open. | P1 | Rebuild controllers from active members or block submit/reload; widget test remove member mid-edit. |
| TC-056 | Creator/payer can edit allowed fields; others cannot. | P0 | Update RPC checks actor; test creator≠payer and direct API. |
| TC-057 | Stale expense edit returns conflict and lets user reload/compare rather than silently overwrite. | P0 | Version column/compare-and-swap; two-client integration test. |
| TC-058 | A dispute is available to active members and changes no money. | P1 | Immutable dispute metadata/audit row; test balances exactly unchanged. |
| TC-059 | Metadata correction after settlement follows approved rule; money correction is an explicit reversal/correction. | P0 | Use append-only correction records; test existing settlements remain explainable. |
| TC-060 | Deleting an expense is a tombstone/reversal, never a ledger hole. | P0 | Add `deleted_at`/reversal event; test audit and balance derivation policy. |
| TC-061 | Expense creation has client idempotency and disabled-submit UI. | P0 | Unique `(crib, actor, idempotency_key)` with payload hash; double-tap/offline retry test. |
| TC-062 | Expense date accepts valid historical dates and defines future-date policy. | P2 | Decide whether future dates allowed; server validation/timezone test. |
| TC-063 | Description/category input is escaped, bounded, searchable, and safe to render. | P1 | Length limits and plain-text rendering; test HTML-like, RTL, emoji, and long input. |
| TC-064 | One-person crib expense produces zero debt and no bogus transfer. | P1 | Ledger unit + UI empty-settle test. |
| TC-065 | Last active member removal is prevented if it would invalidate a pending expense flow. | P1 | Server state check / form reload; test concurrent editor and removal. |
| TC-066 | An expense cannot be created in archived/tombstoned crib. | P0 | Lifecycle check in RPC and UI gating. |
| TC-067 | Cross-crib expense id guessing never exposes or mutates the foreign record. | P0 | RLS and RPC membership join; direct SDK test. |

## E. Balances, settlements, and money integrity (TC-068–TC-082)

| ID | Scenario / expected result | Priority | How to solve and prove it |
| --- | --- | --- | --- |
| TC-068 | Balance calculation is reproducible from immutable ledger rows and totals to zero. | P0 | Database function + property tests for random ledgers. |
| TC-069 | Pairwise debt, not only net balance, limits a settlement. | P0 | Use pairwise debt function under transaction; test cycles/mutual debts. |
| TC-070 | Sender, receiver, amount, currency, and active membership are validated for new settlement. | P0 | Server-only actor checks; test same person, removed/foreign recipient, wrong currency. |
| TC-071 | Pending settlement is created only by sender; recipient alone confirms; sender alone cancels. | P0 | Status-transition RPC and tests for every invalid transition. |
| TC-072 | UI can create pending requests and recipient can confirm/cancel visibly. | P1 | Build inbox/detail actions; widget/device test both accounts. |
| TC-073 | `confirmed`/`selfManaged` settlement is immutable; correction is compensating record. | P0 | Reject update/delete final rows; test audit and net effect. |
| TC-074 | Partial settlement reduces only that pair's debt. | P0 | Pairwise ledger tests; test remaining suggested transfer. |
| TC-075 | Overpayment is rejected even when two devices submit at the same time. | P0 | Lock relevant crib/debt rows or serializable RPC transaction; concurrent integration test. |
| TC-076 | Same idempotency key + same payload returns original settlement; different payload conflicts. | P0 | Unique sender-scoped key + payload hash; retry test. |
| TC-077 | Different senders can safely use the same idempotency key. | P1 | Scope uniqueness by actor; test isolation. |
| TC-078 | Pending/cancelled settlements do not change balances; confirmed/self-managed do. | P0 | Ledger status filter and regression tests. |
| TC-079 | Suggested transfers are actually permissible pairwise debts. | P0 | Generate from pairwise debt graph; property test every suggestion. |
| TC-080 | Currency/precision/large-value formatting never uses floating point. | P1 | Integer minor units end-to-end; formatter boundary tests. |
| TC-081 | Settlement requires current ledger version/snapshot and explains conflict. | P1 | Snapshot/version parameter or transaction retry; test expense added between quote and submit. |
| TC-082 | Settle-up screen is refreshed after remote mutation and never records someone else's transfer as the current user. | P1 | Realtime/refetch + actor-bound RPC; two-device UI test. |

## F. Recurring payments and time (TC-083–TC-094)

| ID | Scenario / expected result | Priority | How to solve and prove it |
| --- | --- | --- | --- |
| TC-083 | Only owner creates/cancels/assigns payer for a recurring schedule. | P0 | Owner RPC/RLS tests. |
| TC-084 | Schedule stores IANA timezone, local time, anchor day, frequency, payer and recipient. | P1 | Store validated IANA id, not device offset; test serialization. |
| TC-085 | Month-end and leap-day schedules use last valid day then resume anchor. | P1 | Keep scheduler tests; add DB/job parity tests. |
| TC-086 | DST spring/fall behaviour is specified and stable. | P1 | Choose gap/ambiguous-time policy; zone-based tests. |
| TC-087 | Each due occurrence is generated once despite reopen, retry, or worker retry. | P0 | Unique `(schedule_id, due_date)` occurrence key; concurrent test. |
| TC-088 | Background/server job generates while the app is closed—or UI explicitly promises on-open only. | P1 | Prefer scheduled server job; test closed-app catch-up and observability. |
| TC-089 | Cancel stops only future generation; past generated expenses remain. | P0 | Status/effective time check; test cancellation after catch-up. |
| TC-090 | Removing/leaving payer pauses schedule, clears payer, records event, and creates no charged occurrence. | P0 | Same transaction as membership change; test immediately due schedule race. |
| TC-091 | Reassigning an active payer resumes only from the next due date, with no paused-window backlog. | P0 | Persist `resume_from`; test long pause and month boundary. |
| TC-092 | Removed/non-member cannot be assigned as payer or recipient. | P0 | Active-member validation; direct API test. |
| TC-093 | Recurring generated expense obeys normal expense validations and idempotency. | P0 | Reuse internal ledger/RPC path; test deleted/archived crib and currency. |
| TC-094 | Schedule edit policy is explicit (future only vs immutable/cancel-recreate). | P2 | Pick one, audit it, and test edits around already-generated occurrences. |

## G. Activity, search, UI state, reliability, and security (TC-095–TC-115)

| ID | Scenario / expected result | Priority | How to solve and prove it |
| --- | --- | --- | --- |
| TC-095 | Every material mutation writes one ordered audit event with server actor/time/target. | P0 | Transactional server event insert; test rollback creates no event. |
| TC-096 | Activity/read/search are always membership-scoped, including "All" filters. | P0 | RLS plus query predicates; two-user test with same crib name. |
| TC-097 | Activity timestamps render locale-aware relative/absolute time; raw domain strings are not stored. | P2 | Store `timestamptz`; format in UI; widget tests timezone/locale. |
| TC-098 | Search never leaks foreign crib/member/expense metadata and handles empty/loading/error state. | P0 | RLS-backed server search; security/integration tests. |
| TC-099 | App restart preserves server data and restores consistent screens. | P0 | Replace in-memory store with repository/cache; install/restart integration test. |
| TC-100 | Tabs and detail screens refresh after a mutation made elsewhere. | P1 | Stream/repository invalidation or refetch-on-resume; navigation test. |
| TC-101 | Offline reads are labelled stale; offline writes queue safely or fail clearly—never pretend success. | P1 | Define offline strategy, durable operation queue/idempotency; airplane-mode tests. |
| TC-102 | Timeout, 429, 5xx, DNS failure, and malformed response have retry-safe UX. | P1 | Typed error mapper/backoff; integration mocks and idempotent replay tests. |
| TC-103 | Double tap, back/submit race, and app kill during submit create at most one mutation. | P0 | Busy state + idempotency keys; device test. |
| TC-104 | All server errors map to useful messages without exposing SQL, tokens, or other users' data. | P1 | Error contract/redaction tests. |
| TC-105 | RLS denies select/insert/update/delete for every foreign or inactive-member row. | P0 | Run a role-by-role Supabase SQL test suite in CI. |
| TC-106 | Direct table writes cannot bypass financial/role rules. | P0 | Revoke direct writes; expose audited `SECURITY DEFINER` RPCs only; malicious SDK tests. |
| TC-107 | Sensitive tokens/session data are not logged, cached in plain text, or included in crash reports. | P0 | Secret scanning/redacted logging/secure storage tests. |
| TC-108 | API rate limits protect sign-in, reset, invite validation, and writes without blocking normal retry. | P1 | Per-actor/IP policy; load/abuse tests. |
| TC-109 | Accessibility: screen reader labels, focus order, contrast, text scaling, and touch sizes work. | P1 | Flutter semantics/golden/device accessibility tests. |
| TC-110 | Light/dark theme and narrow/wide/mobile/web layouts remain usable. | P2 | Responsive goldens at representative breakpoints. |
| TC-111 | Localization uses correct money/date/plural rules without changing stored values. | P2 | Locale matrix tests. |
| TC-112 | Analytics/crash reporting use no raw financial descriptions, amounts, emails, or invite tokens. | P0 | Privacy review + event-schema tests. |
| TC-113 | Database backup/restore preserves ledger, memberships, tombstones, and idempotency uniqueness. | P0 | Staging restore drill and reconciliation query. |
| TC-114 | Migration from prototype/mock data cannot duplicate or lose financial records. | P1 | One-off migration dry run, checksums, and rollback plan. |
| TC-115 | Release rollback does not break a newer schema or replay a queued write twice. | P1 | Expand/contract migrations, feature flags, staging rollback test. |

## Execution plan

1. **Decide lifecycle rules first**: approve the owner-transfer and self-leave
   rules above, archive/tombstone semantics, and account-deletion outcome.
2. **Build the production boundary**: Supabase Auth, profiles, membership RLS,
   append-only/audited RPCs, server timestamps, and durable storage. Do not
   treat Flutter repository checks as authorization.
3. **Implement P0 cases before new UI polish**: specifically TC-001–005,
   TC-016–035, TC-036–043, TC-048–052, TC-056–061, TC-068–078, TC-087,
   TC-090–093, and TC-095–107.
4. **Run four suites in CI**: Dart unit/widget tests; Supabase SQL/RLS/RPC
   integration tests; two-account/two-device end-to-end tests; restart/offline
   device tests. Seed each test with isolated users and cribs.
5. **Make the release gate measurable**: every P0 case must be automated and
   passing; no hard delete of ledger data; no client-owned actor ids; no RLS
   bypass; and a successful backup/restore drill.

## Owner-leaves flow: final recommended behaviour

```
Owner taps “Leave crib”
  → app shows outstanding pairwise debt and recurring schedules
  → owner settles their own debt (if any)
  → owner selects an active successor
  → successor accepts (or owner cancels / request expires)
  → server atomically transfers owner_id and records audit events
  → former owner uses normal leave flow; membership becomes inactive
  → former owner retains permitted read-only history; no new writes
```

Never choose a successor automatically, never remove the owner first, and
never solve owner departure by hard-deleting the crib. Those shortcuts create
an ownerless group, a privilege surprise, or broken shared financial history.
