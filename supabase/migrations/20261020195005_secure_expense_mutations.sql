create or replace function public.create_expense(
  target_crib_id uuid, expense_description text, expense_total_minor bigint,
  expense_currency text, expense_category text, expense_occurred_on date,
  expense_shares jsonb
) returns public.expenses language plpgsql security definer set search_path = '' as $$
declare e public.expenses; actor uuid := auth.uid(); share jsonb; participant uuid;
begin
  if actor is null or not app_private.is_active_crib_member(target_crib_id) then
    raise exception 'Active membership required' using errcode = '42501';
  end if;
  if expense_total_minor <= 0 or jsonb_typeof(expense_shares) <> 'array' or jsonb_array_length(expense_shares) = 0 then
    raise exception 'Invalid expense or shares' using errcode = '23514';
  end if;
  if (select coalesce(sum((value->>'share_minor')::bigint), 0) from jsonb_array_elements(expense_shares)) <> expense_total_minor then
    raise exception 'Shares must equal expense total' using errcode = '23514';
  end if;
  if not exists (select 1 from public.cribs where id = target_crib_id and currency = expense_currency and deleted_at is null) then
    raise exception 'Crib currency mismatch' using errcode = '23514';
  end if;
  for share in select value from jsonb_array_elements(expense_shares) loop
    participant := (share->>'user_id')::uuid;
    if (share->>'share_minor')::bigint < 0 or not exists (select 1 from public.crib_members where crib_id=target_crib_id and user_id=participant and left_at is null) then
      raise exception 'Invalid share participant' using errcode = '23514';
    end if;
  end loop;
  if not exists (select 1 from public.crib_members where crib_id=target_crib_id and user_id=actor and left_at is null) then raise exception 'Invalid payer' using errcode='42501'; end if;
  insert into public.expenses(crib_id,description,total_minor,currency,payer_id,created_by,category,occurred_on)
  values(target_crib_id,trim(expense_description),expense_total_minor,expense_currency,actor,actor,trim(expense_category),expense_occurred_on) returning * into e;
  insert into public.expense_shares(expense_id,user_id,share_minor)
  select e.id,(value->>'user_id')::uuid,(value->>'share_minor')::bigint from jsonb_array_elements(expense_shares);
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(target_crib_id,actor,'expense_created',e.id);
  return e;
end $$;

revoke all on function public.create_expense(uuid,text,bigint,text,text,date,jsonb) from public;
revoke all on function public.create_expense(uuid,text,bigint,text,text,date,jsonb) from anon;
grant execute on function public.create_expense(uuid,text,bigint,text,text,date,jsonb) to authenticated;

create or replace function public.update_expense(
  target_expense_id uuid, expected_version bigint, expense_description text,
  expense_category text, expense_occurred_on date
) returns public.expenses language plpgsql security definer set search_path = '' as $$
declare e public.expenses; actor uuid := auth.uid();
begin
  select * into e from public.expenses where id=target_expense_id and deleted_at is null for update;
  if e is null then raise exception 'Expense not found' using errcode='P0002'; end if;
  if not app_private.is_active_crib_member(e.crib_id) or (actor <> e.created_by and actor <> e.payer_id and not app_private.is_crib_owner(e.crib_id)) then
    raise exception 'Not permitted to edit this expense' using errcode='42501'; end if;
  if e.version <> expected_version then raise exception 'Expense changed by another device' using errcode='40001'; end if;
  if exists (select 1 from public.settlements where crib_id=e.crib_id and status in ('confirmed','self_managed')) then raise exception 'Settled history is immutable' using errcode='23514'; end if;
  update public.expenses set description=trim(expense_description),category=trim(expense_category),occurred_on=expense_occurred_on,version=version+1,updated_at=now() where id=e.id returning * into e;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(e.crib_id,actor,'expense_updated',e.id);
  return e;
end $$;

create or replace function public.delete_expense(target_expense_id uuid, expected_version bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare e public.expenses; actor uuid := auth.uid();
begin
  select * into e from public.expenses where id=target_expense_id and deleted_at is null for update;
  if e is null then raise exception 'Expense not found' using errcode='P0002'; end if;
  if not app_private.is_active_crib_member(e.crib_id) or (actor <> e.created_by and actor <> e.payer_id and not app_private.is_crib_owner(e.crib_id)) then raise exception 'Not permitted to delete this expense' using errcode='42501'; end if;
  if e.version <> expected_version then raise exception 'Expense changed by another device' using errcode='40001'; end if;
  if exists (select 1 from public.settlements where crib_id=e.crib_id and status in ('confirmed','self_managed')) then raise exception 'Settled history is immutable' using errcode='23514'; end if;
  update public.expenses set deleted_at=now(),version=version+1,updated_at=now() where id=e.id;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(e.crib_id,actor,'expense_deleted',e.id);
end $$;

revoke all on function public.update_expense(uuid,bigint,text,text,date) from public;
revoke all on function public.delete_expense(uuid,bigint) from public;
revoke all on function public.update_expense(uuid,bigint,text,text,date) from anon;
revoke all on function public.delete_expense(uuid,bigint) from anon;
grant execute on function public.update_expense(uuid,bigint,text,text,date) to authenticated;
grant execute on function public.delete_expense(uuid,bigint) to authenticated;
