# PayCal Security and Data Integrity Findings

**Date:** 2026-10-20
**Scope:** Threat model, abuse cases, privacy exposure, and the control map that
must be enforced by the database (RLS / transactional RPCs) rather than by the
client.
**Evidence basis:** Read-only code inspection + executed test suite
(112 passed, 0 failed) + runtime reproductions performed in an isolated copy.
**The backend does not exist.** Every production-security claim that depends on
server-side enforcement is marked **UNTESTABLE — no backend** and must not be
reported as working.

---

## 1. Threat model

### 1.1 Actors

| Actor | Capability assumed |
|---|---|
| **Curious member** | A legitimate signed-in user of one crib. Reads IDs from the UI, the network, or a shared screenshot. |
| **Malicious member** | A legitimate member of one crib who tampers with the client, replays requests, or forges IDs. |
| **Non-member** | Has an account, or has only an invitation token. |
| **Token holder** | Possesses an invitation link (possibly forwarded, guessed, or captured). |
| **Attacker with the database** | Has a dump or log access. |
| **Compromised client** | Full control of the Dart code and the request layer. |

### 1.2 The central fact of this codebase

> "The Flutter client, custom URI parameters, local repository checks, and
> `FinancialLedger` validation are not authorization boundaries. The backend must
> authenticate the caller and enforce every rule below."
> — `docs/BACKEND_SECURITY_REQUIREMENTS.md:3-6`

Every check in `lib/data/in_memory_repositories.dart` is a **client-side**
check. A patched client, a replayed HTTP request, or a guessed identifier
bypasses **all** of them simultaneously. The Dart checks are valuable for fast
feedback and for shaping the UI; they are **not** a security control and must
not be counted as one in any release sign-off.

**AUD-SEC-06 (Critical, confirmed).** This is the root cause that upgrades
every other client-side rule below from "High" to "Critical in production".

---

## 2. Findings

### AUD-SEC-01 — No read is scoped to the caller's memberships · **Critical** · Confirmed

**User impact:** any signed-in user who learns or guesses a crib id can read
every expense description, amount, payer and participant list, every
settlement, and every activity event of a crib they are not a member of.
Financial and personal data of unrelated households is exposed.

**Evidence**

| Call | Location | Behaviour |
|---|---|---|
| `cachedCribs` | `in_memory_repositories.dart:129` | returns every crib in the store |
| `CribRepository.list()` | `:131` | returns `cachedCribs` |
| `CribRepository.getById(id)` | `:133`, `:269-271` | scans all cribs, no membership check |
| `cachedExpenses` | `:286` | every expense of every crib |
| `ExpenseRepository.list({cribId})` | `:288-290` | when `cribId` is null, returns **all** expenses |
| `ExpenseRepository.getById(id)` | `:292-295`, `:393-395` | returns any expense by id |
| `cachedSettlements` | `:447-448` | every settlement |
| `SettlementRepository.list({cribId})` | `:450-454` | unscoped when `cribId` is null |
| `cachedEvents` | `:569` | every activity event |
| `ActivityRepository.list({cribName})` | `:571-576` | unscoped when `cribName` is null |
| `ActivityRepository.record()` | `:579-581` | requires only a signed-in user |
| `InvitationRepository.getById(token)` | `:759-761` | **no auth check at all** |

The screens inherit this: `HomeScreen`, `CribsScreen`, `SearchScreen` and
`ActivityScreen` all iterate `cachedCribs` unfiltered, and `SearchScreen`
prints `${b.members.length} members` for cribs the user is not in.

**Why it blocks Supabase integration.** The repository interface has **no
notion of "my cribs"**, so there is nothing for an RLS policy to bind to. This
is not a "add RLS later" task — every list/get contract must become
membership-scoped *first*, otherwise the database either has to be trusted
blindly or the adapter has to re-implement the filter in Dart, which is the
same client-side check that is not a boundary.

**Existing coverage:** none. **No test in the suite creates a second crib** —
cross-crib leakage is structurally undetectable.
**Worse:** `test/in_memory_repositories_test.dart` **asserts the unscoped
behaviour as correct** — `:110 expect(await expenses.list(), isEmpty)`;
`:142`, `:145`, `:146` call `list()` with no `cribId`.

