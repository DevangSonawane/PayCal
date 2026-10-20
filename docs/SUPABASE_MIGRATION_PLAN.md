# Supabase migration plan (proposal, not implemented)

Status: **proposal for review**. No Supabase code, schema, dependency or
migration exists in the repository yet. This document is the outcome of a
read-only review of the pre-backend milestone plus a design for the production
backend.

Scope note: the goal is a reliable v1 on Supabase. Everything below is chosen
to be the smallest thing that satisfies the approved rules in
`PRODUCT_RULES.md` and the security requirements in
`BACKEND_SECURITY_REQUIREMENTS.md`. No realtime, no edge functions beyond the
one that genuinely needs the service role, no separate balance store.

---

---

# 0. The short version — what to build first

This section is the practical plan. Everything after it is the detailed design
that backs it up.

## 0.1 The minimum that makes the current app work on Supabase

**Nine tables.** Nothing else is needed for the features that exist today.

| Table | Holds | Key columns |
|---|---|---|
| `profiles` | One row per person | `id` (the `auth.users` id), `display_name`, `created_at` |
| `cribs` | A shared group | `id`, `name`, `currency`, `owner_id` **not null**, `categories`, `version`, `deleted_at` |
| `crib_members` | Who is in a crib | `crib_id`, `user_id`, `left_at` (null = active), unique `(crib_id, user_id)` |
| `expenses` | One expense | `crib_id`, `description`, `total_minor`, `currency`, `payer_id`, `created_by`, `category`, `occurred_on`, `disputed_at`, `version`, `deleted_at` |
| `expense_shares` | Who carries what | `expense_id`, `user_id`, `share_minor`, unique `(expense_id, user_id)` |
| `settlements` | A recorded payment | `crib_id`, `from_user_id`, `to_user_id`, `amount_minor`, `status`, `idempotency_key`, `version` |
| `invitations` | An invite token | `crib_id`, `token_hash`, `created_by`, `expires_at`, `revoked_at`, `accepted_by`, `accepted_at` |
| `recurring_schedules` | A recurring transfer | `crib_id`, `created_by`, `recipient_id`, `payer_id` (**null = paused**), `resume_from`, `amount_minor`, `frequency`, `anchor_day`, `local_time`, `time_zone`, `start_date`, `active` |
| `activity_events` | The audit trail | `crib_id`, `actor_id`, `action`, `target_id`, `occurred_at` |

`recurring_occurrences` is a tenth table, but it is an idempotency ledger
rather than user data, and it can wait until the recurring generation moves to
the server.

## 0.2 Authentication

* Supabase Auth with email and password, plus the OAuth provider the sign-in
  screen already offers.
* `profiles.id` is the `auth.users.id`. **The client never sends a user id.**
* The `AuthRepository` in `lib/data/repositories.dart` is the seam: today it
  stores a client-owned id in memory, and the Supabase implementation replaces
  that with the Supabase session. Nothing else in the app changes.
* Sign out has to revoke the session and the sign-in screen has to wait for
  it. Both are currently fake and are listed as launch blockers in
  `docs/RELEASE_READINESS_CHECKLIST.md`.

## 0.3 The three rules the database has to enforce

The client already refuses the wrong actions. **That is a usability feature,
not a security boundary** — a modified client skips every check. These three
rules have to live in the database:

| Rule | How the database enforces it |
|---|---|
| A member only ever sees their own cribs | RLS `using (public.was_member(crib_id))` on every table, plus a `profiles` policy for the own row |
| Only the **Crib Owner** may manage the crib and its members | `public.is_crib_owner(crib_id)` checked inside every `SECURITY DEFINER` RPC — never in the Flutter layer |
| The money is only ever computed from stored rows | The share sum, the pairwise debt and the balance are computed in SQL, inside the transaction that writes the row |

## 0.4 The owner permissions, server-side

The owner-only operations are exactly these RPCs, and each one starts with
`is_crib_owner(crib_id)`:

`update_crib` · `delete_crib` · `add_member` · `remove_member` ·
`create_invitation` · `revoke_invitation` · `create_recurring_schedule` ·
`update_recurring_schedule` · `cancel_recurring_schedule` ·
`assign_recurring_payer`

Two rules that are easy to get wrong:

* **The Crib Owner may correct any expense of their own crib.** The owner is
  not the payer and not the author of most expenses, so
  `update_expense` and `delete_expense` accept
  `payer_id = auth.uid() or created_by = auth.uid() or is_crib_owner(crib_id)`.
  A plain member still cannot touch it.
* **A member may never manage another member's expense.** The rule above is
  the only way in, and it needs the real owner id, not a client-supplied one.

## 0.5 The constraints that protect the money

These are the ones worth getting wrong at your peril:

| Constraint | Why |
|---|---|
| `expense_shares.share_minor >= 0` and the **sum of the shares equals `expenses.total_minor`** | A wrong share sum silently changes every balance |
| `expenses.payer_id` is one of the share participants | The payer carries their own part |
| Every share participant is an **active** member of the crib | A removed member is never charged again |
| `settlements.from_user_id <> to_user_id` and `amount_minor > 0` | No self-payments, no zero amounts |
| `settlements.amount_minor <= pairwise_debt(from, to)` | A member cannot pay off a debt they do not have. **Checked inside the transaction**, not in the client |
| `unique (crib_id, from_user_id, idempotency_key)` on `settlements` | A repeated request returns the original settlement instead of a second one |
| `settlements` in `('pending','confirmed','cancelled','self_managed')` and only a `pending` settlement can become `confirmed` | A confirmed settlement is never rewritten |
| `cribs.owner_id` is `not null` | Without it the owner check falls back to "the first member", which is a hole |
| `cribs.version` and `expenses.version` are compare-and-swap targets | Two devices cannot overwrite each other |

The share sum and the pairwise debt are the two that a plain
`CHECK` constraint cannot express. They are enforced by a **deferred
constraint trigger** on `expenses` (the sum) and by the settlement RPC (the
debt), so the rule holds even if a row is written by a script.

## 0.6 The order to build it in

1. **`profiles` + `cribs` + `crib_members`**, with RLS and the two helper
   functions (`was_member`, `is_crib_owner`). Everything else depends on them.
2. **Auth**: replace `InMemoryAuthRepository` with the Supabase session, and
   make sign-in, sign-out and session restore real.
3. **`expenses` + `expense_shares`**, with the share-sum trigger and the
   `create_expense` / `update_expense` / `delete_expense` RPCs.
4. **`settlements`**, with `pairwise_debt` and the idempotency key.
5. **`invitations`**, with the token hashed server-side.
6. **`activity_events`**, written by the same transaction as the mutation, so
   the actor and the timestamp are the server's.
7. **`recurring_schedules`**, with the payer and the paused state.

Each step is independently useful, and steps 1 to 4 are the minimum for the
app to be a real product.

## 0.7 How to prove it works

The client-side tests in `test/` are a contract suite. The moment the Supabase
implementation exists, the **same tests must run against it**. That is the
mechanism that keeps the two implementations honest, and it is what catches a
rule that was implemented on one side only.

