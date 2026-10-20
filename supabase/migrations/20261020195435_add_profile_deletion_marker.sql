-- A deleted identity remains referenced by shared financial history. The
-- Edge Function performs the privileged anonymisation and session revocation.
alter table public.profiles
  add column deleted_at timestamptz;
