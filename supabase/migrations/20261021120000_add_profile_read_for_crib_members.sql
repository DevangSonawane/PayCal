-- Members of a crib need each other's display name. The client reads the
-- names through the `crib_members -> profiles` embed, and the profile policy
-- only ever exposed a row to its owner. The embed was therefore filtered
-- away for everybody else, so a crib full of people showed up as "PayCal
-- member" for every member who was not the signed-in one.
--
-- The rule mirrors the membership rules: two people may read each other's
-- profile while both of them are active members of the same crib. Somebody
-- who left the crib keeps their own profile, but loses the names of the
-- people they used to share it with.
create policy "members can read the profiles of their crib members"
  on public.profiles for select to authenticated
  using (
    exists (
      select 1
      from public.crib_members mine
      join public.crib_members theirs on theirs.crib_id = mine.crib_id
      where mine.user_id = (select auth.uid())
        and mine.left_at is null
        and theirs.user_id = id
        and theirs.left_at is null
    )
  );