The tests that must pass against the database, and what they prove:

| Test | Proves |
|---|---|
| `repository_isolation_test.dart` | A second member in a second crib cannot read the first crib's data |
| `owner_permissions_test.dart` | Every owner-only operation is refused for a member **by the database** |
| `expense_permissions_test.dart` | The owner may correct any expense of their crib, a member may not |
| `settlement_pairwise_debt_test.dart` | The overpayment rule, the idempotency key and the mismatched payload |
| `active_member_enforcement_test.dart` | A removed member cannot be charged, and the history stays valid |
| `recurring_pause_test.dart` | The payer, the pause and the assignment |

Plus three that only exist on the server:

* two members of the same crib see each other's expenses,
* two devices cannot record the same settlement twice,
* a rejected settlement leaves no trace.

---

## 1. Findings from the code review

Everything below was checked against the current working tree, not against the
milestone report. `flutter analyze` is clean and `flutter test` passes 111
tests — both re-run and confirmed. The findings are about behaviour the tests
do not cover.

### Critical

**C1 — No repository method scopes a read to the caller's memberships.**
`CribRepository.list()`, `getById()` and `cachedCribs` return every crib in
the store. `ExpenseRepository.list()` with no `cribId` returns every expense
of every crib, and `getById()` returns any expense by id.
`SettlementRepository.list()` behaves the same. `ActivityRepository.cachedEvents`
returns every event.

Verified:

```
P2 list() returns [c1, cX]                      # cX = a crib "me" is not in
P2 cachedCribs contains cX: true
P4 expenses.list() no filter -> [mine/c1/Dinner, theirs/cX/Secret dinner]
P4 expenses.getById("theirs") -> Secret dinner 999   # foreign crib
P4 expenses.list(cribId:"cX") -> [Secret dinner]
```

*Consequence.* In production, any signed-in user who learns or guesses a
crib id can read every expense description, amount and member list of that
crib. The screens inherit this: home, cribs, search and the activity feed
all iterate `cachedCribs` unfiltered, and search prints
`${b.members.length} members` for cribs the user is not in.

This is also the reason the migration cannot be "just swap the implementation":
the interface has no notion of *my cribs*, so there is nothing for an RLS
policy to bind to. Every list/get contract has to become membership-scoped
before it can be implemented safely.

**C2 — The app has no authentication, and the current user id is client-owned.**
`AuthRepository.signIn(email, displayName)` does not authenticate: it keeps
`_store.currentUser?.id ?? 'me'` and updates the display name
(`in_memory_repositories.dart:99-113`). `sign_in_screen.dart:_signIn` only
waits 600 ms and navigates. `create_account_screen.dart` navigates to a verify
screen with a hard-coded `you@gmail.com`. "Log out" navigates to the welcome
screen and never calls `signOut()`. "Delete account" shows the toast
`Account deletion requested` and calls nothing.

*Consequence.* `auth.uid()` is the only identity Supabase RLS can trust, and
nothing in the current app can produce one. Every policy in §4 depends on it.
Until real auth exists, the `me` string is a client-controlled value that would
be trivially spoofable in any implementation that copied this design.

**C3 — The crib owner can permanently destroy other members' financial
records.** `CribRepository.delete` removes the crib and then
`_store.expenses.removeWhere(...)` and `_store.settlements.removeWhere(...)`
(`in_memory_repositories.dart:203-206`). Verified: after `delete('c1')`,
`expenses=0, settlements=0` while the activity feed still holds five events
that reference the deleted expenses.

*Consequence.* One member (the owner — the only admin in v1) can erase the
expenses that the other members recorded. The audit trail survives and points
at records that no longer exist. In v1 this needs at minimum a tombstone plus
a guard that refuses to hard-delete a crib that has confirmed settlements.

### High

**H1 — One settlement freezes every expense in the crib, including unrelated
and metadata-only edits.** `_requireSettledHistoryAllows` only asks "does this
crib have any confirmed or self-managed settlement?" and then blocks
`update` and `delete` for the whole crib
(`in_memory_repositories.dart:410-423`). Verified:

```
P5 unrelated expense edit BLOCKED -> conflict: This crib already has a settled transfer.
P5 metadata-only edit BLOCKED     -> conflict   (description/category change only)
```

*Consequence.* The first time anybody settles up in a crib, nobody can ever
fix a typo in an expense again, and new expenses can still be added (create is
not frozen) — so the crib is permanently half-frozen. The rule is also
inconsistent with the dispute path, which is deliberately *not* frozen.

**H2 — A legitimate settlement can be rejected.** The overpayment rule compares
against each member's **net** position in the crib, not their debt to the
counterparty. Verified: with `me` owed 300 by a third member, `a` owes `me`
exactly 500, and `a` records a 500 settlement to `me`:

```
P3 net balances (a owes B exactly 500): {me: 300, a: -500, d: 200}
P3 legitimate settlement REJECTED -> validation: Settlement exceeds the current outstanding balance.
```

*Consequence.* In any crib where the payee is also owed money by somebody
else, the debtor cannot record the settlement they actually owe. Since the
ledger only computes net balances (`FinancialLedger.balances`), the repository
has no way to know the per-pair debt — the check is not just wrong, it is
unimplementable with the current ledger API.

**H3 — The settlement idempotency key is not scoped to the sender or the
payload.** The lookup is `(crib_id, idempotency_key)`
(`in_memory_repositories.dart:452-461`). Verified: a second sender reusing the
same key receives the *first* sender's settlement object instead of their own.

```
P6 other sender reusing the key got -> id=s1 from=a to=me amount=200
   (expected its own s2/400)
```

*Consequence.* A client that retries with a reused key silently receives
somebody else's settlement — wrong payer, wrong amount, wrong status. In
Supabase the same defect becomes a unique-constraint violation instead of a
silent wrong result, which is better but still needs the key scoped as
`(crib_id, requested_by, idempotency_key)` and the payload compared on
replay.

**H4 — Members can be invented.** `CribRepository.addMember` accepts a
client-supplied `Member` with both an id and a display name, and never checks
that the id belongs to a real user. The onboarding flow leans on this:
`first_crib_screen` creates `ob1…obN` / `Housemate N` placeholders and
`create_crib_popup` lets the creator type a free-text name.

*Consequence.* A crib can contain members that do not exist, and the display
name is unverified — the QR flow copies a name from one crib into another, so
a member can be added under a name they never claimed. With a foreign key to
`auth.users` this stops working, which makes it a concrete migration blocker.

**H5 — Every activity event is stamped `time: 'now'`.** `_recordActivity`
hard-codes `time: 'now'` (`in_memory_repositories.dart:879`) while
`occurredAt` uses the device clock, and the activity screen renders
`event.time` (`activity_screen.dart:86`). Verified:
`expense_updated | time='now' | occurredAt=2026-10-20T14:37:15`.

*Consequence.* The activity feed shows "now" for every event it records, so it
carries no information for support or for users. The authoritative field should
be a server timestamp, and the relative label should be derived in the UI.

