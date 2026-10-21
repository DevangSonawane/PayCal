-- Firebase device tokens and a durable outbox. Database mutations only enqueue
-- work: a server-only Edge Function delivers it later, so app clients never
-- need Firebase server credentials and writes are never blocked by FCM.
create table public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique check (char_length(token) between 20 and 4096),
  platform text not null check (platform in ('android', 'ios')),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  kind text not null check (kind in (
    'expense_created', 'expense_updated', 'expense_deleted',
    'settlement_requested', 'settlement_confirmed', 'settlement_cancelled',
    'member_joined', 'recurring_due'
  )),
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 240),
  data jsonb not null default '{}'::jsonb,
  event_key text unique,
  status text not null default 'pending' check (status in ('pending', 'processing', 'delivered', 'failed')),
  attempts smallint not null default 0 check (attempts >= 0 and attempts <= 10),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  delivered_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

create index push_devices_enabled_user_idx on public.push_devices (user_id) where enabled;
create index notification_outbox_ready_idx on public.notification_outbox (available_at, created_at)
  where status = 'pending';

alter table public.push_devices enable row level security;
alter table public.notification_outbox enable row level security;

-- Push tokens and message payloads are sensitive; neither table is exposed to
-- app users. The registration RPC and Edge Function are the only access path.
create or replace function public.register_push_device(
  device_token text,
  device_platform text,
  delivery_enabled boolean
) returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if char_length(device_token) < 20 or device_platform not in ('android', 'ios') then
    raise exception 'Invalid push device' using errcode = '23514';
  end if;
  insert into public.push_devices (user_id, token, platform, enabled)
  values (actor, device_token, device_platform, delivery_enabled)
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    enabled = excluded.enabled,
    updated_at = now(),
    last_seen_at = now();
end;
$$;

revoke all on function public.register_push_device(text, text, boolean) from public, anon;
grant execute on function public.register_push_device(text, text, boolean) to authenticated;

