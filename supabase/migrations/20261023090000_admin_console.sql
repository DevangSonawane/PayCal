-- PayCal admin console: platform admin role, user suspension, an audit log,
-- admin read access and moderation RPCs. The mobile app is untouched: admins
-- are existing authenticated users with is_admin on their profile, and every
-- admin mutation is a security definer RPC that writes the audit log itself.

-- ---------------------------------------------------------------------------
-- 1. Admin and suspension columns
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column is_admin boolean not null default false,
  add column suspended_at timestamptz,
  add column suspension_reason text;

-- ---------------------------------------------------------------------------
-- 2. Admin helper
-- ---------------------------------------------------------------------------

create or replace function app_private.is_platform_admin()
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and is_admin
      and deleted_at is null
      and suspended_at is null
  );
$$;

-- ---------------------------------------------------------------------------
-- 3. Audit log
-- ---------------------------------------------------------------------------

create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null references public.profiles (id) on delete restrict,
  action text not null check (char_length(action) between 1 and 100),
  target_type text not null check (char_length(target_type) between 1 and 40),
  target_id uuid,
  reason text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index admin_audit_log_created_idx on public.admin_audit_log (created_at desc);
create index admin_audit_log_admin_idx on public.admin_audit_log (admin_id);

alter table public.admin_audit_log enable row level security;

create policy "platform admins can read the audit log"
  on public.admin_audit_log for select to authenticated
  using ((select app_private.is_platform_admin()));

grant select on public.admin_audit_log to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Membership helpers: a suspended (or deleted) profile reads and writes
--    nothing anymore.
-- ---------------------------------------------------------------------------

create or replace function app_private.was_crib_member(target_crib_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.crib_members membership
    join public.profiles profile on profile.id = membership.user_id
    where membership.crib_id = target_crib_id
      and membership.user_id = (select auth.uid())
      and profile.deleted_at is null
      and profile.suspended_at is null
  );
$$;

create or replace function app_private.is_active_crib_member(target_crib_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.crib_members membership
    join public.profiles profile on profile.id = membership.user_id
    join public.cribs crib on crib.id = membership.crib_id
    where membership.crib_id = target_crib_id
      and membership.user_id = (select auth.uid())
      and membership.left_at is null
      and crib.deleted_at is null
      and profile.deleted_at is null
      and profile.suspended_at is null
  );
$$;

-- A suspended user cannot even read their own profile, so every read in the
-- app fails while the account is locked. The display_name-only update grant
-- above means they cannot clear the flag themselves.
drop policy "users can read their profile" on public.profiles;
create policy "users can read their profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id and suspended_at is null);

-- ---------------------------------------------------------------------------
-- 5. Admin read access
-- ---------------------------------------------------------------------------

create policy "platform admins can read profiles"
  on public.profiles for select to authenticated
  using ((select app_private.is_platform_admin()));

create policy "platform admins can read cribs"
  on public.cribs for select to authenticated
  using ((select app_private.is_platform_admin()));

create policy "platform admins can read memberships"
  on public.crib_members for select to authenticated
  using ((select app_private.is_platform_admin()));

create policy "platform admins can read expenses"
  on public.expenses for select to authenticated
  using ((select app_private.is_platform_admin()));

create policy "platform admins can read expense shares"
  on public.expense_shares for select to authenticated
  using ((select app_private.is_platform_admin()));

create policy "platform admins can read settlements"
  on public.settlements for select to authenticated
  using ((select app_private.is_platform_admin()));

create policy "platform admins can read invitations"
  on public.invitations for select to authenticated
  using ((select app_private.is_platform_admin()));

create policy "platform admins can read schedules"
  on public.recurring_schedules for select to authenticated
  using ((select app_private.is_platform_admin()));

create policy "platform admins can read recurring occurrences"
  on public.recurring_occurrences for select to authenticated
  using ((select app_private.is_platform_admin()));

create policy "platform admins can read activity"
  on public.activity_events for select to authenticated
  using ((select app_private.is_platform_admin()));

-- ---------------------------------------------------------------------------
-- 6. Audit writer
-- ---------------------------------------------------------------------------

