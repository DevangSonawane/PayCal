-- The values below are added to Vault after deployment; the scheduled SQL
-- resolves them at run time so no credential enters this repository.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'dispatch-notifications-every-minute',
  '* * * * *',
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
