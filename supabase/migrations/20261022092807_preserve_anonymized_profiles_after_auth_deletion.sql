-- Shared financial records retain profiles.id as their historical actor and
-- payer reference. An account deletion must therefore remove the Auth
-- identity without cascading into the anonymised profile or those records.
alter table public.profiles
  drop constraint if exists profiles_id_fkey;