create or replace function app_private.write_admin_audit(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_details jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_target_id is null and p_target_type = 'profile' then
    raise exception 'Audit row without a target' using errcode = '22004';
  end if;
  insert into public.admin_audit_log (admin_id, action, target_type, target_id, reason, details)
  values (auth.uid(), p_action, p_target_type, p_target_id, nullif(trim(p_reason), ''), p_details);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Moderation RPCs
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_user_suspension(
  p_target_user_id uuid,
  p_suspended boolean,
  p_reason text default ''
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.profiles;
begin
  if not app_private.is_platform_admin() then
    raise exception 'Platform admin required' using errcode = '42501';
  end if;

  select * into target
  from public.profiles
  where id = p_target_user_id
  for update;
  if target is null then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  if target.deleted_at is not null then
    raise exception 'User account is deleted' using errcode = 'P0002';
  end if;
  if target.id = auth.uid() then
    raise exception 'You cannot suspend yourself' using errcode = '42501';
  end if;
  if target.is_admin then
    raise exception 'You cannot suspend another platform admin' using errcode = '42501';
  end if;

  if p_suspended then
    update public.profiles
    set suspended_at = now(), suspension_reason = nullif(trim(p_reason), '')
    where id = target.id
    returning * into target;

    -- The suspension is enforced by RLS (denied profile and membership reads),
    -- so an existing session instantly loses all access. Full session
    -- revocation stays with the Supabase auth admin API, which the console
    -- operator can use on top if they want the tokens gone as well.
  else
    update public.profiles
    set suspended_at = null, suspension_reason = null
    where id = target.id
    returning * into target;
  end if;

  perform app_private.write_admin_audit(
    case when p_suspended then 'user_suspended' else 'user_unsuspended' end,
    'profile',
    target.id,
    p_reason,
    jsonb_build_object('display_name', target.display_name)
  );

  return target;
end;
$$;

create or replace function public.admin_delete_crib(
  p_crib_id uuid,
  p_expected_version bigint,
  p_reason text default ''
)
returns public.cribs
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.cribs;
begin
  if not app_private.is_platform_admin() then
    raise exception 'Platform admin required' using errcode = '42501';
  end if;

  select * into target
  from public.cribs
  where id = p_crib_id
  for update;
  if target is null then
    raise exception 'Crib not found' using errcode = 'P0002';
  end if;
  if target.deleted_at is not null then
    raise exception 'Crib is already deleted' using errcode = 'P0002';
  end if;
  if p_expected_version is null or target.version <> p_expected_version then
    raise exception 'Crib changed by another device' using errcode = '40001';
  end if;

  update public.cribs
  set deleted_at = now(), version = version + 1, updated_at = now()
  where id = target.id
  returning * into target;

  perform app_private.write_admin_audit(
    'crib_deleted',
    'crib',
    target.id,
    p_reason,
    jsonb_build_object('name', target.name, 'owner_id', target.owner_id, 'version', target.version)
  );

  return target;
end;
$$;

create or replace function public.admin_remove_crib_member(
  p_crib_id uuid,
  p_user_id uuid,
  p_reason text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.crib_members;
  crib_names record;
begin
  if not app_private.is_platform_admin() then
    raise exception 'Platform admin required' using errcode = '42501';
  end if;

  select name, owner_id, coalesce(deleted_at is not null, false) as deleted
  into crib_names
  from public.cribs
  where id = p_crib_id
  for update;
  if crib_names is null then
    raise exception 'Crib not found' using errcode = 'P0002';
  end if;
  if crib_names.deleted then
    raise exception 'Crib is deleted' using errcode = 'P0002';
  end if;
  if crib_names.owner_id = p_user_id then
    raise exception 'The crib owner cannot be removed' using errcode = '42501';
  end if;

  select * into target
  from public.crib_members
  where crib_id = p_crib_id and user_id = p_user_id
  for update;
  if target is null then
    raise exception 'Membership not found' using errcode = 'P0002';
  end if;
  if target.left_at is not null then
    raise exception 'Member already removed' using errcode = 'P0002';
  end if;

  update public.crib_members
  set left_at = now()
  where crib_id = p_crib_id and user_id = p_user_id;

  insert into public.activity_events (crib_id, actor_id, action, target_id, metadata)
  values (p_crib_id, auth.uid(), 'member_removed', p_user_id, jsonb_build_object('by', 'platform_admin'));

  perform app_private.write_admin_audit(
    'member_removed',
    'crib_membership',
    p_user_id,
    p_reason,
    jsonb_build_object('crib_id', p_crib_id)
  );
end;
$$;

create or replace function public.admin_revoke_invitation(
  p_invitation_id uuid,
  p_reason text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.invitations;
begin
  if not app_private.is_platform_admin() then
    raise exception 'Platform admin required' using errcode = '42501';
  end if;

  select * into target
  from public.invitations
  where id = p_invitation_id
  for update;
  if target is null then
    raise exception 'Invitation not found' using errcode = 'P0002';
  end if;
  if target.revoked_at is not null then
    raise exception 'Invitation already revoked' using errcode = 'P0002';
  end if;

  update public.invitations
  set revoked_at = now()
  where id = target.id;

  perform app_private.write_admin_audit(
    'invitation_revoked',
    'invitation',
    target.id,
    p_reason,
    jsonb_build_object('crib_id', target.crib_id)
  );
end;
$$;

create or replace function public.admin_cancel_schedule(
  p_schedule_id uuid,
  p_reason text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.recurring_schedules;
begin
  if not app_private.is_platform_admin() then
    raise exception 'Platform admin required' using errcode = '42501';
  end if;

  select * into target
  from public.recurring_schedules
  where id = p_schedule_id
  for update;
  if target is null then
    raise exception 'Schedule not found' using errcode = 'P0002';
  end if;
  if not target.active then
    raise exception 'Schedule is already cancelled' using errcode = 'P0002';
  end if;

  update public.recurring_schedules
  set active = false, updated_at = now()
  where id = target.id;

  insert into public.activity_events (crib_id, actor_id, action, target_id, metadata)
  values (target.crib_id, auth.uid(), 'recurring_cancelled', target.id, jsonb_build_object('by', 'platform_admin'));

  perform app_private.write_admin_audit(
    'schedule_cancelled',
    'recurring_schedule',
    target.id,
    p_reason,
    jsonb_build_object('crib_id', target.crib_id, 'was_paused', target.payer_id is null)
  );
end;
$$;

create or replace function public.admin_resolve_dispute(
  p_expense_id uuid,
  p_unpaid boolean default false,
  p_reason text default ''
)
returns public.expenses
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.expenses;
begin
  if not app_private.is_platform_admin() then
    raise exception 'Platform admin required' using errcode = '42501';
  end if;

  select * into target
  from public.expenses
  where id = p_expense_id and deleted_at is null
  for update;
  if target is null then
    raise exception 'Expense not found' using errcode = 'P0002';
  end if;
  if target.disputed_at is null then
    raise exception 'Expense is not disputed' using errcode = 'P0002';
  end if;

  update public.expenses
  set disputed_at = null, unpaid = coalesce(p_unpaid, unpaid), version = version + 1, updated_at = now()
  where id = target.id
  returning * into target;

  insert into public.activity_events (crib_id, actor_id, action, target_id)
  values (target.crib_id, auth.uid(), 'expense_dispute_resolved', target.id);

  perform app_private.write_admin_audit(
    'dispute_resolved',
    'expense',
    target.id,
    p_reason,
    jsonb_build_object('crib_id', target.crib_id, 'marked_unpaid', target.unpaid)
  );

  return target;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Execution rights
--
-- The RLS helpers (is_platform_admin, was_crib_member,
-- is_active_crib_member) are executed by policies on behalf of the signed-in
-- user, so authenticated must keep the execution right — see migration
-- 20261021130000 for the precedent. Like the other two they are security
-- definer and resolve the caller only through auth.uid().
--
-- write_admin_audit is only ever called inside security definer RPCs, so it
-- stays revoked from the API roles.
-- ---------------------------------------------------------------------------

revoke all on function app_private.is_platform_admin() from public, anon;
grant execute on function app_private.is_platform_admin() to authenticated;

revoke all on function app_private.write_admin_audit(text, text, uuid, text, jsonb) from public, anon, authenticated;

revoke all on function public.admin_set_user_suspension(uuid, boolean, text) from public, anon;
revoke all on function public.admin_delete_crib(uuid, bigint, text) from public, anon;
revoke all on function public.admin_remove_crib_member(uuid, uuid, text) from public, anon;
revoke all on function public.admin_revoke_invitation(uuid, text) from public, anon;
revoke all on function public.admin_cancel_schedule(uuid, text) from public, anon;
revoke all on function public.admin_resolve_dispute(uuid, boolean, text) from public, anon;

grant execute on function public.admin_set_user_suspension(uuid, boolean, text) to authenticated;
grant execute on function public.admin_delete_crib(uuid, bigint, text) to authenticated;
grant execute on function public.admin_remove_crib_member(uuid, uuid, text) to authenticated;
grant execute on function public.admin_revoke_invitation(uuid, text) to authenticated;
grant execute on function public.admin_cancel_schedule(uuid, text) to authenticated;
grant execute on function public.admin_resolve_dispute(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Dashboard statistics (read-only, no audit needed)
-- ---------------------------------------------------------------------------

create or replace function public.admin_dashboard_stats()
returns jsonb
language sql
security definer
set search_path = ''
stable
as $$
  with per_day as (
    select occurred_on, count(*)::int as cnt, sum(total_minor)::bigint as total_minor
    from public.expenses
    where deleted_at is null
      and occurred_on >= current_date - interval '29 days'
    group by occurred_on
  )
  select jsonb_build_object(
    'profiles_total', (select count(*) from public.profiles where deleted_at is null),
    'profiles_suspended', (select count(*) from public.profiles where deleted_at is null and suspended_at is not null),
    'profiles_deleted', (select count(*) from public.profiles where deleted_at is not null),
    'cribs_live', (select count(*) from public.cribs where deleted_at is null),
    'cribs_deleted', (select count(*) from public.cribs where deleted_at is not null),
    'members_active', (select count(*) from public.crib_members where left_at is null),
    'members_departed', (select count(*) from public.crib_members where left_at is not null),
    'expenses_total', (select count(*) from public.expenses where deleted_at is null),
    'expenses_last_30d', (select count(*) from public.expenses where deleted_at is null and occurred_on >= current_date - interval '30 days'),
    'disputed_open', (select count(*) from public.expenses where deleted_at is null and disputed_at is not null),
    'expenses_unpaid', (select count(*) from public.expenses where deleted_at is null and unpaid),
    'settlements_confirmed', (select count(*) from public.settlements where status = 'confirmed'),
    'schedules_active', (select count(*) from public.recurring_schedules where active and payer_id is not null),
    'schedules_paused', (select count(*) from public.recurring_schedules where active and payer_id is null),
    'schedules_cancelled', (select count(*) from public.recurring_schedules where not active),
    'invitations_open', (select count(*) from public.invitations where revoked_at is null and accepted_at is null and expires_at > now()),
    'outbox_pending', (select count(*) from public.notification_outbox where status = 'pending'),
    'expenses_per_day', (
      select coalesce(jsonb_agg(jsonb_build_object('day', to_char(d.day, 'YYYY-MM-DD'), 'count', coalesce(p.cnt, 0), 'total_minor', coalesce(p.total_minor, 0)) order by d.day), '[]'::jsonb)
      from generate_series(current_date - interval '29 days', current_date, interval '1 day') as d(day)
      left join per_day p on p.occurred_on = d.day
    ),
    'currency_totals', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'currency', c.currency,
        'expenses_minor', coalesce(e.total, 0)::bigint,
        'settlements_minor', coalesce(s.total, 0)::bigint
      ) order by c.currency), '[]'::jsonb)
      from (
        select distinct currency
        from public.cribs
      ) c
      left join lateral (
        select sum(ex.total_minor) as total
        from public.expenses ex
        join public.cribs cb on cb.id = ex.crib_id and cb.currency = c.currency
        where ex.deleted_at is null
      ) e on true
      left join lateral (
        select sum(st.amount_minor) as total
        from public.settlements st
        join public.cribs cb2 on cb2.id = st.crib_id and cb2.currency = c.currency
        where st.status = 'confirmed'
      ) s on true
    )
  );
$$;

revoke all on function public.admin_dashboard_stats() from public, anon;
grant execute on function public.admin_dashboard_stats() to authenticated;