**H6 — A removed member can still be charged, creating a debt that the normal
flow can never close.** `FinancialLedger.validateExpense` only checks that
participants are *crib members*, and removed members stay in the member list.
Verified: after removing `a`, a new expense whose only participant is `a` is
accepted, and an existing expense can be edited to keep charging `a`.

*Consequence.* The payer carries a debt to somebody who has left and cannot
confirm anything. The ledger stays internally consistent (which was the goal),
but the debt is stranded and the settle-up flow cannot close it.

**H7 — No concurrency control beyond a single-process version check.**
`expense.update` and `crib.update` compare versions, but `settlement.create`
computes balances and then appends with no lock, and nothing protects against
two devices writing at once.

*Consequence.* Two concurrent settlements can both pass the overpayment check
and jointly exceed the debt; two concurrent expense edits can lose one
another's change. These need row locks / compare-and-swap in the database, not
in Dart.

**H8 — The recipient-confirms flow has no UI.** The only settlement the app can
create is `selfManaged` from the settle-up sheet. `pending`,
`SettlementRepository.updateStatus` and the recipient-confirmation rule are
unreachable from the UI.

*Consequence.* A member cannot request a transfer from somebody else and
cannot confirm one that was requested. The v1 rule "only the recipient may
confirm" exists only in the repository.

### Medium

**M1 — Money parsing bug.** `Money.tryParseToMinor('-0.50')` returns **+50**
(`whole = int.parse('-0') = 0`, then `whole >= 0` adds the fraction). Verified:
`P1 tryParseToMinor("-0.50") = 50`. A negative sub-unit amount becomes a
positive expense.

**M2 — The amount input uses the device currency symbol while the amount is
stored in the crib currency.** `AmountField(currencySymbol:
AppSettings.instance.currencySymbol)` in four places, but the expense is
created with `currency: crib.currency`. A USD crib shows `₹` in the input.

**M3 — `Money.format` divides by 100 into a `double`**
(`minorUnits / 100.0`), losing precision above 2^53 minor units, and the
fallback symbol is `'$code '` with a trailing space.

**M4 — Member counts include removed members** in three places
(`home_screen.dart:1044`, `cribs_screen.dart:452`, `search_screen.dart:172`),
while `crib_edit_sheet` shows the active count. Inconsistent.

**M5 — The activity feed shows other cribs' events** (`_filterAll == 'All'`
returns the whole cache).

**M6 — `expense.update` may add a removed member to the shares**, and
`settlements.create` only requires the *actor* to be an active member; the
counterparty may be a removed member (arguably correct — you should still be
able to pay someone who left — but it should be an explicit rule).

**M7 — A recurring occurrence is paid by the schedule creator even after that
creator was removed** (`generateDue` sets `payerId: schedule.createdById`), and
generation is triggered by *any* active member opening the crib.

**M8 — The device timezone is stored as a fixed offset** (`UTC+05:30`), because
the platform exposes no IANA zone id without a plugin. DST is therefore not
followed for the device zone. IANA zones are supported and tested.

**M9 — Dead code.** `lib/domain/balance_engine.dart` and
`lib/features/settlements/settle_sheet.dart` have no callers. The first is a
legacy adapter that duplicates the money API surface.

**M10 — `Crib.ownerId` is nullable** and `_requireOwner` falls back to "the
first admin member". In the database `owner_id` must be `NOT NULL`.

**M11 — `nextDueDateAfter` walks up to 5000 occurrences from the start date on
every call** — O(n) per screen open for an old schedule.

### Low

- `MemberRole` has no `admin` value even though the model has `isAdmin`; with
  the owner as sole admin this is consistent, but the role should be derived,
  not stored twice.
- `ActivityEvent.time` is a display string living in the domain model.
- The split editor builds its exact/percent controllers lazily and never
  rebuilds them if the member list changes while the sheet is open.
- `invitations.getById(token)` is readable by any signed-in user — and by a
  signed-out user — and returns `cribId` and `createdById`. The token is the
  only credential, so its metadata should not be readable to anyone.

### What is already sound

The invitation path is correct in structure: opaque 32-character
`Random.secure` tokens, expiry, revocation, single-use, and the acceptance
validates token → revocation → expiry → use → crib → membership eligibility
before adding a member (`in_memory_repositories.dart:752-791`). `paycal://crib/<id>`
links are rejected rather than granting membership, and the QR flow mutates
membership only through `CribRepository.addMember` (owner-only). The recurring
occurrence key (`schedule id + due date`) and the derived expense id are
deterministic, which is exactly what a unique constraint needs. Removal keeps
history and the ledger keeps validating removed members' expenses — the
approved rule is implemented correctly.

---

## 2. Open product decisions (blocking the schema)

These must be decided before the schema is frozen, because each one changes a
table or a rule.

| # | Decision | Why it blocks | Recommendation |
| --- | --- | --- | --- |
| D1 | Single-use or reusable invitations? | `invitations.max_uses` / `use_count` columns | Keep single-use for v1 (current behaviour); keep the columns so reuse is a config change |
| D2 | Do invitees enter a `pending` membership? | `crib_members.status` column | No. Accept directly; the approved rule says joining goes through an explicit acceptance |
| D3 | Precise rule for editing expenses in a settled crib (fixes H1) | A DB predicate | See §3.4 |
| D4 | Are confirmed settlements immutable, and how is a mistake corrected? | `settlements.status` values, `compensates_settlement_id` | Immutable; corrections are compensating records |
| D5 | Per-pair or net overpayment rule (fixes H2) | The balance function | Per-pair debt |
| D6 | Placeholder members (fixes H4) | `crib_members.user_id` FK | Drop them; onboarding creates the crib and invites real people |
| D7 | Account deletion: soft or hard, and the retention period | `profiles.deleted_at`, a purge job | Soft/anonymise now; the retention period is a legal input and stays a parameter |
| D8 | Does a removed member keep read-only access to their own history? | The read policies | Yes for now; one policy flag away from changing |
| D9 | May an owner delete a crib that has settlements? (fixes C3) | The delete RPC | No — tombstone instead |
| D10 | Device timezone: platform plugin or fixed offset? | `recurring_schedules.time_zone` | Store the IANA id; resolve it on the platform later |

---

## 3. Proposed schema

### 3.1 Principles

1. **One source of truth per fact.** The member's display name lives in
   `profiles` only. `crib_members` stores no name. Balances are always
   derived — there is no balance column and no balance table. The crib
   currency lives in `cribs` only. `crib_members` stores no role: the
   owner is `cribs.owner_id`.
2. **Money is validated in the database.** Amounts are `bigint` minor units.
   The share sum, the membership of every participant and the settlement
   bounds are enforced by functions inside a transaction, not by the client.
3. **Writes go through `SECURITY DEFINER` RPCs**; reads go through RLS. That
   keeps the money rules in one place instead of spread over policies, and
   makes multi-row writes atomic by construction.
4. **Server-side truth.** All timestamps are `timestamptz default now()`.
   The client never sends a timestamp or a user id.

