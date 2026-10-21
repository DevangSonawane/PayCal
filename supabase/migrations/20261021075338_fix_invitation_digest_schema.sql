-- The invitation functions run with an empty search path. pgcrypto lives in
-- `extensions`, so its digest function must be fully qualified.
create or replace function public.create_invitation(target_crib_id uuid, invitation_token text, invitation_expires_at timestamptz)
returns public.invitations language plpgsql security definer set search_path = '' as $$
declare result public.invitations; actor uuid := auth.uid();
begin
  if actor is null or not app_private.is_crib_owner(target_crib_id) then raise exception 'Only the Crib Owner may invite members' using errcode='42501'; end if;
  if invitation_expires_at <= now() or char_length(invitation_token) < 16 then raise exception 'Invalid invitation' using errcode='23514'; end if;
  insert into public.invitations(crib_id,token_hash,created_by,expires_at)
  values(target_crib_id,encode(extensions.digest(invitation_token, 'sha256'),'hex'),actor,invitation_expires_at)
  returning * into result;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(target_crib_id,actor,'invitation_created',result.id);
  return result;
end $$;

create or replace function public.accept_invitation(invitation_token text)
returns public.cribs language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); invitation public.invitations; result public.cribs;
begin
  if actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into invitation from public.invitations
  where token_hash=encode(extensions.digest(invitation_token, 'sha256'),'hex') for update;
  if invitation is null or invitation.revoked_at is not null or invitation.accepted_at is not null or invitation.expires_at <= now() then raise exception 'Invitation is not active' using errcode='42501'; end if;
  insert into public.crib_members(crib_id,user_id) values(invitation.crib_id,actor) on conflict(crib_id,user_id) do update set left_at=null;
  update public.invitations set accepted_by=actor,accepted_at=now() where id=invitation.id;
  select * into result from public.cribs where id=invitation.crib_id;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(invitation.crib_id,actor,'invitation_accepted',invitation.id);
  return result;
end $$;
