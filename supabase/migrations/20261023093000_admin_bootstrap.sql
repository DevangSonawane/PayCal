-- Admin bootstrap: lets the operator mint the very first platform admin from
-- the console. The RPC refuses once any admin exists, so the signup window is
-- never an open privilege escalation path — and the bootstrap code is required
-- on top of that.

create table app_private.admin_bootstrap (
  code_hash text not null primary key,
  created_at timestamptz not null default now()
);

create or replace function public.declare_first_admin(p_bootstrap_code text)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  me public.profiles;
  admin_count int;
begin
  if not exists (
    select 1 from app_private.admin_bootstrap
    where code_hash = encode(sha256(convert_to(nullif(trim(p_bootstrap_code), ''), 'utf8')), 'hex')
  ) then
    raise exception 'Invalid bootstrap code' using errcode = '42501';
  end if;

  select count(*) into admin_count
  from public.profiles
  where is_admin and deleted_at is null;
  if admin_count > 0 then
    raise exception 'An admin already exists' using errcode = '42501';
  end if;

  select * into me
  from public.profiles
  where id = (select auth.uid());
  if me is null or me.deleted_at is not null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;

  update public.profiles
  set is_admin = true
  where id = me.id
  returning * into me;

  perform app_private.write_admin_audit(
    'admin_created',
    'profile',
    me.id,
    'bootstrap',
    jsonb_build_object('email', 'created via first-admin bootstrap')
  );

  return me;
end;
$$;

revoke all on function public.declare_first_admin(text) from public, anon;
grant execute on function public.declare_first_admin(text) to authenticated;