**Required database controls**
* `listMyCribs()` — `select … from cribs join crib_members where left_at is null`
* Mandatory `cribId` on every expense/settlement/activity read
* `was_member(crib_id)` / `is_active_member(crib_id)` `SECURITY DEFINER`
  helpers with a pinned `search_path`
* RLS `using` clauses on `cribs`, `crib_members`, `expenses`, `expense_shares`,
  `settlements`, `invitations`, `recurring_schedules`, `recurring_occurrences`,
  `activity_events`, `profiles`
* `security_invoker = true` on the balance view, or the view bypasses RLS

**Remediation:** Supabase_Migration_PLAN §5 — add `listMyCribs()`, make `cribId`
mandatory, scope every `getById`; delete the tests that assert the unscoped
behaviour (AUD-TST-05).

---

### AUD-SEC-02 — No authentication; the user id is client-owned; "Log out" does not sign out · **Critical** · Confirmed

**User impact:** the app has no identity. Any user can reach every screen.
Tapping "Log out" leaves the session intact. A user believes they have ended a
session; they have not.

**Evidence**

| Behaviour | Location |
|---|---|
| `signIn(email, displayName)` validates the email *format* only and sets `AuthUser(id: _store.currentUser?.id ?? 'me', …)` | `in_memory_repositories.dart:96-113` |
| `signOut()` sets `_store.currentUser = null` — **never called from the UI** | `:116`; `profile_screen.dart:551-564` |
| `updateProfile` calls `signIn` (not an update) | `:119-122` |
| `SignInScreen._signIn` waits 600 ms and navigates to `MainShell` **without calling `auth.signIn`** | `sign_in_screen.dart:33-44` |
| The Google button navigates directly | `sign_in_screen.dart:124-128` |
| `CreateAccountScreen` waits 450 ms, navigates with a hard-coded `email: 'you@gmail.com'`, `google: true` | `create_account_screen.dart:24-38` |
| `VerifyEmailScreen` simulates polling; `google == true` auto-advances | `verify_email_screen.dart:50-66` |
| "Log out" → confirm sheet → navigate to `WelcomeScreen`; **`signOut()` is never called** | `profile_screen.dart:551-564` |
| "Delete account" → confirm sheet → toast `Account deletion requested`; **nothing is called** | `profile_screen.dart:527-548` |

**Consequence.** `auth.uid()` is the only identity Postgres RLS can trust, and
nothing in this app can produce one. The string `'me'` is client-controlled and
would be trivially spoofable in any implementation that copied this design. A
`"me"` user id is also the basis of the actor identity recorded in the activity
feed (AUD-DAT-06).

**Existing coverage:** none. No test asserts that a client cannot claim
another identity, that a session exists, that a session is restored, or that
sign-out revokes anything.

**Required database controls**
* Real `signUp` / `signIn` (email+password, OAuth, or OTP) with a session the
  client cannot forge
* A session gate on app launch; `supabase.auth.onAuthStateChange` for
  sign-in/sign-out
* `auth.uid()` — never a client-supplied `user_id` — in every RPC
* Server-side session revocation on sign-out and on account deletion
* `delete_my_account()` as a `service_role` operation: anonymise the profile,
  revoke sessions and refresh tokens, revoke the user's invitations, close
  memberships, keep the financial history, write an `account_deleted` event

**Remediation:** top action #1.

---

### AUD-SEC-03 — Crib deletion orphans financial history and has no settlement guard · **High** · Confirmed

**Note on the prior record.** The historical finding **F-C3 as written in
`docs/PRODUCT_FINDINGS.md`** — "`CribRepository.delete` removes
expenses/settlements" — is **refuted by the current code**. `delete` preserves
both (comment at `in_memory_repositories.dart:204`; asserted by
`test/crib_operations_test.dart:180-182`). The finding is stale in two places
and the code is stale in one:

* `lib/data/repositories.dart:42` still documents *"Deletes the crib **and the
  records that belong to it**"* — the interface contract lies.
* `docs/SUPABASE_MIGRATION_PLAN.md:67-72` and
  `docs/BACKEND_READINESS_AUDIT.md:56` ("delete cascades") describe behaviour
  that no longer exists.

