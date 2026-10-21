-- Members can leave a crib on their own and an owner can hand a crib over.
--
-- Leaving a crib is not a deletion: the membership keeps its history, so the
-- expenses and settlements of the member that left keep validating. A member
-- that left can still read the crib, but is never charged again.
--
-- The owner cannot leave a crib they still own. The crib has to be handed
-- over first, so a crib never ends up without an owner.

create or replace function public.leave_crib(target_crib_id uuid)
returns public.crib_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  owner_id uuid;
  membership public.crib_members;
begin
  if actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select crib.owner_id into owner_id
  from public.cribs crib
  where crib.id = target_crib_id and crib.deleted_at is null
  for update;

  if owner_id is null then
    raise exception 'Crib not found' using errcode = 'P0002';
  end if;

  if owner_id = actor then
    raise exception 'Transfer ownership before leaving the crib' using errcode = '23514';
  end if;

  update public.crib_members
  set left_at = now()
  where crib_id = target_crib_id and user_id = actor and left_at is null
  returning * into membership;

  if membership is null then
    raise exception 'Active membership not found' using errcode = 'P0002';
  end if;

  -- A schedule the member paid for pauses instead of running on without a
  -- payer. The owner assigns a new payer, the schedule resumes.
  update public.recurring_schedules
  set active = false, updated_at = now()
  where crib_id = target_crib_id and payer_id = actor and active;

  insert into public.activity_events(crib_id, actor_id, action, target_id)
  values (target_crib_id, actor, 'member_left', actor);

  return membership;
end;
$$;

create or replace function public.transfer_crib_ownership(
  target_crib_id uuid,
  new_owner_id uuid
)
returns public.cribs
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  updated_crib public.cribs;
begin
  if actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not app_private.is_crib_owner(target_crib_id) then
    raise exception 'Only the Crib Owner may hand over the crib' using errcode = '42501';
  end if;

  if new_owner_id = actor then
    raise exception 'You already own this crib' using errcode = '23514';
  end if;

  if not exists (
    select 1 from public.crib_members membership
    where membership.crib_id = target_crib_id
      and membership.user_id = new_owner_id
      and membership.left_at is null
  ) then
    raise exception 'The new owner has to be an active member' using errcode = '23514';
  end if;

  update public.cribs
  set owner_id = new_owner_id, version = version + 1, updated_at = now()
  where id = target_crib_id and deleted_at is null
  returning * into updated_crib;

  if updated_crib is null then
    raise exception 'Crib not found' using errcode = 'P0002';
  end if;

  insert into public.activity_events(crib_id, actor_id, action, target_id)
  values (target_crib_id, actor, 'ownership_transferred', new_owner_id);

  return updated_crib;
end;
$$;

revoke all on function public.leave_crib(uuid), public.transfer_crib_ownership(uuid, uuid) from public, anon;
grant execute on function public.leave_crib(uuid), public.transfer_crib_ownership(uuid, uuid) to authenticated;

-- Immediate delivery for transactional notifications.
--
-- The scheduler sweeps the whole outbox every few minutes, which is the right
-- pace for recurring reminders. A member who just added an expense should not
-- wait for that sweep: the app of the member who did something asks for the
-- transactional notifications to be sent right away.
--
-- Only transactional kinds are claimed this way. A recurring reminder keeps
-- its own pace and is never delivered early by a member's device.

create or replace function app_private.claim_transactional_notification_jobs(
  batch_size integer default 100
)
returns setof public.notification_outbox
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with candidates as (
    select id from public.notification_outbox
    where kind <> 'recurring_due'
      and ((status = 'pending' and available_at <= now())
        or (status = 'processing' and locked_at < now() - interval '10 minutes'))
    order by available_at, created_at
    limit greatest(1, least(batch_size, 250))
    for update skip locked
  )
  update public.notification_outbox job
  set status = 'processing', locked_at = now(), attempts = attempts + 1
  from candidates where job.id = candidates.id
  returning job.*;
end;
$$;

create or replace function public.claim_push_transactional_jobs(
  batch_size integer default 100
)
returns setof public.notification_outbox
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  return query
  select * from app_private.claim_transactional_notification_jobs(batch_size);
end;
$$;

revoke all on function app_private.claim_transactional_notification_jobs(integer) from public, anon, authenticated;
revoke all on function public.claim_push_transactional_jobs(integer) from public, anon;
grant execute on function public.claim_push_transactional_jobs(integer) to authenticated;
