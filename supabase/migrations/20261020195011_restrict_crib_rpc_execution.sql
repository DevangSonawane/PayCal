-- Supabase grants EXECUTE to API roles by default. These RPCs mutate data and
-- are exclusively for signed-in members; make the intended boundary explicit.
revoke all on function public.create_crib(text, text, text[]) from anon;
revoke all on function public.update_crib(uuid, bigint, text, text, text[]) from anon;
revoke all on function public.add_crib_member(uuid, uuid) from anon;
revoke all on function public.remove_crib_member(uuid, uuid) from anon;
revoke all on function public.delete_crib(uuid, bigint) from anon;

grant execute on function public.create_crib(text, text, text[]) to authenticated;
grant execute on function public.update_crib(uuid, bigint, text, text, text[]) to authenticated;
grant execute on function public.add_crib_member(uuid, uuid) to authenticated;
grant execute on function public.remove_crib_member(uuid, uuid) to authenticated;
grant execute on function public.delete_crib(uuid, bigint) to authenticated;