**The live defect.** `in_memory_repositories.dart:196-206`:
* Removes the crib row while its `expenses`, `settlements` and membership rows
  keep pointing at a `cribId` that no longer resolves → **orphaned financial
  records**.
* Has **no guard** against deleting a crib that has `confirmed` or
  `selfManaged` settlements. The owner (the only admin in v1) can therefore
  delete the container that other members' financial history lives in, leaving
  the audit trail pointing at unreachable records.
* Uses a **hard delete**, not a tombstone. `PRODUCT_RULES.md` §2 lists
  tombstone/reversal as explicitly **Open**; `SUPABASE_MIGRATION_PLAN.md` §3.2
  already specifies `cribs.deleted_at` and D9 recommends refusing the delete.
* Records a `crib_deleted` activity event whose `cribId` points at the deleted
  crib.

**Existing coverage:** `crib_operations_test.dart` covers owner-only delete,
stale version and not-found — but **not** "delete a crib that has settlements",
which is the case that matters.

**Required database controls**
* `delete_crib(id, expected_version)` as a `SECURITY DEFINER` RPC that
  **soft-deletes** (`deleted_at = now()`), never hard-deletes
* Refuse the delete when any `confirmed`/`self_managed` settlement exists
  (D9) — or require a compensating settlement, per D4
* RLS must not expose deleted cribs (`where deleted_at is null`)
* Never mutate historical payer/participant ids; keep the immutable trail

**Remediation:** top action #6.

---

### AUD-SEC-04 — Members can be invented · **High** · Confirmed

**User impact:** a crib can contain people who do not exist, and a member can
be added under a display name they never claimed. The roster — which drives
who is charged and who can be paid — becomes unreliable.

**Evidence**
* `Member` (`lib/data/models.dart:8-66`) accepts an arbitrary `id` and `name`
  with no validation.
* `CribRepository.addMember` (`in_memory_repositories.dart:208-234`) takes a
  **client-supplied `Member`** and never checks that the id belongs to a real
  user.
* `FirstCribScreen` manufactures placeholder members `ob1…obN` / "Housemate N"
  from the household-size step.
* `CreateCribPopup` lets the creator type a **free-text** name.
* `scan_flow.dart:200-210` copies a **display name** from one crib into
  another — so a person can be added to a crib under a name they did not
  choose.

**Why it blocks Supabase.** A FK from `crib_members.user_id` to `profiles.id`
makes invented members impossible. That is a good outcome, but it means the
placeholder onboarding flow **must be replaced** with real invitations first,
or the migration breaks the primary onboarding path. The migration map already
anticipates this: `add_member(crib_id, user_id)` with the name resolved from
`profiles`, never from the client.

**Required database controls**
* `crib_members.user_id → profiles.id` (NOT NULL), no name column
* `add_member(crib_id, user_id)` RPC: owner-only; the user must exist; the
  display name comes from `profiles`
* A `UserDirectoryRepository.lookup(handle)` contract to resolve a handle to a
  user id

**Remediation:** top action #5.

---

### AUD-SEC-05 — Invitation metadata is readable by anyone · **Medium** · Confirmed

**Evidence:** `in_memory_repositories.dart:759-761` — `getById(token)` requires
**no** user and no membership and returns `cribId` and `createdById` for any
token. The token is the only credential, so its metadata should not be
readable to anyone. Tokens are also stored in plaintext (acceptable in memory;
the database must store only `sha256(token)`).

**Required database controls**
* `token_hash bytea unique` — the raw token is returned once, at creation
* `accept_invitation(raw_token)` RPC does the lookup, the revocation/expiry/
  use-count checks and the membership check in **one transaction**
* No direct read policy on `invitations` for a token holder
* Rate-limit acceptance attempts; audit creation, acceptance, rejection and
  revocation

**Remediation:** part of top action #9; also a standing item in the migration.

---

### AUD-SEC-07 — Membership data model stores the role twice · **Low** · Confirmed

`Member.isAdmin` is a getter over `role == MemberRole.owner`
(`lib/data/models.dart:33`), but the constructor still accepts an `isAdmin`
parameter, and `MemberRole` has no explicit `admin` value. With the owner as
sole admin this is consistent today, but the model permits a contradiction, and
the fallback in `_requireOwner` (`in_memory_repositories.dart:867-873`) then
picks "the first member whose role is `owner`" — which is a **role-based
fallback for a missing owner**, not a permission check.