### 3.2 Tables

```sql
-- Identity. auth.users is Supabase's own store; PayCal never reads it
-- directly, only through this profile row.
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null check (length(btrim(display_name)) > 0),
  handle        text unique,                  -- lookup handle for "add member"
  email         text,                         -- only if the product wants a copy
  avatar_seed   text,
  deleted_at    timestamptz,                 -- anonymisation marker
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table public.cribs (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(btrim(name)) > 0),
  currency    char(3) not null,
  categories  text[] not null default '{}',
  owner_id    uuid not null references public.profiles(id),
  version     integer not null default 1,
  deleted_at  timestamptz,                    -- tombstone, never a hard delete
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index cribs_owner_idx on public.cribs(owner_id) where deleted_at is null;

-- One row per membership. left_at IS the active flag: no second boolean can
-- disagree with it. The owner role is derived from cribs.owner_id.
create table public.crib_members (
  crib_id   uuid not null references public.cribs(id) on delete cascade,
  user_id    uuid not null references public.profiles(id),
  joined_at  timestamptz not null default now(),
  left_at    timestamptz,
  primary key (crib_id, user_id)
);
create index crib_members_user_idx on public.crib_members(user_id) where left_at is null;

-- Only the SHA-256 of the token is stored; the raw token is returned once.
create table public.invitations (
  id           uuid primary key default gen_random_uuid(),
  crib_id     uuid not null references public.cribs(id) on delete cascade,
  token_hash   bytea not null unique,
  created_by   uuid not null references public.profiles(id),
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null,
  revoked_at   timestamptz,
  revoked_by   uuid references public.profiles(id),
  accepted_by  uuid references public.profiles(id),
  accepted_at  timestamptz,
  max_uses     integer,                      -- null = single use
  use_count    integer not null default 0
);
create index invitations_crib_idx on public.invitations(crib_id);

create table public.expenses (
  id          uuid primary key default gen_random_uuid(),
  crib_id    uuid not null references public.cribs(id) on delete cascade,
  description text not null,
  total_minor bigint not null check (total_minor > 0),
  currency    char(3) not null,
  payer_id    uuid not null references public.profiles(id),
  created_by  uuid not null references public.profiles(id),
  category    text not null,
  occurred_on date not null,
  disputed_at timestamptz,
  disputed_by uuid references public.profiles(id),
  version     integer not null default 1,
  deleted_at  timestamptz,                   -- tombstone, never a hard delete
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index expenses_crib_idx on public.expenses(crib_id, occurred_on desc)
  where deleted_at is null;

create table public.expense_shares (
  expense_id  uuid not null references public.expenses(id) on delete cascade,
  user_id     uuid not null references public.profiles(id),
  share_minor bigint not null check (share_minor >= 0),
  primary key (expense_id, user_id)
);

create table public.settlements (
  id                  uuid primary key default gen_random_uuid(),
  crib_id            uuid not null references public.cribs(id) on delete cascade,
  currency            char(3) not null,
  from_user_id        uuid not null references public.profiles(id),
  to_user_id          uuid not null references public.profiles(id),
  amount_minor        bigint not null check (amount_minor > 0),
  status              text not null
                      check (status in ('pending','confirmed','self_managed','cancelled')),
  idempotency_key     text not null,
  requested_by        uuid not null references public.profiles(id),
  confirmed_by        uuid references public.profiles(id),
  confirmed_at        timestamptz,
  cancelled_at        timestamptz,
  version             integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (from_user_id <> to_user_id)
);
create unique index settlements_idem_idx
  on public.settlements(crib_id, requested_by, idempotency_key);

-- A schedule is paid by one member at a time. `payer_id is null` means the
-- schedule is paused: it generates nothing until the owner assigns an active
-- member again. `resume_from` is the due date the schedule continues from,
-- so a pause does not create a backlog.
create table public.recurring_schedules (
  id           uuid primary key default gen_random_uuid(),
  crib_id     uuid not null references public.cribs(id) on delete cascade,
  description  text not null,
  amount_minor bigint not null check (amount_minor > 0),
  currency     char(3) not null,
  category     text not null,
  frequency    text not null check (frequency in ('monthly','yearly')),
  recipient_id uuid not null references public.profiles(id),
  created_by   uuid not null references public.profiles(id),
  payer_id     uuid references public.profiles(id),  -- null = paused
  resume_from  date,                                -- continue from here
  time_zone    text not null,                -- IANA zone id
  local_hour   smallint not null check (local_hour between 0 and 23),
  local_minute smallint not null check (local_minute between 0 and 59),
  start_date   date not null,
  anchor_day   smallint not null check (anchor_day between 1 and 31),
  active       boolean not null default true,
  version      integer not null default 1,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- The uniqueness of (schedule_id, occurrence_date) IS the idempotency
-- guarantee for recurring generation.
create table public.recurring_occurrences (
  id              uuid primary key default gen_random_uuid(),
  schedule_id     uuid not null references public.recurring_schedules(id) on delete cascade,
  occurrence_date date not null,
  due_at          timestamptz not null,
  expense_id      uuid references public.expenses(id),
  created_at      timestamptz not null default now(),
  unique (schedule_id, occurrence_date)
);

create table public.activity_events (
  id          bigint generated always as identity primary key,
  crib_id    uuid references public.cribs(id) on delete set null,
  actor_id    uuid references public.profiles(id) on delete set null,
  action      text not null,
  target_type text not null,
  target_id   uuid,
  occurred_at timestamptz not null default now(),   -- server clock
  payload     jsonb not null default '{}'
);
create index activity_crib_idx on public.activity_events(crib_id, occurred_at desc);
```

### 3.3 How balances are derived

Balances are **never stored**. A view computes them from the same three rules
the Dart ledger uses today (payer credited, shares debited, only `confirmed`
and `self_managed` settlements applied):

```sql
create or replace view public.crib_balances with (security_invoker = true) as
select b.id as crib_id,
       m.user_id,
       coalesce(e.credit, 0) - coalesce(e.debit, 0)
         + coalesce(s.credit, 0) - coalesce(s.debit, 0) as net_minor
from public.crib_members m
join public.cribs b on b.id = m.crib_id
left join lateral (
  select sum(x.total_minor) as credit
  from public.expenses x
  where x.crib_id = m.crib_id and x.deleted_at is null and x.payer_id = m.user_id
) e on true
left join lateral (
  select sum(sx.share_minor) as debit
  from public.expense_shares sx
  join public.expenses x on x.id = sx.expense_id
  where x.crib_id = m.crib_id and x.deleted_at is null and sx.user_id = m.user_id
) e2 on true
...
```

(The final view is written out in the migration; the shape above shows the
intent.) `security_invoker = true` is essential — a plain view runs with the
definer's rights and would bypass RLS.

The same rules must also exist as SQL functions for the write paths
(`create_settlement` needs the per-pair debt, see D5). The Dart
`FinancialLedger` stays the client-side mirror of these rules and is used for
optimistic display only; the database is authoritative.

### 3.4 The precise "settled history" rule (fixes H1)

