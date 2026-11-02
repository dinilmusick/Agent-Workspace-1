-- Permit dedicated, registered verifier agents to accept worker results.
create or replace function public.task_ledger_verify_result(
  task_id_in uuid, verifier_agent_id_in text, verified_in boolean, verification_report_in jsonb
) returns public.tasks
language plpgsql
set search_path to 'public'
as $function$
declare task_out public.tasks;
begin
  update public.tasks t
  set verification_status = case when verified_in then 'verified' else 'rejected' end,
      verification_report = coalesce(verification_report_in, '{}'::jsonb),
      verified_by_agent_id = verifier_agent_id_in,
      verified_at = now(),
      status = case when verified_in then 'completed' else 'queued' end,
      completed_at = case when verified_in then now() else null end,
      claimed_by_agent_id = case when verified_in then claimed_by_agent_id else null end,
      claimed_by_agent_name = case when verified_in then claimed_by_agent_name else null end,
      claim_token = case when verified_in then claim_token else null end,
      claim_expires_at = case when verified_in then claim_expires_at else null end,
      updated_at = now()
  where t.id = task_id_in and t.status = 'completed' and t.verification_status = 'pending'
    and (
      t.agent_id = verifier_agent_id_in
      or exists (select 1 from public.tasks p where p.id = t.parent_task_id and p.agent_id = verifier_agent_id_in)
      or exists (select 1 from public.agent_registry ar where ar.agent_id = verifier_agent_id_in and ar.enabled = true and ar.agent_type in ('verifier','orchestrator','supervisor'))
    );
  if not found then raise exception 'Task is not awaiting verification or verifier is not authorized'; end if;
  select * into task_out from public.tasks where id = task_id_in;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,case when verified_in then 'verified' else 'verification_rejected' end,
    verifier_agent_id_in,case when verified_in then 'Result independently verified' else 'Result rejected; task returned to queue' end,
    coalesce(verification_report_in, '{}'::jsonb));
  return task_out;
end;
$function$;

create or replace function public.task_ledger_finalize_parent(
  task_id_in uuid, verifier_agent_id_in text, outcome_in text, verification_report_in jsonb
) returns public.tasks
language plpgsql
set search_path to 'public'
as $function$
declare task_out public.tasks;
begin
  if not exists (select 1 from public.tasks where id = task_id_in and agent_id = verifier_agent_id_in)
    and not exists (select 1 from public.agent_registry ar where ar.agent_id = verifier_agent_id_in
      and ar.enabled = true and ar.agent_type in ('verifier','orchestrator','supervisor')) then
    raise exception 'Only the parent owner or an enabled verifier/orchestrator may finalize this task';
  end if;
  if exists (select 1 from public.tasks c where c.parent_task_id = task_id_in
    and not (c.status = 'completed' and c.verification_status = 'verified')) then
    raise exception 'Cannot finalize: one or more subtasks are not independently verified';
  end if;
  update public.tasks set status='completed',outcome=outcome_in,verification_status='verified',
    verification_report=coalesce(verification_report_in,'{}'::jsonb),verified_by_agent_id=verifier_agent_id_in,
    verified_at=now(),completed_at=now(),heartbeat_at=now(),updated_at=now()
  where id=task_id_in returning * into task_out;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'completed',verifier_agent_id_in,outcome_in,
    jsonb_build_object('verification_report',coalesce(verification_report_in,'{}'::jsonb),
      'children_summary',public.task_ledger_children_summary(task_id_in)));
  return task_out;
end;
$function$;