**Required database control:** `cribs.owner_id uuid not null`; `crib_members`
stores **no role** (the owner role is derived from `cribs.owner_id`), per
`SUPABASE_MIGRATION_PLAN.md` §3.2.

---

## 3. Abuse-case matrix

| # | Abuse | Expected (approved rules) | Actual | Verdict |
|---|---|---|---|---|
| 1 | Read another user's crib by changing an ID | 403 / no rows | The client now answers `notFound`; the database has to refuse it | **CLOSED ON THE CLIENT** (AUD-SEC-01) |
| 2 | Read another crib's expenses by id | 403 / no rows | The client now answers `notFound`; the database has to refuse it | **CLOSED ON THE CLIENT** (AUD-SEC-01) |
| 3 | Read another crib's settlements | 403 / no rows | The client now answers `notFound`; the database has to refuse it | **CLOSED ON THE CLIENT** (AUD-SEC-01) |
| 4 | Read another crib's activity feed | 403 / no rows | The feed is scoped to the caller's cribs now | **CLOSED ON THE CLIENT** (AUD-SEC-01, AUD-DAT-04) |
| 5 | Forge an owner id | Rejected | `ownerId` is a client-supplied string on `Crib`; `create` requires `owner == actor.id`, so a forged owner is rejected **only because the ids are compared** — the owner is still client-owned | **BROKEN by construction** (AUD-SEC-02) |
| 6 | Forge a member id / invent a member | Rejected; FK to a real profile | Accepted | **BROKEN** (AUD-SEC-04) |
| 7 | Join with an expired token | Rejected | Rejected (`:790-817`) | **HELD** |
| 8 | Join with a revoked token | Rejected | Rejected | **HELD** |
| 9 | Reuse an accepted (single-use) token | Rejected | Rejected | **HELD** |
| 10 | Guess an invitation token | 32 chars from `Random.secure()` | Not guessable | **HELD** |
| 11 | Use `paycal://crib/<id>` to join | Rejected | Rejected with a toast | **HELD** |
| 12 | Use `paycal://batch/<id>` to join | Rejected | Rejected with a toast | **HELD** |
| 13 | Edit another member's expense | Rejected | Rejected (creator/payer only) | **HELD** (client-side only) |
| 14 | Delete another member's expense | Rejected | Rejected | **HELD** (client-side only) |
| 15 | Edit another's settlement | Rejected | Only the recipient confirms, only the sender cancels; confirmed is immutable | **HELD** (client-side only) |
| 16 | Charge a removed member | Rejected | Rejected by the repository **and** by the domain rule now | **HELD** (AUD-FIN-03) |
| 17 | Add/remove a member without being the owner | Rejected | Rejected | **HELD** (client-side only) |
| 18 | Create/revoke an invitation without being the owner | Rejected | Rejected | **HELD** (client-side only) |
| 19 | Remove the owner | Rejected | Rejected | **HELD** |
| 20 | Change the currency after activity | Rejected | Rejected | **HELD** (client-side only) |
| 21 | Change the payer or currency of an expense | Rejected | Rejected | **HELD** (client-side only) |
| 22 | Overwrite a concurrent edit | Conflict | Conflict, single-process only | **HELD in-process; UNTESTABLE across devices** |
| 23 | Replay a settlement request | Same settlement returned | Returned for the same sender + key + payload | **HELD for settlements only**; every other mutation has no idempotency key (AUD-DAT-08) |
| 24 | Overpay a settlement | Rejected | Rejected against the debt of the **pair** | **HELD** (AUD-FIN-02) |
| 25 | Reuse a settlement idempotency key from another sender | Rejected | Rejected | **HELD** (F-H3 fixed) |
| 26 | Sign out and keep using the app | Session revoked | The in-memory `currentUser` **remains set**; "Log out" only navigates | **BROKEN** (AUD-SEC-02) |
| 27 | Delete an account and expect the data to go | Anonymised, history kept | A toast; nothing happens | **NOT IMPLEMENTED** (AUD-SEC-02) |
| 28 | Restore an old session | Session expired / refresh | No session model exists | **NOT IMPLEMENTED** |
| 29 | Read private data from logs / errors / notifications | No PII in logs | No logging framework is used; the error surface is `RepositoryException.message`, which contains crib and member context | **NO OBSERVED LEAK; no logging discipline defined** |
| 30 | Read the notification content of another user | Rejected | No notifications are ever scheduled | **N/A** |
| 31 | Owner hard-deletes a crib to destroy another member's expenses | History preserved / tombstoned | The crib is removed and the expenses are **orphaned** (not destroyed, not reachable) | **PARTIAL** (AUD-SEC-03) |
| 32 | Expense delete destroys the audit trail | Tombstone + reversal | The row is removed; the activity event survives and points at nothing | **PARTIAL** (AUD-DAT-03) |
| 33 | Invent an activity actor | Server-stamped actor | The actor is the client-owned `'me'` | **BROKEN** (AUD-DAT-06) |
| 34 | Read a crib's expense amounts across currencies | Never aggregate across currencies | The crib has one currency and the repository enforces it; the **UI** shows the wrong symbol but the stored currency is right | **HELD**, with a UX defect (AUD-FIN-07) |
| 35 | Drain the rate limit on invitation attempts | Rate-limited | **No rate limiting exists**; UNTESTABLE without a backend | **UNTESTABLE — no backend** |
| 36 | Change the signed-in user's id in a request | Rejected | **UNTESTABLE — no backend**; the Dart check compares client-supplied ids | **UNTESTABLE — no backend** |