The current rule freezes a whole crib. The precise rule:

> An expense may change its **money** (total, shares, payer) only if no
> confirmed or self-managed settlement exists in which **any member affected
> by that expense** is a party. Metadata (description, category, date, the
> dispute flag) may always change.

Formally, for an expense with payer `p` and participants `S`:

```
affected(e) = {p} ∪ S
frozen(e)   = exists settlement s
              where s.crib_id = e.crib_id
                and s.status in ('confirmed','self_managed')
                and (s.from_user_id in affected(e) or s.to_user_id in affected(e))
```

Consequences:

* A settlement between A and B freezes only the expenses that involve A or B.
  Expenses between C and D stay editable.
* Renaming an expense, fixing a category, or flagging a dispute always works.
* For an edit, the affected set is the union of the old and the new version,
  so an edit cannot move money out of the frozen set.
* The rule is a predicate over two tables and can be expressed in SQL as
  `not exists (...)`, evaluated inside the update RPC.

The same rule should replace `_requireSettledHistoryAllows` in the in-memory
implementation so that both implementations agree (milestone M1).

### 3.5 Per-pair debt (fixes H2 / D5)

The overpayment rule needs "how much does A owe B", which the current net
ledger cannot answer. Add a ledger function that computes the pairwise debt:

```sql
create or replace function public.pairwise_debt(
  p_crib uuid, p_from uuid, p_to uuid
) returns bigint language sql stable as $$
  select coalesce((
    -- what p_from consumed of the money p_to paid:
    -- p_from's share in the expenses p_to paid
    select sum(sx.share_minor)
    from public.expenses x
    join public.expense_shares sx on sx.expense_id = x.id
    where x.crib_id = p_crib and x.deleted_at is null
      and x.payer_id = p_to and sx.user_id = p_from
  ), 0)
  - coalesce((
    -- minus what p_from already settled to p_to
    select sum(s.amount_minor) from public.settlements s
    where s.crib_id = p_crib and s.from_user_id = p_from
      and s.to_user_id = p_to
      and s.status in ('confirmed','self_managed')
  ), 0);
$$;
```

A settlement is rejected when `amount_minor > pairwise_debt(from, to)`.
Partial settlements are allowed; the remainder stays as debt. This removes the
false rejection proven in H2 and makes the rule match the approved wording
("exceeds the sender's outstanding debt to the recipient").

> **Corrected 2026-10-20.** The first version of this function read
> `x.payer_id = p_from and sx_all.user_id = p_to` and computed
> `sum(x.total_minor) - sum(sx_all.share_minor)`. That expression does not
> compute the debt of a pair: it adds up the whole amount of every expense
> the payer paid and subtracts one participant's share, which is the claim of
> the *group* on the payer, not the claim of the participant on the payer.
> With three participants it reported 667 for a debt of 333. The payer and
> share predicates were also the wrong way round for the direction the
> function is called with. The version above is the one the Dart
> implementation follows: `FinancialLedger.pairwiseDebt` in
> `lib/domain/financial_ledger.dart`, covered by
> `test/financial_ledger_test.dart` and
> `test/settlement_pairwise_debt_test.dart`.

> **The SQL must mirror the Dart, and the Dart is now the reference.** A
> settlement is validated against the debt of the *pair*, never against the
> net position of the sender in the crib. Two consequences the schema has to
> keep:
>
> * Only `confirmed` and `self_managed` settlements reduce the debt. A
>   `pending` settlement is a request, the recipient still has to confirm it,
>   so it does not use up the debt yet.
> * The net position and the pairwise debt answer different questions and
>   both are needed. `FinancialLedger.balances` reports the net position,
>   `FinancialLedger.pairwiseDebts` reports who owes whom, and
>   `FinancialLedger.suggestedTransfers` builds the settlement plan from the
>   pairwise debts so that every transfer it suggests is inside the debt of
>   that pair and can therefore be recorded.

---

## 4. The security boundary

### 4.1 Roles

| Role | Where it lives | Used for |
| --- | --- | --- |
| `anon` | Supabase managed | Unauthenticated reads; nothing except `accept_invitation` |
| `authenticated` | Supabase managed | The signed-in user; owns their JWT and their RLS context |
| `service_role` | **server only** | Account deletion, cron jobs. Never in the Flutter app, never in a client query |

The Flutter app ships only the anon key and the user's access token. The
service role key belongs in Edge Function environment variables and in the
Supabase dashboard only.

### 4.2 Helper functions

RLS policies cannot query the tables they protect without recursing, so the
membership predicates live in `SECURITY DEFINER` helpers with a pinned
`search_path`:

```sql
create or replace function public.is_active_member(
  p_crib uuid, p_user uuid default auth.uid()
) returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.crib_members m
    where m.crib_id = p_crib and m.user_id = p_user and m.left_at is null
  );
$$;

create or replace function public.was_member(
  p_crib uuid, p_user uuid default auth.uid()
) returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.crib_members m
    where m.crib_id = p_crib and m.user_id = p_user
  );
$$;

create or replace function public.is_crib_owner(
  p_crib uuid, p_user uuid default auth.uid()
) returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.cribs b
    where b.id = p_crib and b.owner_id = p_user and b.deleted_at is null
  );
$$;

revoke all on function public.is_active_member(uuid, uuid) from public;
grant execute on function public.is_active_member(uuid, uuid) to authenticated;
-- (same for was_member and is_crib_owner)
```

`is_active_member` gates **writes**; `was_member` gates **reads** and is how
D8 (historical access for removed members) is implemented: a removed member
keeps SELECT on the cribs they were in, and loses every write right.

### 4.3 Read policies (RLS)

```sql
alter table public.cribs enable row level security;
alter table public.crib_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_shares enable row level security;
alter table public.settlements enable row level security;
alter table public.invitations enable row level security;
alter table public.recurring_schedules enable row level security;
alter table public.recurring_occurrences enable row level security;
alter table public.activity_events enable row level security;
alter table public.profiles enable row level security;

-- profiles: own row, plus people you share a crib with
create policy profiles_read on public.profiles for select to authenticated
using (
  id = auth.uid()
  or exists (
    select 1 from public.crib_members m1
    join public.crib_members m2 on m2.crib_id = m1.crib_id
    where m1.user_id = auth.uid() and m2.user_id = profiles.id
  )
);

-- cribs: only cribs you are (or were) a member of
create policy cribs_read on public.cribs for select to authenticated
using (public.was_member(id));

-- crib_members: members of the crib can read the roster; a removed member
-- can still read their own row
create policy members_read on public.crib_members for select to authenticated
using (public.was_member(crib_id) or user_id = auth.uid());

-- expenses: active members read; removed members read their own history
create policy expenses_read on public.expenses for select to authenticated
using (
  public.is_active_member(crib_id)
  or (public.was_member(crib_id) and (payer_id = auth.uid() or created_by = auth.uid()))
);

create policy shares_read on public.expense_shares for select to authenticated
using (exists (
  select 1 from public.expenses e
  where e.id = expense_shares.expense_id
    and (public.is_active_member(e.crib_id)
         or (public.was_member(e.crib_id)
             and (e.payer_id = auth.uid() or e.created_by = auth.uid())))
));

create policy settlements_read on public.settlements for select to authenticated
using (public.was_member(crib_id));

create policy activity_read on public.activity_events for select to authenticated
using (public.was_member(crib_id));
```

