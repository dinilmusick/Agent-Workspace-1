create or replace function public.goal_ledger_claim_task_by_key(
  goal_key_in text, agent_id_in text, agent_name_in text,
  agent_type_in text default 'worker', capabilities_in text[] default '{}',
  session_id_in text default null, lease_seconds_in integer default 900
) returns setof public.tasks language plpgsql set search_path=public
as $$
declare goal_out public.goals;
begin
  goal_out:=public.goal_ledger_get_by_key(goal_key_in);
  if goal_out.status='blocked' then
    raise exception 'goal is blocked; inspect and resolve its blocker before claiming a task';
  end if;
  if goal_out.status not in ('ready','active') then
    raise exception 'goal is not available for task claims: %',goal_out.status;
  end if;
  return query select * from public.goal_ledger_claim_task(
    goal_out.name,agent_id_in,agent_name_in,agent_type_in,capabilities_in,session_id_in,lease_seconds_in);
end;
$$;