**Score: 22 held (all client-side only), 12 broken or partial, 4 untestable or
not implemented.**

> **After the pre-Supabase fixes of 2026-10-20:** the five rows that were
> broken on the client (1–4, 16, 24) are now closed on the client side. The
> score becomes **28 held, 7 broken or partial, 4 untestable or not
> implemented** — but every "held" row is still held by the **client**, which
> is not a boundary. The RLS policies and the RPC authorisation checks of
> `docs/SUPABASE_MIGRATION_PLAN.md` §4 are what turn them into a real
> control, and they are untestable until a database exists.

---

## 4. Privacy and data-handling observations

* **Nothing is persisted** — so nothing leaks from a device store. This is a
  privacy accident of the prototype, not a privacy design.
* **`OnboardingDraft` persists to SharedPreferences** — it stores the draft
  onboarding state (including the name, role and household size) in
  **plaintext, unencrypted**, with no cleanup on account deletion.
  `ACCOUNT_DELETION.md` §4 requires "Device-local profile data … is cleared on
  the device" — **not implemented**.
* **`AppSettings` caches the display name and email** on the device. The same
  clearing requirement applies — **not implemented**.
* **No analytics, no crash reporting, no logging framework** is wired up, so
  there is no observed telemetry leak. There is also **no telemetry policy**,
  so the first SDK added will not have a rule to follow.
* **Activity events carry the client-owned actor id** and the crib id of every
  event. With AUD-SEC-01 unfixed, the activity store is the most sensitive
  aggregate in the app: it maps *who did what* across *every crib in the
  store*.
* **Invitations expose `createdById` and `cribId`** to any caller (AUD-SEC-05).
* **The error surface** (`RepositoryException.message`) includes crib and
  member context and is surfaced verbatim in toasts. Once a backend is added,
  server error bodies must not be shown raw to the user — the current code
  shows `e.message` directly, so a backend message would leak internals.

---

## 5. Supabase control map

> **Update 2026-10-20.** The client now scopes every read to the
> memberships of the signed-in member
> (`test/repository_isolation_test.dart`, 17 tests). That closes the *client*
> half of `AUD-SEC-01` and makes the interface the RLS policies can bind to.
> **It does not close the finding.** The checks are still in the client, so a
> modified client bypasses every one of them. The database half of the table
> below is still the whole security boundary, and it is still untestable until
> a database exists.
>
> **Update 2026-10-20 (Milestone 2B).** The Crib Owner permissions are now
> proved at every layer: `test/owner_permissions_test.dart` (34 cases) proves
> that every owner-only operation is refused for a member, a stranger and a
> signed-out caller, and `test/owner_ui_gating_test.dart` proves that a
> member is not even offered the owner-only controls. The full matrix is in
> `docs/ADMIN_ROLE_AND_PERMISSION_AUDIT.md`. The recurring payer adds one
> more owner-only operation, `assign_recurring_payer`, which the database has
> to enforce with `is_crib_owner`. The recurring schedules table needs a
> nullable `payer_id` — a null payer is a paused schedule.

