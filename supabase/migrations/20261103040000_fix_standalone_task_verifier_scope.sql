-- Keep goal ownership checks while permitting parent-agent verification of standalone task trees.
create or replace function public.task_ledger_verify_result(
  task_id_in uuid, verifier_agent_id_in text, verified_in boolean,
  verification_report_in jsonb
) returns public.tasks language plpgsql set search_path=public
as $$
declare task_out public.tasks;
begin
  if exists(select 1 from public.tasks t where t.id=task_id_in
    and t.claimed_by_agent_id=verifier_agent_id_in) then
    raise exception 'worker cannot verify its own submitted result';
  end if;
  if not exists(
    select 1 from public.tasks t
    left join public.goals g on g.id=t.goal_id
    where t.id=task_id_in and (
      (g.id is not null and auth.uid() is not null and g.owner_user_id=auth.uid())
      or (g.id is not null and auth.uid() is null and g.owner_user_id is null)
      or exists(select 1 from public.tasks p where p.id=t.parent_task_id and p.agent_id=verifier_agent_id_in)
      or exists(select 1 from public.agent_registry a where a.agent_id=verifier_agent_id_in
        and a.enabled and a.agent_type in ('verifier','orchestrator','supervisor'))
    )
  ) then raise exception 'independent verifier is not authorized for this workspace'; end if;
  update public.tasks t set
    verification_status=case when verified_in then 'verified' else 'rejected' end,
    verification_report=coalesce(verification_report_in,'{}'::jsonb),
    verified_by_agent_id=verifier_agent_id_in,verified_at=now(),
    status=case when verified_in then 'completed' else 'queued' end,
    completed_at=case when verified_in then now() else null end,
    claimed_by_agent_id=case when verified_in then claimed_by_agent_id else null end,
    claimed_by_agent_name=case when verified_in then claimed_by_agent_name else null end,
    claim_token=case when verified_in then claim_token else null end,
    claim_expires_at=case when verified_in then claim_expires_at else null end,
    updated_at=now()
  where t.id=task_id_in and t.status='completed' and t.verification_status='pending';
  if not found then raise exception 'task is not awaiting verification'; end if;
  select * into task_out from public.tasks where id=task_id_in;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,case when verified_in then 'verified' else 'verification_rejected' end,
    verifier_agent_id_in,
    case when verified_in then 'Result independently verified' else 'Result rejected; task returned to queue' end,
    coalesce(verification_report_in,'{}'::jsonb));
  return task_out;
end;
$$;
