-- Owner-managed recurring schedules and idempotent occurrence generation.
create or replace function public.create_recurring_schedule(
  target_crib_id uuid, schedule_description text, schedule_amount_minor bigint,
  schedule_currency text, schedule_category text, schedule_frequency text,
  schedule_recipient_id uuid, schedule_start_date date, schedule_time_zone text,
  schedule_local_hour smallint, schedule_local_minute smallint, schedule_anchor_day smallint
) returns public.recurring_schedules language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.recurring_schedules;
begin
  if actor is null or not app_private.is_crib_owner(target_crib_id) then raise exception 'Only the Crib Owner may manage recurring transfers' using errcode='42501'; end if;
  if schedule_amount_minor <= 0 or schedule_frequency not in ('monthly','yearly') or trim(schedule_time_zone)='' or not exists(select 1 from public.cribs where id=target_crib_id and currency=upper(trim(schedule_currency)) and deleted_at is null) or not exists(select 1 from public.crib_members where crib_id=target_crib_id and user_id=schedule_recipient_id and left_at is null) then raise exception 'Invalid recurring transfer' using errcode='23514'; end if;
  insert into public.recurring_schedules(crib_id,description,amount_minor,currency,category,frequency,recipient_id,created_by,payer_id,start_date,time_zone,local_hour,local_minute,anchor_day)
  values(target_crib_id,trim(schedule_description),schedule_amount_minor,upper(trim(schedule_currency)),trim(schedule_category),schedule_frequency,schedule_recipient_id,actor,actor,schedule_start_date,trim(schedule_time_zone),schedule_local_hour,schedule_local_minute,schedule_anchor_day) returning * into result;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(target_crib_id,actor,'recurring_created',result.id);
  return result;
end $$;

create or replace function public.update_recurring_schedule(target_schedule_id uuid, schedule_description text, schedule_amount_minor bigint, schedule_category text, schedule_frequency text, schedule_recipient_id uuid, schedule_start_date date, schedule_time_zone text, schedule_local_hour smallint, schedule_local_minute smallint, schedule_anchor_day smallint)
returns public.recurring_schedules language plpgsql security definer set search_path = '' as $$
declare result public.recurring_schedules;
begin
  select * into result from public.recurring_schedules where id=target_schedule_id for update;
  if result is null then raise exception 'Recurring transfer not found' using errcode='P0002'; end if;
  if not result.active or not app_private.is_crib_owner(result.crib_id) then raise exception 'Recurring transfer cannot be changed' using errcode='42501'; end if;
  update public.recurring_schedules set description=trim(schedule_description),amount_minor=schedule_amount_minor,category=trim(schedule_category),frequency=schedule_frequency,recipient_id=schedule_recipient_id,start_date=schedule_start_date,time_zone=trim(schedule_time_zone),local_hour=schedule_local_hour,local_minute=schedule_local_minute,anchor_day=schedule_anchor_day,updated_at=now() where id=result.id returning * into result;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(result.crib_id,auth.uid(),'recurring_updated',result.id);
  return result;
end $$;

create or replace function public.set_recurring_schedule_state(target_schedule_id uuid, next_active boolean, next_payer_id uuid default null)
returns public.recurring_schedules language plpgsql security definer set search_path = '' as $$
declare result public.recurring_schedules;
begin
  select * into result from public.recurring_schedules where id=target_schedule_id for update;
  if result is null or not app_private.is_crib_owner(result.crib_id) then raise exception 'Only the Crib Owner may manage recurring transfers' using errcode='42501'; end if;
  if next_active and (next_payer_id is null or not exists(select 1 from public.crib_members where crib_id=result.crib_id and user_id=next_payer_id and left_at is null)) then raise exception 'Payer must be an active member' using errcode='23514'; end if;
  update public.recurring_schedules set active=next_active,payer_id=case when next_active then coalesce(next_payer_id,payer_id) else payer_id end,updated_at=now() where id=result.id returning * into result;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(result.crib_id,auth.uid(),case when next_active then 'recurring_payer_assigned' else 'recurring_cancelled' end,result.id);
  return result;
end $$;

create or replace function public.generate_recurring_occurrence(target_schedule_id uuid, target_due_date date)
returns public.expenses language plpgsql security definer set search_path = '' as $$
declare schedule public.recurring_schedules; result public.expenses; actor uuid := auth.uid();
begin
  select * into schedule from public.recurring_schedules where id=target_schedule_id for update;
  if schedule is null or actor is null or not app_private.is_active_crib_member(schedule.crib_id) then raise exception 'Active membership required' using errcode='42501'; end if;
  if not schedule.active or schedule.payer_id is null or not exists(select 1 from public.crib_members where crib_id=schedule.crib_id and user_id=schedule.payer_id and left_at is null) then raise exception 'Recurring transfer is paused or cancelled' using errcode='23514'; end if;
  select e.* into result from public.recurring_occurrences o join public.expenses e on e.id=o.expense_id where o.schedule_id=schedule.id and o.due_date=target_due_date;
  if result is not null then return result; end if;
  insert into public.expenses(crib_id,description,total_minor,currency,payer_id,created_by,category,occurred_on)
  values(schedule.crib_id,trim(schedule.description),schedule.amount_minor,schedule.currency,schedule.payer_id,schedule.payer_id,schedule.category,target_due_date) returning * into result;
  insert into public.expense_shares(expense_id,user_id,share_minor) values(result.id,schedule.payer_id,schedule.amount_minor);
  insert into public.recurring_occurrences(schedule_id,due_date,expense_id) values(schedule.id,target_due_date,result.id);
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(schedule.crib_id,actor,'recurring_generated',result.id);
  return result;
end $$;

revoke all on function public.create_recurring_schedule(uuid,text,bigint,text,text,text,uuid,date,text,smallint,smallint,smallint), public.update_recurring_schedule(uuid,text,bigint,text,text,uuid,date,text,smallint,smallint,smallint), public.set_recurring_schedule_state(uuid,boolean,uuid), public.generate_recurring_occurrence(uuid,date) from public, anon;
grant execute on function public.create_recurring_schedule(uuid,text,bigint,text,text,text,uuid,date,text,smallint,smallint,smallint), public.update_recurring_schedule(uuid,text,bigint,text,text,uuid,date,text,smallint,smallint,smallint), public.set_recurring_schedule_state(uuid,boolean,uuid), public.generate_recurring_occurrence(uuid,date) to authenticated;

create index recurring_schedules_recipient_id_idx on public.recurring_schedules (recipient_id);
create index recurring_schedules_created_by_idx on public.recurring_schedules (created_by);
create index recurring_schedules_payer_id_idx on public.recurring_schedules (payer_id);