What **must** live in the database, and what may stay client-side.

| Operation | Client-side check (UX only) | **Required database enforcement** |
|---|---|---|
| Read crib | — | `RLS using (was_member(id))` |
| Read members | — | `RLS using (was_member(crib_id) or user_id = auth.uid())` |
| Read expenses | — | `RLS using (is_active_member(crib_id) or (was_member(crib_id) and (payer_id = auth.uid() or created_by = auth.uid())))` |
| Read shares | — | RLS via an `exists` on the parent expense |
| Read settlements | — | `RLS using (was_member(crib_id))` |
| Read activity | — | `RLS using (was_member(crib_id))` + server `occurred_at` |
| Read profiles | — | own row + users sharing a crib |
| Create crib | actor becomes owner | `create_crib` RPC — `owner_id = auth.uid()`, membership + activity in one transaction |
| Update crib | owner, version | `update_crib` RPC, owner-only, compare-and-swap on `version` |
| Delete crib | owner, version | `delete_crib` RPC — **soft delete**, refuse if confirmed settlements exist |
| Add member | owner, not duplicate | `add_member(crib_id, user_id)` RPC — owner-only, FK to `profiles`, name from `profiles` |
| Remove member | owner, not the owner | `remove_member` RPC — owner-only, sets `left_at`, never mutates history |
| Create expense | payer is active, splits valid | `create_expense` RPC — `payer_id = auth.uid()`, every participant an **active** member, currency match, **share sum == total** enforced in the transaction, payer must participate |
| Update expense | creator/payer, version | `update_expense` RPC — compare-and-swap, payer/currency immutable, **§3.4 affected-set freeze predicate**, metadata-only allowed |
| Flag dispute | active member | `flag_dispute` RPC — never changes money, never blocked by the freeze |
| Delete expense | creator/payer | `delete_expense` RPC — **tombstone** (`deleted_at`), never a hard delete |
| Create settlement | sender only | `create_settlement` RPC — `from_user_id = auth.uid()`, `status` ∈ {`pending`,`self_managed`}, `pg_advisory_xact_lock(hashtext(crib_id))`, overpayment checked against **`pairwise_debt`**, unique `(crib_id, requested_by, idempotency_key)` |
| Confirm settlement | recipient only | `confirm_settlement` RPC — `to_user_id = auth.uid()`, `status = 'pending'`, amount immutable |
| Cancel settlement | sender only | `cancel_settlement` RPC — status change only |
| Create invitation | owner only | `create_invitation` RPC — server-generated 32 random bytes, returns the raw token **once**, stores `sha256(token)` |
| Accept invitation | member eligibility | `accept_invitation` RPC — one transaction, re-checks revocation/expiry/use-count/membership, rate-limited, audited |
| Revoke invitation | owner only | `revoke_invitation` RPC |
| Recurring schedule | owner/creator | `create_recurring_schedule` RPC — validates the IANA zone against `pg_timezone_names` |
| Generate occurrences | active member | `generate_due_occurrences` RPC — `insert … on conflict (schedule_id, occurrence_date) do nothing`; the expense is created **only** if the occurrence row was actually inserted |
| Account deletion | — | `delete_my_account()` — `service_role` only; anonymise, revoke sessions, revoke invitations, close memberships, keep history, write the event |

**Client-side checks that must be duplicated server-side** (from
`docs/BACKEND_SECURITY_REQUIREMENTS.md`): every owner-only check, every
active-member check, every version check, every financial validation, every
idempotency constraint.

**Invariant the client must never be trusted for:** the client may send a
`crib_id`, a `user_id`, a `payer_id`, a `status`, an `amount_minor` or a
`timestamp`. The server must derive identity from `auth.uid()`, derive
timestamps from `now()`, derive `status` transitions from the current row
state, and re-derive every monetary quantity from stored rows.

---

## 6. Data integrity findings

### AUD-DAT-01 — No durable persistence · **Critical for production** · Confirmed

`PayCalRepositories.instance` holds a single `InMemoryStore` in memory
(`in_memory_repositories.dart:38-45`). A fresh process re-seeds from
`MockData`. **All financial data is lost on restart.** Only `OnboardingDraft`
(SharedPreferences) and some `AppSettings` values persist.