Because the client can only select rows the policies allow, **the cross-crib
leak in C1 disappears structurally** — there is no code path that can ask for
another crib's rows, because the database refuses.

### 4.4 Write paths: `SECURITY DEFINER` RPCs

All mutations go through functions. Inside a `SECURITY DEFINER` function RLS is
bypassed, so **each function performs its own authorisation checks** using
`auth.uid()`. Functions are created by a non-login owner role, get
`set search_path = public, pg_temp`, and `execute` is revoked from `public`
and granted only to `authenticated`.

| RPC | Authorisation | Atomicity / idempotency |
| --- | --- | --- |
| `create_crib(name, currency, categories)` | `auth.uid()` becomes `owner_id` and the first membership | One transaction; activity event written in the same transaction |
| `update_crib(id, name, currency, categories, expected_version)` | `is_crib_owner(id)` | `where id = $1 and version = $2` → 0 rows means conflict |
| `delete_crib(id, expected_version)` | `is_crib_owner(id)` | **Soft delete (`deleted_at`), never a hard delete.** The row stays, so the expenses, the settlements and the activity of the Crib still resolve and the balances still add up. The members lose access: the Crib and all of its rows are hidden from the reads. A deleted Crib cannot be changed or deleted again (fixes C3 and the orphaning of the financial rows) |
| `add_member(crib_id, user_id)` | `is_crib_owner(crib_id)`; the user must exist in `profiles` | Insert with `on conflict do update` to re-activate; the name comes from `profiles`, never from the client (fixes H4) |
| `remove_member(crib_id, user_id)` | `is_crib_owner(crib_id)`; never the owner | Sets `left_at`; keeps the row so history stays valid |
| `create_expense(crib_id, description, total_minor, category, occurred_on, shares jsonb)` | `is_active_member(crib_id)` and `payer_id = auth.uid()`; every share participant must be an active member | Insert expense + shares + activity in one transaction; the share sum is checked against `total_minor` by a deferred constraint trigger; the payer must be a participant of their own expense |
| `update_expense(id, ..., expected_version)` | `is_active_member` and (`payer_id = auth.uid()` or `created_by = auth.uid()` **or `is_crib_owner(crib_id)`**); payer and currency immutable; §3.4 freeze predicate | Compare-and-swap on `version`; metadata-only updates skip the freeze predicate. **The Crib Owner may correct any expense of their crib** |
| `flag_dispute(id)` | `is_active_member(crib_id)` | Sets `disputed_at`/`disputed_by`; never blocked by the freeze rule |
| `delete_expense(id, expected_version)` | payer, creator **or the Crib Owner** | Tombstone (`deleted_at`), never a hard delete |
| `create_settlement(crib_id, to_user_id, amount_minor, idempotency_key, status)` | `from_user_id = auth.uid()`; `status` in ('pending','self_managed') only — a confirmed settlement is unreachable here | `pg_advisory_xact_lock(hashtext(crib_id))` serialises settlements per crib; overpayment checked against `pairwise_debt`; `on conflict (crib_id, requested_by, idempotency_key) do nothing` then return the existing row (fixes H3) |
| `confirm_settlement(id, expected_version)` | `to_user_id = auth.uid()` and `status = 'pending'` | Compare-and-swap; the amount can never be changed |
| `cancel_settlement(id, expected_version)` | `from_user_id = auth.uid()` and `status = 'pending'` | Status change only |
| `create_invitation(crib_id, expires_at)` | `is_crib_owner(crib_id)` | Generates 32 random bytes server-side, returns the raw token **once**, stores `sha256(token)` |
| `accept_invitation(raw_token)` | any authenticated user | Hash, look up, check revoked/expired/used/crib-deleted, check the caller is not already an active member, insert the membership, mark the acceptance, write the activity event — one transaction (fixes the low finding about readable metadata: the row is not readable directly) |
| `revoke_invitation(id)` | `is_crib_owner(crib_id)` | Sets `revoked_at`; already accepted members keep their membership |
| `create_recurring_schedule(...)` | `is_crib_owner(crib_id)` and `created_by = auth.uid()` | Validates the IANA zone against `pg_timezone_names` |
| `update_recurring_schedule(id, description, amount_minor, category, frequency, recipient_id, start_date)` | `is_crib_owner(crib_id)` | The occurrences that were generated already stay in the ledger; the payer and `resume_from` are not touched |
| `cancel_recurring_schedule(id)` | `is_crib_owner` | Sets `active = false`; past occurrences stay |
| `generate_due_occurrences(crib_id)` | `is_active_member(crib_id)` | `insert ... on conflict (schedule_id, occurrence_date) do nothing`; the expense is created **only** if the occurrence row was actually inserted. The unique constraint makes concurrent runs and two devices safe (fixes H7 for recurring). **A schedule with `payer_id is null` is paused and generates nothing** |
| `assign_recurring_payer(id, user_id)` | `is_crib_owner(crib_id)` | The assignee has to be an active member; `payer_id` is set and `resume_from` is kept; the assignment and the resume are written in the same transaction as the activity events |

### 4.5 Invitation tokens

* 32 bytes from `gen_random_bytes()`, base64url encoded → ~43 characters,
  ~256 bits of entropy.
* The database stores `sha256(token)` only. A database dump, a log line or a
  support screenshot never contains a live invite link.
* The raw token is returned exactly once, at creation, and is the only thing
  the app shares.
* Acceptance is a single transaction that re-checks revocation, expiry, use
  count and membership eligibility.
* Failed and successful attempts are audited; rate limiting belongs on the
  `accept_invitation` function (a counter table checked inside the function
  is enough for v1).

### 4.6 Recurring generation while the app is closed

Use `pg_cron` (included in Supabase) to call `generate_due_occurrences()` for
every active schedule on the hour. The function is `SECURITY DEFINER` and
performs its own authorisation for the scheduled run, or is split into an
internal variant that the cron calls. Because the occurrence insert relies on
`unique (schedule_id, occurrence_date)`, running it concurrently with a client
catch-up, or on two devices, cannot create a second expense.

Until the cron job exists, the app keeps its on-demand catch-up, and the UI
must keep saying that occurrences are generated when the crib is opened —
no claim of background execution.

### 4.7 Account deletion and retention

`delete_my_account()` (an Edge Function, because it needs the service role to
revoke sessions, or a `SECURITY DEFINER` function plus a session-revocation
job):

1. Anonymise the profile: `display_name = 'Removed member'`, `email = null`,
   `handle = null`, `deleted_at = now()`. The row and the id stay, because
   every financial record references it.
2. Revoke sessions and refresh tokens (service role only).
3. Revoke the invitations the user created (`revoked_at = now()`).
4. Close the user's memberships (`left_at = now()`), except cribs they own.
   For an owned crib, either transfer ownership or tombstone the crib
   (D-decision).
