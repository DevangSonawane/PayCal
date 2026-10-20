create or replace function public.flag_expense_dispute(target_expense_id uuid)
returns public.expenses
language plpgsql
security definer
set search_path = ''
as $$
declare
  expense public.expenses;
begin
  select * into expense
  from public.expenses
  where id = target_expense_id and deleted_at is null
  for update;
  if expense is null then
    raise exception 'Expense not found' using errcode = 'P0002';
  end if;
  if not app_private.is_active_crib_member(expense.crib_id) then
    raise exception 'Active membership required' using errcode = '42501';
  end if;
  update public.expenses
  set disputed_at = coalesce(disputed_at, now()),
      version = version + 1,
      updated_at = now()
  where id = expense.id
  returning * into expense;
  insert into public.activity_events (crib_id, actor_id, action, target_id)
  values (expense.crib_id, auth.uid(), 'expense_disputed', expense.id);
  return expense;
end;
$$;

revoke all on function public.flag_expense_dispute(uuid) from public;
revoke all on function public.flag_expense_dispute(uuid) from anon;
grant execute on function public.flag_expense_dispute(uuid) to authenticated;