This is a prototype characteristic rather than a code bug, but it means **no
claim that "the app works" is supportable**, and it is the architectural
reason no end-to-end journey can be executed (see
`docs/END_TO_END_TEST_MATRIX.md` J14).

**Do not equate the in-memory store with persistence.** A backend adapter behind
the same interfaces would fix this; nothing in the UI needs to change. The
`PayCalRepositories.forStore` seam already exists for exactly this.

---

### AUD-DAT-02 — Crib delete orphans dependent rows · **High** · Confirmed — see AUD-SEC-03.

### AUD-DAT-03 — Expense delete is a hard delete · **Medium** · Confirmed

`ExpenseRepository.delete` removes the row and records an `expense_deleted`
activity event. The financial effect is correct (balances recompute from the
remaining rows) and the audit trail keeps a record — but the trail points at a
record that no longer exists, and there is no reversal. `PRODUCT_RULES.md` §2
lists this as **Open** ("Tombstone / reversal instead of a hard delete"), so
this is a **product decision recorded as a defect**, not a code bug. It must
not ship to production without a decision.

---

### AUD-DAT-04 — The activity feed is a global, unformatted log · **Medium** · Confirmed

* `ActivityEvent.time` is a **display `String`** living in the domain model
  (`lib/data/models.dart:406`), and `activity_screen.dart:86` renders it raw —
  so the feed displays `2026-10-20T15:26:49.644862`.
* `ActivityRepository.list()` returns the entire cache when `cribName` is null
  (`:571-576`) → the "All" filter is a **feed across every crib in the store**,
  including cribs the user is not a member of.
* `activity_test.dart:36` asserts only `expect(event.occurredAt, isNotNull)`,
  which is **trivially true** because `occurredAt` defaults to
  `DateTime.now()` (`models.dart:403`).

**Required:** the display label must be derived in the UI from `occurredAt`; the
`time` field must be removed from the domain model; the feed must be scoped by
membership; the timestamp must come from the server.

---

### AUD-DAT-05 — Screens do not all react to repository mutations · **Medium** · Confirmed

Updates propagate through `onSaved` / `onDone` / `setState` callbacks and by
re-reading the repository cache. `MainShell` keeps its four tabs mounted in an
`IndexedStack`, so a tab can display stale data after a mutation performed in a
pushed route until it is rebuilt. There is no reactive invalidation layer.

**Impact:** a user adds an expense from the crib detail screen and returns to
Home; whether the new expense is visible depends on which tab is mounted. This
is a correctness-of-display problem that a backend will not fix — it needs an
invalidation/refresh strategy (or a reactive store).

---

### AUD-DAT-06 — Actor identity in the activity trail is client-owned · **Medium** · Confirmed

`_recordActivity` (`:892-914`) records `actorId: actor.id`, which is the
client-controlled `'me'` string. `PRODUCT_RULES.md` §8 requires every event to
carry an accurate actor. Until AUD-SEC-02 is fixed, the actor field is
unreliable by construction. The server must write the activity event inside the
same transaction as the mutation, using `auth.uid()`.

---

### AUD-DAT-07 — Failures do not leave partially mutated state · **Positive** · Confirmed by inspection

Repositories validate before mutating and throw `RepositoryException`; the UI
applies local state changes only after a successful call. Expense creation
(validates → stores → records activity) is the one place where a throw
*between* the store write and the activity write would leave a partial state —
low risk, but it is exactly the pattern that a transactional RPC eliminates.

---

### AUD-DAT-08 — Retries can duplicate operations · **Low/Medium** · Confirmed

* Only `SettlementRepository.create` has an idempotency key, and that key is
  derived from `DateTime.now().microsecondsSinceEpoch` — so a **retry** (a
  second request at a later moment) produces a **different** key and creates a
  **second settlement**. Same-sender same-key replay is protected; genuine
  retry is not.
* Expense creation has **no** idempotency key (id = `e${millisecondsSinceEpoch}`).
* Member add and invitation create have none.
* Most submit paths are not debounced — only `SignInScreen` has a `_busy` guard.
  A double tap can create two expenses.

