-- Financial records are append-oriented. Mutation RPCs are added with the
-- repository implementation; no client receives direct write privileges.

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  crib_id uuid not null references public.cribs (id) on delete restrict,
  description text not null check (char_length(trim(description)) between 1 and 240),
  total_minor bigint not null check (total_minor > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  payer_id uuid not null references public.profiles (id) on delete restrict,
  created_by uuid not null references public.profiles (id) on delete restrict,
  category text not null check (char_length(trim(category)) between 1 and 80),
  occurred_on date not null,
  disputed_at timestamptz,
  unpaid boolean not null default false,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.expense_shares (
  expense_id uuid not null references public.expenses (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete restrict,
  share_minor bigint not null check (share_minor >= 0),
  primary key (expense_id, user_id)
);

create table public.settlements (
  id uuid primary key default gen_random_uuid(),
  crib_id uuid not null references public.cribs (id) on delete restrict,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  from_user_id uuid not null references public.profiles (id) on delete restrict,
  to_user_id uuid not null references public.profiles (id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  status text not null check (status in ('pending', 'confirmed', 'cancelled', 'self_managed')),
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 200),
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (from_user_id <> to_user_id),
  unique (crib_id, from_user_id, idempotency_key)
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  crib_id uuid not null references public.cribs (id) on delete restrict,
  token_hash text not null unique,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  accepted_by uuid references public.profiles (id) on delete restrict,
  accepted_at timestamptz,
  check (expires_at > created_at),
  check ((accepted_by is null) = (accepted_at is null))
);

create table public.recurring_schedules (
  id uuid primary key default gen_random_uuid(),
  crib_id uuid not null references public.cribs (id) on delete restrict,
  description text not null check (char_length(trim(description)) between 1 and 240),
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  category text not null check (char_length(trim(category)) between 1 and 80),
  frequency text not null check (frequency in ('monthly', 'yearly')),
  recipient_id uuid not null references public.profiles (id) on delete restrict,
  created_by uuid not null references public.profiles (id) on delete restrict,
  payer_id uuid references public.profiles (id) on delete restrict,
  resume_from date,
  local_hour smallint not null check (local_hour between 0 and 23),
  local_minute smallint not null check (local_minute between 0 and 59),
  anchor_day smallint not null check (anchor_day between 1 and 31),
  time_zone text not null,
  start_date date not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.recurring_occurrences (
  schedule_id uuid not null references public.recurring_schedules (id) on delete restrict,
  due_date date not null,
  expense_id uuid not null unique references public.expenses (id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (schedule_id, due_date)
);

create table public.activity_events (
  id bigint generated always as identity primary key,
  crib_id uuid not null references public.cribs (id) on delete restrict,
  actor_id uuid references public.profiles (id) on delete restrict,
  action text not null check (char_length(action) between 1 and 100),
  target_id uuid,
  request_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index expenses_crib_occurred_idx on public.expenses (crib_id, occurred_on desc, created_at desc)
  where deleted_at is null;
create index expenses_payer_id_idx on public.expenses (payer_id);
create index expense_shares_user_id_idx on public.expense_shares (user_id);
create index settlements_crib_created_idx on public.settlements (crib_id, created_at desc);
create index settlements_from_user_id_idx on public.settlements (from_user_id);
create index settlements_to_user_id_idx on public.settlements (to_user_id);
create index invitations_crib_id_idx on public.invitations (crib_id);
create index recurring_schedules_crib_id_idx on public.recurring_schedules (crib_id);
create index activity_events_crib_occurred_idx on public.activity_events (crib_id, occurred_at desc);

-- A CHECK cannot compare an expense with rows in expense_shares. Deferring
-- this trigger allows an RPC to write the expense and all shares atomically.
create or replace function app_private.validate_expense_share_sum()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_expense_id uuid;
  expected_total bigint;
  actual_total bigint;
begin
  if tg_table_name = 'expense_shares' and tg_op = 'DELETE' then
    target_expense_id := old.expense_id;
  elsif tg_table_name = 'expense_shares' then
    target_expense_id := new.expense_id;
  elsif tg_op = 'DELETE' then
    target_expense_id := old.id;
  else
    target_expense_id := new.id;
  end if;
  select total_minor into expected_total
  from public.expenses where id = target_expense_id and deleted_at is null;
  if expected_total is null then
    return null;
  end if;
  select coalesce(sum(share_minor), 0) into actual_total
  from public.expense_shares where expense_id = target_expense_id;
  if actual_total <> expected_total then
    raise exception 'Expense shares must equal the expense total' using errcode = '23514';
  end if;
  return null;
end;
$$;

create constraint trigger expense_share_sum_after_share_change
  after insert or update or delete on public.expense_shares
  deferrable initially deferred
  for each row execute procedure app_private.validate_expense_share_sum();

create constraint trigger expense_share_sum_after_expense_change
  after insert or update of total_minor, deleted_at on public.expenses
  deferrable initially deferred
  for each row execute procedure app_private.validate_expense_share_sum();

alter table public.expenses enable row level security;
alter table public.expense_shares enable row level security;
alter table public.settlements enable row level security;
alter table public.invitations enable row level security;
alter table public.recurring_schedules enable row level security;
alter table public.recurring_occurrences enable row level security;
alter table public.activity_events enable row level security;

create policy "members can read expenses" on public.expenses for select to authenticated
  using ((select app_private.was_crib_member(crib_id)) and deleted_at is null);
create policy "members can read expense shares" on public.expense_shares for select to authenticated
  using (exists (select 1 from public.expenses expense where expense.id = expense_id
    and (select app_private.was_crib_member(expense.crib_id)) and expense.deleted_at is null));
create policy "members can read settlements" on public.settlements for select to authenticated
  using ((select app_private.was_crib_member(crib_id)));
create policy "owners can read invitations" on public.invitations for select to authenticated
  using ((select app_private.is_crib_owner(crib_id)));
create policy "members can read schedules" on public.recurring_schedules for select to authenticated
  using ((select app_private.was_crib_member(crib_id)));
create policy "members can read recurring occurrences" on public.recurring_occurrences for select to authenticated
  using (exists (select 1 from public.recurring_schedules schedule where schedule.id = schedule_id
    and (select app_private.was_crib_member(schedule.crib_id))));
create policy "members can read activity" on public.activity_events for select to authenticated
  using ((select app_private.was_crib_member(crib_id)));

grant select on public.expenses, public.expense_shares, public.settlements,
  public.invitations, public.recurring_schedules, public.recurring_occurrences,
  public.activity_events to authenticated;
