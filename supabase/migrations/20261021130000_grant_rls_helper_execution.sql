-- Row level security policies call these helpers on behalf of the signed in
-- user, so the authenticated role needs to be able to execute them.
--
-- The initial foundation migration revoked execution on every function in the
-- app_private schema from the api roles. That was meant to keep the internal
-- helpers invisible, but it also removed the execution right the policies
-- depend on: every read from cribs, crib_members, profiles, expenses,
-- settlements and invitations failed with "permission denied for function
-- was_crib_member".
--
-- These three helpers stay safe to expose. They are security definer, they
-- always resolve the caller through auth.uid() and they take no user id as an
-- argument, so a signed in user cannot use them to inspect anybody else's
-- data.
grant execute on function app_private.was_crib_member(uuid) to authenticated;
grant execute on function app_private.is_active_crib_member(uuid) to authenticated;
grant execute on function app_private.is_crib_owner(uuid) to authenticated;