5. Keep all expenses, shares, settlements and activity. Their `user_id`
   references still resolve; the UI renders "Removed member".
6. Write an `account_deleted` activity event.

Retention periods are **not** set by the schema. If a purge is later
required, it goes into one maintenance function that takes the cutoff as a
parameter, so the legal decision lives in one place:

```sql
create or replace function public.purge_anonymised_profiles(cutoff interval)
returns void language sql security definer as $$ ... $$;
```

The retention interval itself comes from legal/privacy review, not from this
plan.

### 4.8 What is explicitly *not* the security boundary

* The Dart repository checks (owner-only, active-member, version checks) stay
  — they produce good error messages and protect the UI — but every one of
  them is duplicated by an RLS policy or an RPC authorisation check. If the
  client is compromised, the database still refuses.
* `FinancialLedger` validation is duplicated in SQL. The client version is
  for instant feedback; the SQL version is the authority.
* The service role key is never in the app bundle. It lives only in Edge
  Function environment variables.

---

## 5. Repository migration map

| Contract | Supabase implementation | Notes |
| --- | --- | --- |
| `AuthRepository.currentUser` | `supabase.auth.currentUser` + the `profiles` row | The `AuthUser` model maps to `profiles` |
| `AuthRepository.signIn(email, displayName)` | **Split** into `signUp(email, password)` / `signIn(email, password)` / `signInWithOtp(email)` + a profile upsert | The current signature conflates registration and sign-in, and does no authentication (C2) |
| `AuthRepository.signOut` | `supabase.auth.signOut()` | |
| `AuthRepository.updateProfile(name, email)` | `update profiles` + `auth.updateUser(email:)` | An email change needs re-authentication |
| — | **new**: `sessionChanges`, `refreshSession`, `signOutAll` | The app needs a session gate (M4) |
| `CribRepository.list()` / `cachedCribs` | `select … from cribs join crib_members where left_at is null` + a local cache | Must become "my cribs" (C1) |
| `CribRepository.getById` | `select … where id = $1` | RLS scopes it; a 403 must be handled as "no longer a member" |
| `CribRepository.create` | `rpc('create_crib', …)` | |
| `CribRepository.update` | `rpc('update_crib', …, expected_version)` | Compare-and-swap |
| `CribRepository.delete` | `rpc('delete_crib', …)` | Tombstone (C3) |
| `CribRepository.addMember` | `rpc('add_member', crib_id, user_id)` | The user id is resolved server-side from a handle; the name comes from `profiles` (H4) |
| `CribRepository.removeMember` | `rpc('remove_member', crib_id, user_id)` | |
| `ExpenseRepository.list(cribId)` | `select … where crib_id = $1` | `cribId` becomes mandatory |
| `ExpenseRepository.getById` | `select … where id = $1` | |
| `ExpenseRepository.create` | `rpc('create_expense', …)` | |
| `ExpenseRepository.update` | `rpc('update_expense', …, expected_version)` | Freeze predicate lives in SQL (§3.4) |
| `ExpenseRepository.flagDispute` | `rpc('flag_dispute', id)` | |
| `ExpenseRepository.delete` | `rpc('delete_expense', id, expected_version)` | Tombstone |
| `SettlementRepository.list(cribId)` | `select … where crib_id = $1` | |
| `SettlementRepository.create` | `rpc('create_settlement', …, idempotency_key)` | Key scoped to `(crib, requested_by)` (H3) |
| `SettlementRepository.updateStatus` | `rpc('confirm_settlement' / 'cancel_settlement', …)` | Two functions instead of one status setter |
| `ActivityRepository.list` | `select … from activity_events order by occurred_at desc` | Server timestamps (H5) |
| `ActivityRepository.record` | **removed** from the client | Events are written by the same transaction as the mutation |
| `InvitationRepository.create` | `rpc('create_invitation', crib_id, expires_at)` → returns the raw token once | |
| `InvitationRepository.validate` | `rpc('validate_invitation', token)` | |
| `InvitationRepository.accept` | `rpc('accept_invitation', token)` | |
| `InvitationRepository.revoke` | `rpc('revoke_invitation', id)` | |
| `InvitationRepository.list(cribId)` | `select … from invitations where crib_id = $1` | Owner-only by policy |
| `RecurringPaymentRepository.create` | `rpc('create_recurring_schedule', …)` | The payer is the creator; the payer has to be an active member |
| `RecurringPaymentRepository.update` | `rpc('update_recurring_schedule', id, …)` | Owner only; the generated occurrences stay |
| `RecurringPaymentRepository.cancel` | `rpc('cancel_recurring_schedule', id)` | |
| `RecurringPaymentRepository.assignPayer` | `rpc('assign_recurring_payer', id, user_id)` | **New in Milestone 2B.** Owner only; the assignee has to be an active member; the assignment and the resume are written in the same transaction |
| `RecurringPaymentRepository.generateDue` | `rpc('generate_due_occurrences', crib_id)` | The client stops computing dates; the server owns the rules |
| `cachedSchedules` / `cachedOccurrences` | `select …` | |
| `MemberDirectory` (static helper) | **new** `UserDirectoryRepository.lookup(handle)` | Resolves a person to a user id for "add member" (H4) |

### Missing contracts to add before integration

1. **Authentication** — separate sign-up / sign-in / session refresh / sign-out,
   and a session-change stream. The current `signIn` is not authentication (C2).
2. **`listMyCribs()`** — the crib list must be explicitly "mine" (C1).
3. **Mandatory `cribId`** on every expense/settlement list method.
4. **`UserDirectoryRepository`** — resolve a handle to a user id; removes the
   client-supplied member name (H4).
5. **`LedgerRepository.balances(cribId)`** — the UI should not recompute
   balances over a whole expense list; the server should return them.
6. **`RecurringPaymentRepository.catchUp()`** — server-driven, replacing the
   client-side date maths.
7. **`AccountRepository.requestDeletion()`** — the contract behind the profile
   screen's toast (C2).
8. **A client request id on every mutation**, plus a `ConflictException` that
   carries the current server row so the UI can offer "reload and review".
   The current `RepositoryException` has a code but no payload.
9. **`CribRepository.transferOwnership`** — only if D-decision 8 requires it;
   otherwise leave it out.

### Keeping the in-memory store

* `InMemoryStore` and the `InMemory*Repository` classes stay as the test
  implementation of the same interfaces. They are the fastest way to test UI
  logic without a network.
* `PayCalRepositories` already accepts an injected store
  (`PayCalRepositories.forStore`). The production app swaps the repository
  set through the same seam, so the UI never learns which one it is talking to.
* The test harness (`test/support/harness.dart`) should be parameterised so
  the **same contract suite** can run against the in-memory set and the
  Supabase set. That suite is the real definition of the contract and it is
  what keeps the two implementations honest.
* Consequence: the in-memory implementation must first be corrected to the
  agreed semantics (M1). Otherwise the contract suite encodes the wrong rules
  and the database has to be bent to match them.

