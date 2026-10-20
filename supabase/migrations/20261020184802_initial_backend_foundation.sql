-- PayCal backend foundation: authenticated profiles, cribs, and memberships.
-- All client mutations go through the RPCs below; direct writes are denied.

create schema if not exists app_private;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.cribs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 120),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  categories text[] not null default '{}'::text[],
  owner_id uuid not null references public.profiles (id) on delete restrict,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.crib_members (
  crib_id uuid not null references public.cribs (id) on delete restrict,
  user_id uuid not null references public.profiles (id) on delete restrict,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (crib_id, user_id),
  check (left_at is null or left_at >= joined_at)
);

create index cribs_owner_id_idx on public.cribs (owner_id);
create index cribs_visible_idx on public.cribs (id) where deleted_at is null;
create index crib_members_user_crib_idx on public.crib_members (user_id, crib_id);
create index crib_members_active_user_crib_idx on public.crib_members (user_id, crib_id)
  where left_at is null;

create or replace function app_private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(new.email, '@', 1), 'PayCal member')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure app_private.handle_new_user();

-- The helpers intentionally live outside the API-exposed schema. They use the
-- caller identity, not an argument supplied by the Flutter client.
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
    where membership.crib_id = target_crib_id
      and membership.user_id = (select auth.uid())
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
    join public.cribs crib on crib.id = membership.crib_id
    where membership.crib_id = target_crib_id
      and membership.user_id = (select auth.uid())
      and membership.left_at is null
      and crib.deleted_at is null
  );
$$;

create or replace function app_private.is_crib_owner(target_crib_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.cribs crib
    where crib.id = target_crib_id
      and crib.owner_id = (select auth.uid())
      and crib.deleted_at is null
  );
$$;

revoke all on schema app_private from public;
revoke all on all functions in schema app_private from public, anon, authenticated;

alter table public.profiles enable row level security;
alter table public.cribs enable row level security;
alter table public.crib_members enable row level security;

create policy "users can read their profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

create policy "users can update their profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "members can read their live cribs"
  on public.cribs for select to authenticated
  using ((select app_private.was_crib_member(id)) and deleted_at is null);

create policy "members can read crib membership"
  on public.crib_members for select to authenticated
  using ((select app_private.was_crib_member(crib_id)));

grant select, update (display_name) on public.profiles to authenticated;
grant select on public.cribs, public.crib_members to authenticated;

create or replace function public.create_crib(
  crib_name text,
  crib_currency text,
  crib_categories text[] default '{}'::text[]
)
returns public.cribs
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_crib public.cribs;
  actor_id uuid := auth.uid();
begin
  if actor_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  insert into public.cribs (name, currency, categories, owner_id)
  values (trim(crib_name), upper(trim(crib_currency)), coalesce(crib_categories, '{}'::text[]), actor_id)
  returning * into created_crib;

  insert into public.crib_members (crib_id, user_id)
  values (created_crib.id, actor_id);

  return created_crib;
end;
$$;

create or replace function public.update_crib(
  target_crib_id uuid,
  expected_version bigint,
  crib_name text,
  crib_currency text,
  crib_categories text[]
)
returns public.cribs
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_crib public.cribs;
begin
  if not app_private.is_crib_owner(target_crib_id) then
    raise exception 'Only the Crib Owner may update a crib' using errcode = '42501';
  end if;

  update public.cribs
  set name = trim(crib_name),
      currency = upper(trim(crib_currency)),
      categories = coalesce(crib_categories, '{}'::text[]),
      version = version + 1,
      updated_at = now()
  where id = target_crib_id
    and version = expected_version
    and deleted_at is null
  returning * into updated_crib;

  if updated_crib is null then
    raise exception 'Crib was changed by another device' using errcode = '40001';
  end if;
  return updated_crib;
end;
$$;

create or replace function public.add_crib_member(target_crib_id uuid, member_id uuid)
returns public.crib_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership public.crib_members;
begin
  if not app_private.is_crib_owner(target_crib_id) then
    raise exception 'Only the Crib Owner may manage members' using errcode = '42501';
  end if;

  insert into public.crib_members (crib_id, user_id)
  values (target_crib_id, member_id)
  on conflict (crib_id, user_id) do update
    set left_at = null
  returning * into membership;
  return membership;
end;
$$;

create or replace function public.remove_crib_member(target_crib_id uuid, member_id uuid)
returns public.crib_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership public.crib_members;
begin
  if not app_private.is_crib_owner(target_crib_id) then
    raise exception 'Only the Crib Owner may manage members' using errcode = '42501';
  end if;
  if exists (select 1 from public.cribs where id = target_crib_id and owner_id = member_id) then
    raise exception 'Transfer ownership before removing the owner' using errcode = '23514';
  end if;

  update public.crib_members
  set left_at = now()
  where crib_id = target_crib_id and user_id = member_id and left_at is null
  returning * into membership;

  if membership is null then
    raise exception 'Active membership not found' using errcode = 'P0002';
  end if;
  return membership;
end;
$$;

create or replace function public.delete_crib(target_crib_id uuid, expected_version bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not app_private.is_crib_owner(target_crib_id) then
    raise exception 'Only the Crib Owner may delete a crib' using errcode = '42501';
  end if;

  update public.cribs
  set deleted_at = now(), version = version + 1, updated_at = now()
  where id = target_crib_id and version = expected_version and deleted_at is null;

  if not found then
    raise exception 'Crib was changed by another device' using errcode = '40001';
  end if;
end;
$$;

revoke all on function public.create_crib(text, text, text[]) from public;
revoke all on function public.update_crib(uuid, bigint, text, text, text[]) from public;
revoke all on function public.add_crib_member(uuid, uuid) from public;
revoke all on function public.remove_crib_member(uuid, uuid) from public;
revoke all on function public.delete_crib(uuid, bigint) from public;
grant execute on function public.create_crib(text, text, text[]) to authenticated;
grant execute on function public.update_crib(uuid, bigint, text, text, text[]) to authenticated;
grant execute on function public.add_crib_member(uuid, uuid) to authenticated;
grant execute on function public.remove_crib_member(uuid, uuid) to authenticated;
grant execute on function public.delete_crib(uuid, bigint) to authenticated;