create or replace function app_private.enqueue_notification(
  target_recipient_id uuid, target_actor_id uuid, notification_kind text,
  notification_title text, notification_body text, notification_data jsonb default '{}'::jsonb,
  notification_event_key text default null
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if target_recipient_id = target_actor_id then return; end if;
  insert into public.notification_outbox (
    recipient_id, actor_id, kind, title, body, data, event_key
  ) values (
    target_recipient_id, target_actor_id, notification_kind, notification_title,
    notification_body, coalesce(notification_data, '{}'::jsonb), notification_event_key
  ) on conflict (event_key) do nothing;
end;
$$;

create or replace function app_private.enqueue_for_crib_members(
  target_crib_id uuid, target_actor_id uuid, notification_kind text,
  notification_title text, notification_body text, notification_data jsonb
) returns void language plpgsql security definer set search_path = '' as $$
declare member_id uuid;
begin
  for member_id in
    select user_id from public.crib_members
    where crib_id = target_crib_id and left_at is null and user_id <> target_actor_id
  loop
    perform app_private.enqueue_notification(member_id, target_actor_id, notification_kind,
      notification_title, notification_body, notification_data);
  end loop;
end;
$$;

create or replace function app_private.notify_expense_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare expense public.expenses;
declare actor_name text;
declare action_kind text := lower(tg_op);
begin
  if tg_op = 'DELETE' then expense := old; else expense := new; end if;
  -- A soft delete is an UPDATE; only notify when it newly becomes deleted.
  if tg_op = 'UPDATE' and new.deleted_at is not null and old.deleted_at is null then action_kind := 'delete';
  elsif tg_op = 'UPDATE' and new.deleted_at is not null then return new;
  elsif tg_op = 'UPDATE' then action_kind := 'update';
  elsif tg_op = 'INSERT' then action_kind := 'create';
  end if;
  select display_name into actor_name from public.profiles where id = auth.uid();
  perform app_private.enqueue_for_crib_members(
    expense.crib_id, auth.uid(), 'expense_' || action_kind || 'd', 'PayCal update',
    coalesce(actor_name, 'Someone') || case action_kind
      when 'create' then ' added ' || expense.description || '.'
      when 'update' then ' updated ' || expense.description || '.'
      else ' deleted ' || expense.description || '.' end,
    jsonb_build_object('type', 'expense', 'crib_id', expense.crib_id, 'expense_id', expense.id)
  );
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger notify_expense_changes
  after insert or update of description, category, occurred_on, deleted_at on public.expenses
  for each row execute procedure app_private.notify_expense_change();

create or replace function app_private.notify_settlement_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor_name text;
declare target_id uuid;
declare notification_kind text;
declare message text;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'pending' then return new; end if;
    target_id := new.to_user_id; notification_kind := 'settlement_requested';
    select display_name into actor_name from public.profiles where id = new.from_user_id;
    message := coalesce(actor_name, 'Someone') || ' requested a payment from you.';
  elsif new.status = old.status then return new;
  elsif new.status = 'confirmed' then
    target_id := new.from_user_id; notification_kind := 'settlement_confirmed';
    select display_name into actor_name from public.profiles where id = new.to_user_id;
    message := coalesce(actor_name, 'Someone') || ' confirmed your payment.';
  elsif new.status = 'cancelled' then
    target_id := new.to_user_id; notification_kind := 'settlement_cancelled';
    select display_name into actor_name from public.profiles where id = new.from_user_id;
    message := coalesce(actor_name, 'Someone') || ' cancelled a payment request.';
  else return new;
  end if;
  perform app_private.enqueue_notification(target_id, auth.uid(),
    notification_kind, 'Payment update', message,
    jsonb_build_object('type', 'settlement', 'crib_id', new.crib_id, 'settlement_id', new.id));
  return new;
end;
$$;

create trigger notify_settlement_changes
  after insert or update of status on public.settlements
  for each row execute procedure app_private.notify_settlement_change();

create or replace function app_private.notify_member_joined()
returns trigger language plpgsql security definer set search_path = '' as $$
declare crib_owner uuid;
declare member_name text;
begin
  -- Membership is also inserted at crib creation. The owner is not notified
  -- about joining their own brand-new crib.
  select owner_id into crib_owner from public.cribs where id = new.crib_id;
  if crib_owner = new.user_id then return new; end if;
  select display_name into member_name from public.profiles where id = new.user_id;
  perform app_private.enqueue_notification(
    crib_owner, new.user_id, 'member_joined', 'New crib member',
    coalesce(member_name, 'Someone') || ' joined your crib.',
    jsonb_build_object('type', 'crib', 'crib_id', new.crib_id)
  );
  return new;
end;
$$;

create trigger notify_member_joined
  after insert on public.crib_members
  for each row execute procedure app_private.notify_member_joined();

-- Called by the dispatcher every minute. The unique event key makes this
-- idempotent even when a scheduler retries the same minute.
create or replace function app_private.enqueue_due_reminders()
returns void language plpgsql security definer set search_path = '' as $$
declare schedule record;
declare local_now timestamp;
declare due_today boolean;
begin
  for schedule in
    select * from public.recurring_schedules
    where active and payer_id is not null
  loop
    local_now := now() at time zone schedule.time_zone;
    due_today := schedule.start_date <= local_now::date
      and extract(hour from local_now)::smallint = schedule.local_hour
      and extract(minute from local_now)::smallint = schedule.local_minute
      and case schedule.frequency
        when 'monthly' then least(schedule.anchor_day,
          extract(day from (date_trunc('month', local_now)::date + interval '1 month - 1 day'))::smallint)
          = extract(day from local_now)::smallint
        when 'yearly' then extract(month from schedule.start_date) = extract(month from local_now)
          and least(schedule.anchor_day,
            extract(day from (date_trunc('month', local_now)::date + interval '1 month - 1 day'))::smallint)
            = extract(day from local_now)::smallint
        else false end;
    if due_today then
      perform app_private.enqueue_notification(
        schedule.payer_id, null, 'recurring_due', 'Payment due today',
        schedule.description || ' is due today.',
        jsonb_build_object('type', 'recurring', 'crib_id', schedule.crib_id, 'schedule_id', schedule.id),
        'recurring:' || schedule.id || ':' || local_now::date
      );
    end if;
  end loop;
end;
$$;

-- Atomic leasing prevents concurrent function invocations sending a job twice.
create or replace function app_private.claim_notification_jobs(batch_size integer default 100)
returns setof public.notification_outbox language plpgsql security definer set search_path = '' as $$
begin
  return query
  with candidates as (
    select id from public.notification_outbox
    where (status = 'pending' and available_at <= now())
       or (status = 'processing' and locked_at < now() - interval '10 minutes')
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

revoke all on function app_private.enqueue_notification(uuid, uuid, text, text, text, jsonb, text),
  app_private.enqueue_for_crib_members(uuid, uuid, text, text, text, jsonb),
  app_private.enqueue_due_reminders(), app_private.claim_notification_jobs(integer) from public, anon, authenticated;

-- The Edge Function uses the service-role key. These public-schema wrappers
-- are deliberately not executable by normal app roles.
create or replace function public.process_push_due_reminders()
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform app_private.enqueue_due_reminders();
end;
$$;

create or replace function public.claim_push_notification_jobs(batch_size integer default 100)
returns setof public.notification_outbox language plpgsql security definer set search_path = '' as $$
begin
  return query select * from app_private.claim_notification_jobs(batch_size);
end;
$$;

revoke all on function public.process_push_due_reminders(), public.claim_push_notification_jobs(integer) from public, anon, authenticated;
grant execute on function public.process_push_due_reminders(), public.claim_push_notification_jobs(integer) to service_role;
