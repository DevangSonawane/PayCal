-- The client has no write grants on ledger tables. These small, atomic RPCs
-- are the only mutation surface exposed to a signed-in member.
create or replace function public.create_settlement(
  target_crib_id uuid, recipient_id uuid, settlement_amount_minor bigint,
  settlement_currency text, settlement_status text, settlement_idempotency_key text
) returns public.settlements language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.settlements; debt bigint;
begin
  if actor is null or not app_private.is_active_crib_member(target_crib_id) then
    raise exception 'Active membership required' using errcode = '42501';
  end if;
  if settlement_status not in ('pending', 'self_managed') or settlement_amount_minor <= 0 then
    raise exception 'Invalid settlement' using errcode = '23514';
  end if;
  if not exists (select 1 from public.cribs where id = target_crib_id and currency = upper(trim(settlement_currency)) and deleted_at is null)
     or not exists (select 1 from public.crib_members where crib_id = target_crib_id and user_id = recipient_id and left_at is null)
     or recipient_id = actor then
    raise exception 'Invalid settlement participants or currency' using errcode = '23514';
  end if;
  select coalesce(sum(s.share_minor), 0) - coalesce((select sum(amount_minor) from public.settlements where crib_id=target_crib_id and from_user_id=actor and to_user_id=recipient_id and status in ('confirmed','self_managed')), 0)
    into debt
  from public.expenses e join public.expense_shares s on s.expense_id=e.id
  where e.crib_id=target_crib_id and e.payer_id=recipient_id and s.user_id=actor and e.deleted_at is null;
  if settlement_amount_minor > debt then raise exception 'Settlement exceeds outstanding debt' using errcode='23514'; end if;
  insert into public.settlements(crib_id,currency,from_user_id,to_user_id,amount_minor,status,idempotency_key)
  values(target_crib_id,upper(trim(settlement_currency)),actor,recipient_id,settlement_amount_minor,settlement_status,settlement_idempotency_key)
  on conflict (crib_id,from_user_id,idempotency_key) do update set idempotency_key=excluded.idempotency_key
  returning * into result;
  if result.amount_minor <> settlement_amount_minor or result.to_user_id <> recipient_id then raise exception 'Idempotency key reused with different payload' using errcode='23505'; end if;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(target_crib_id,actor,'settlement_created',result.id);
  return result;
end $$;

create or replace function public.update_settlement_status(target_settlement_id uuid, expected_version bigint, next_status text)
returns public.settlements language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.settlements;
begin
  select * into result from public.settlements where id=target_settlement_id for update;
  if result is null then raise exception 'Settlement not found' using errcode='P0002'; end if;
  if result.version <> expected_version then raise exception 'Settlement changed by another device' using errcode='40001'; end if;
  if result.status <> 'pending' or not ((next_status='confirmed' and actor=result.to_user_id) or (next_status='cancelled' and actor=result.from_user_id)) then
    raise exception 'Settlement transition is not allowed' using errcode='42501';
  end if;
  update public.settlements set status=next_status,version=version+1,updated_at=now() where id=result.id returning * into result;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(result.crib_id,actor,'settlement_' || next_status,result.id);
  return result;
end $$;

create or replace function public.create_invitation(target_crib_id uuid, invitation_token text, invitation_expires_at timestamptz)
returns public.invitations language plpgsql security definer set search_path = '' as $$
declare result public.invitations; actor uuid := auth.uid();
begin
  if actor is null or not app_private.is_crib_owner(target_crib_id) then raise exception 'Only the Crib Owner may invite members' using errcode='42501'; end if;
  if invitation_expires_at <= now() or char_length(invitation_token) < 16 then raise exception 'Invalid invitation' using errcode='23514'; end if;
  insert into public.invitations(crib_id,token_hash,created_by,expires_at) values(target_crib_id,encode(digest(invitation_token, 'sha256'),'hex'),actor,invitation_expires_at) returning * into result;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(target_crib_id,actor,'invitation_created',result.id);
  return result;
end $$;

create or replace function public.accept_invitation(invitation_token text)
returns public.cribs language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); invitation public.invitations; result public.cribs;
begin
  if actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into invitation from public.invitations where token_hash=encode(digest(invitation_token, 'sha256'),'hex') for update;
  if invitation is null or invitation.revoked_at is not null or invitation.accepted_at is not null or invitation.expires_at <= now() then raise exception 'Invitation is not active' using errcode='42501'; end if;
  insert into public.crib_members(crib_id,user_id) values(invitation.crib_id,actor) on conflict(crib_id,user_id) do update set left_at=null;
  update public.invitations set accepted_by=actor,accepted_at=now() where id=invitation.id;
  select * into result from public.cribs where id=invitation.crib_id;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(invitation.crib_id,actor,'invitation_accepted',invitation.id);
  return result;
end $$;

create or replace function public.revoke_invitation(target_invitation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare invitation public.invitations;
begin
  select * into invitation from public.invitations where id=target_invitation_id for update;
  if invitation is null then raise exception 'Invitation not found' using errcode='P0002'; end if;
  if not app_private.is_crib_owner(invitation.crib_id) then raise exception 'Only the Crib Owner may revoke invitations' using errcode='42501'; end if;
  update public.invitations set revoked_at=now() where id=invitation.id and revoked_at is null;
  insert into public.activity_events(crib_id,actor_id,action,target_id) values(invitation.crib_id,auth.uid(),'invitation_revoked',invitation.id);
end $$;

revoke all on function public.create_settlement(uuid,uuid,bigint,text,text,text), public.update_settlement_status(uuid,bigint,text), public.create_invitation(uuid,text,timestamptz), public.accept_invitation(text), public.revoke_invitation(uuid) from public, anon;
grant execute on function public.create_settlement(uuid,uuid,bigint,text,text,text), public.update_settlement_status(uuid,bigint,text), public.create_invitation(uuid,text,timestamptz), public.accept_invitation(text), public.revoke_invitation(uuid) to authenticated;

create index settlements_pair_status_idx on public.settlements (crib_id, from_user_id, to_user_id, status);
create index activity_events_actor_id_idx on public.activity_events (actor_id);
create index expenses_created_by_idx on public.expenses (created_by);
create index invitations_created_by_idx on public.invitations (created_by);
create index invitations_accepted_by_idx on public.invitations (accepted_by);
