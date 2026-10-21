select cron.unschedule('dispatch-notifications-every-minute');

select cron.schedule(
  'dispatch-notifications-every-15-minutes',
  '*/15 * * * *',
  $$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'notification_dispatch_url'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-dispatch-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'notification_dispatch_secret')
      ),
      body := jsonb_build_object('scheduled_at', now()),
      timeout_milliseconds := 10000
    );
  $$
);

-- A 15-minute scheduler needs a delivery window instead of an exact minute.
-- The outbox event key keeps the reminder idempotent within that window.
create or replace function app_private.enqueue_due_reminders()
returns void language plpgsql security definer set search_path = '' as $$
declare schedule record;
declare local_now timestamp;
declare due_today boolean;
declare scheduled_time time;
begin
  for schedule in select * from public.recurring_schedules where active and payer_id is not null loop
    local_now := now() at time zone schedule.time_zone;
    scheduled_time := make_time(schedule.local_hour, schedule.local_minute, 0);
    due_today := schedule.start_date <= local_now::date
      and local_now::time >= scheduled_time
      and local_now::time < scheduled_time + interval '15 minutes'
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