---

## 6. Ordered implementation plan

Each milestone is independently testable and ships behind a switch.

| # | Milestone | Depends on | Done when |
| --- | --- | --- | --- |
| **M0** | Decide the open product rules (D1–D10) | — | `PRODUCT_RULES.md` is updated with the decisions; the schema is frozen afterwards |
| **M1** | Correct the semantics in the in-memory implementation | M0 | Per-pair debt, the §3.4 freeze rule, the idempotency key scope, the `time` field, the `-0.50` parse bug, the removed-member charging rule, the activity `occurredAt` — each with a test in the existing suite |
| **M2** | Supabase project and schema | M0 | `supabase/migrations/` contains the tables, constraints and indexes above; a local Postgres applies it cleanly; constraint tests prove the share sum, the FK and the unique indexes hold |
| **M3** | RLS policies and RPCs | M2 | An RLS test suite proves: a non-member cannot read or write another crib; a member cannot administer another crib; a removed member can read but not write; the owner-only paths are enforced; the service role is not used anywhere in the client |
| **M4** | Auth in the app | M2 | `supabase_flutter` added; the session bootstraps on launch; sign-up / sign-in / sign-out are real; the app is gated on the session; the profile "delete account" and "log out" call the backend |
| **M5** | Crib and membership adapters | M3, M4 | `CribRepository` is served by Supabase; the existing contract suite passes against it; the UI is unchanged |
| **M6** | Expense and settlement adapters | M3, M4, M5 | The money path is served by the RPCs; idempotent retries are proven; the overpayment rule matches the in-memory behaviour; concurrent settlement attempts are serialised |
| **M7** | Invitations and deep links | M3, M4 | The raw token is returned once and only its hash is stored; acceptance, expiry and revocation are proven against the real functions; `paycal://crib/<id>` still grants nothing |
| **M8** | Recurring schedules and the cron job | M3, M4 | The server owns the date rules; `pg_cron` runs `generate_due_occurrences`; two parallel runs and two devices produce exactly one expense per occurrence |
| **M9** | Activity feed | M3, M6, M7 | Events come from `activity_events` with server timestamps; the relative label is derived in the UI; the `time` display string is gone from the domain model |
| **M10** | Account deletion and retention | M4 | The profile screen calls the backend; the profile is anonymised; sessions and invitations are revoked; financial history survives; a purge function exists with the period as a parameter |
| **M11** | Cleanup | M1–M10 | `MockData`, `balance_engine.dart` and `settle_sheet.dart` are gone from the app path; the placeholder-member onboarding is replaced by real invitations; the contract suite runs against both implementations in CI |

### Acceptance tests per milestone

**M1** — per-pair debt accepts the settlement that the net rule rejected
(the exact scenario from P3); the freeze rule blocks an expense involving a
settled pair but allows an unrelated one and allows metadata-only edits; a
reused idempotency key from a different sender is rejected instead of
returning the wrong row; `-0.50` does not parse as a positive amount; activity
rows carry a usable timestamp; a new expense cannot be created whose only
participant is a removed member.

> **Status 2026-10-20.** The M1 acceptance items that are about the money
> rules are now covered by the suite:
> `test/settlement_pairwise_debt_test.dart` (per-pair debt, partial
> payments, overpayment, retries, duplicate keys, mismatched payloads),
> `test/active_member_enforcement_test.dart` (the removed-member rule at the
> domain level and in the repository),
> `test/money_test.dart` (the `-0.50` parse bug, overflow, formatting) and
> `test/financial_ledger_test.dart` (pairwise debt, suggested transfers).
> The metadata-only edit needed a real fix before it could be tested: the
> share comparison used `==` on two different map objects, so every expense
> counted as changed and the freeze rule blocked every edit. It is compared by
> content now, through `FinancialLedger.sameShares`.
>
> Still open in M1: the activity `time` field (the display string still lives
> in the domain model) and the `occurredAt` server timestamp, which both need
> the backend.
>
> **Update 2026-10-20 (Milestone 2B).** Two more M1 items are now covered:
> the recurring payer (a schedule pauses when its payer leaves and resumes
> when the owner assigns an active member, `test/recurring_pause_test.dart`)
> and the consistency between the net position and the pairwise debt
> (`test/settlement_pairwise_debt_test.dart`). The `payer_id` and
> `resume_from` columns of `recurring_schedules` above are part of that
> change.

**M2** — a share sum that does not equal the total is rejected; a share
referencing a non-member is rejected; the `(schedule_id, occurrence_date)`
unique index rejects a duplicate occurrence; `left_at` and `deleted_at` behave
as the active flags; the `settlements` unique index rejects a duplicate key.

**M3** — as a user A: reading crib B (owned by someone else) returns zero
rows; writing to crib B raises; A cannot add a member to a crib A does not
own; A cannot create an invitation for a crib A does not own; a removed
member can read their own historical expenses and cannot create new ones;
`service_role` is not referenced in `lib/`; every RPC rejects a call with a
forged `user_id` argument (the function must use `auth.uid()`, never a
parameter).

**M4** — a signed-out user cannot reach the crib list; a signed-in user sees
only their cribs; sign-out revokes the session; the app restores the session
on relaunch.

**M5** — the contract suite passes against the Supabase adapter; creating a
crib makes the creator the owner and an active member; a second client sees
the new crib; removing a member keeps their history readable.

**M6** — an expense creates its shares and its activity event atomically (no
expense without shares after a forced failure); the same request id twice
creates one settlement; two concurrent settlements that together exceed the
debt produce one success and one rejection; the overpayment rule rejects
exactly what the in-memory rule rejects.

**M7** — the database contains no plaintext token; the acceptance of a
revoked, an expired and an unknown token fails; the acceptance of a valid
token adds exactly one member; the invitation is consumed.

**M8** — a schedule due in the past generates exactly one expense per missed
occurrence; running the generation twice adds nothing; two cron runs in
parallel add nothing; cancelling stops the future occurrences but keeps the
past ones.

**M9** — the feed is ordered by the server timestamp; the relative label
reflects the elapsed time.

**M10** — after deletion the display name is anonymised, the financial records
still resolve, the sessions are invalid, the created invitations are revoked,
and the activity trail records the deletion.

**M11** — the full suite runs against both implementations; `grep -r MockData
lib/` returns nothing; CI runs the Supabase test database for the RLS suite.

---

## 7. Out of scope for v1

Deliberately not proposed, to keep the launch small: realtime subscriptions,
push notifications, offline sync/conflict resolution, multi-currency
conversion, admin roles beyond the owner, invite approval workflows, export
of financial data, and any server-side analytics. The only server-side
component that needs a privileged role is account deletion; everything else
works with `authenticated` and RLS.


## Cross-reference

See docs/PRODUCT_AUDIT.md, docs/PRODUCT_FINDINGS.md, and docs/PRODUCT_REMEDIATION_PLAN.md for the full product audit, findings register, and remediation milestones. Supabase integration is blocked by findings C1-C3 and H1-H8 listed there.