**Required:** a client-generated request id on **every** mutation, a unique
constraint per `(crib_id, requested_by, idempotency_key)`, and a payload
comparison on replay that raises a conflict rather than returning the wrong row.

---

### AUD-FIN-03 — Domain participant activeness is inconsistent · **High** · Confirmed — see `docs/COMPREHENSIVE_PRODUCT_AUDIT.md` §5.2.

`financial_ledger.dart:93` (`validateExpense` → `crib.members`) vs `:134`
(`validateSettlement` → `crib.activeMembers`). The repository layer rejects a
removed participant (`:410-417`), so the repository is safe; the **domain rule
that `PRODUCT_RULES.md` §2 names as the single source of money truth is not**.
The SQL mirror would inherit whichever rule is copied, so this must be fixed
**before** the schema is written, not after.

### AUD-FIN-02 — Overpayment uses net, not per-pair · **High** · Confirmed — see `docs/COMPREHENSIVE_PRODUCT_AUDIT.md` §5.2.

### AUD-FIN-04 — Recurring payer policy · **Medium** · Confirmed

`generateDue` sets `payerId: schedule.createdById` (`:685`) and is callable by
any active member (`:649`). A removed creator leaves a schedule that keeps
charging a departed member. `PRODUCT_RULES.md` §5 does not decide the payer
policy — this is a **missing product rule** that must be decided before the
schema (`recurring_schedules.recipient_id` / `created_by`) is frozen.

---

## 7. Production-security claims that CANNOT be tested (no backend exists)

These must **never** be reported as working:

* RLS policies, `SECURITY DEFINER` RPCs, `auth.uid()`-derived identity
* Server-side share-sum enforcement, per-pair debt in SQL
* Advisory/row locks; compare-and-swap on `version`
* Concurrent settlement serialisation
* Token hashing, invitation rate limiting, audit logging of auth/invitation/mutation attempts
* Session revocation on sign-out or account deletion; service-role isolation
* Account-deletion anonymisation and the retention purge
* Encryption in transit and at rest; secrets never shipped in the app
* Cross-device consistency; realtime propagation between members
* Server timestamps and server-generated ids
* Idempotency under a real network retry
* Any claim that data survives a reinstall, a crash, or a device change

---

## 8. What is sound and must be preserved

Recorded so a remediation does not regress them:

| Control | Evidence |
|---|---|
| Legacy `paycal://crib/<id>` and `/batch/<id>` links grant nothing | `deep_link.dart:132-140`; `ui_flows_test.dart` |
| Invitation tokens: 32 chars, `Random.secure()`, 62-char alphabet | `in_memory_repositories.dart:833-841`; `invitations_test.dart` |
| Acceptance validates token → revoked → expired → used → crib → membership | `in_memory_repositories.dart:790-817`; 11 tests |
| Invitations are single-use; already-accepted members keep membership on revoke | `invitations_test.dart`; `in_memory_repositories.dart:820-831` |
| Invitation create/revoke are owner-only | `in_memory_repositories.dart:734-739`, `:820-831` |
| QR membership changes go only through owner-only `addMember` | `scan_flow.dart:200-210`; `membership_test.dart:9-26` |
| Removed members lose write access but keep history | `membership_test.dart` (12 tests) |
| The owner cannot be removed; the owner cannot be added as a member | `in_memory_repositories.dart:216-218`, `:244-246` |
| Membership cannot be changed through `CribRepository.update` | `in_memory_repositories.dart:170-175` |
| Expense edit/delete restricted to the creator or the payer; any member may dispute | `expense_permissions_test.dart` (11 tests) |
| Payer and currency are immutable; currency is locked once activity exists | `expense_permissions_test.dart`; `crib_operations_test.dart` |
| Settlement status transitions are sender/recipient-restricted; confirmed is immutable | `settlements_test.dart` (11 tests) |
| Idempotency is scoped to the sender with a payload check | `in_memory_repositories.dart:469-488` |
| Financial ledger math and split rules | `financial_ledger_test.dart` (9 tests) |
| Recurring date rules, occurrence idempotency, catch-up | `recurring_test.dart` (17 tests) |
| The `PayCalRepositories.forStore` seam for a backend adapter | `in_memory_repositories.dart`; `SUPABASE_MIGRATION_PLAN.md` §5 |
