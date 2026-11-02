create or replace function public.task_ledger_verify_result(
  task_id_in uuid,
  verifier_agent_id_in text,
  verified_in boolean,
  verification_report_in jsonb
) returns public.tasks
language plpgsql set search_path=public
as $$
declare task_out public.tasks;
begin
  if exists(select 1 from public.tasks t where t.id=task_id_in
    and t.claimed_by_agent_id=verifier_agent_id_in) then
    raise exception 'worker cannot verify its own submitted result';
  end if;
  if not exists(
    select 1 from public.tasks t where t.id=task_id_in and (
      (auth.uid() is not null and t.owner_user_id=auth.uid())
      or exists(select 1 from public.tasks p where p.id=t.parent_task_id and p.agent_id=verifier_agent_id_in)
      or exists(select 1 from public.agent_registry a where a.agent_id=verifier_agent_id_in
        and a.enabled and a.agent_type in ('verifier','orchestrator','supervisor'))
    )
  ) then raise exception 'independent verifier identity is not authorized for this owner'; end if;

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

create or replace function public.task_ledger_record_parent_loop_iteration(
  task_id_in uuid,
  agent_id_in text,
  iteration_no_in integer,
  input_payload_in jsonb,
  output_payload_in jsonb,
  observation_in jsonb,
  criterion_results_in jsonb,
  loop_state_in jsonb,
  tools_used_in jsonb default '[]'::jsonb,
  evidence_in jsonb default '[]'::jsonb,
  verdict_in text default 'continue',
  next_action_in text default null
) returns public.task_iterations
language plpgsql set search_path=public
as $$
declare task_out public.tasks; iteration_out public.task_iterations;
  criterion_count integer; satisfied_count integer; max_allowed integer;
begin
  select * into task_out from public.tasks
  where id=task_id_in
    and (agent_id=agent_id_in or (auth.uid() is not null and owner_user_id=auth.uid()))
    and status in ('queued','running','blocked')
    and exists(select 1 from public.tasks child where child.parent_task_id=tasks.id)
  for update;
  if not found then raise exception 'parent task must belong to this owner and have children'; end if;
  if jsonb_typeof(criterion_results_in)<>'array' or jsonb_array_length(criterion_results_in)=0 then
    raise exception 'criterion_results must be a non-empty array';
  end if;
  if verdict_in not in ('continue','pass','error','blocked','cancelled') then
    raise exception 'invalid loop verdict';
  end if;
  max_allowed:=coalesce((task_out.loop_definition->>'max_iterations')::integer,8);
  if iteration_no_in<1 or iteration_no_in>max_allowed or iteration_no_in<>task_out.loop_iteration+1 then
    raise exception 'parent loop iteration must be sequential and within its budget';
  end if;
  select count(*),count(*) filter(where value->>'status'='satisfied')
    into criterion_count,satisfied_count from jsonb_array_elements(criterion_results_in);
  if exists(select 1 from jsonb_array_elements(criterion_results_in) c
    where c->>'status' not in ('satisfied','unsatisfied','unknown')) then
    raise exception 'invalid criterion status';
  end if;
  if verdict_in='pass' then
    if criterion_count<>satisfied_count or jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))=0 then
      raise exception 'parent loop pass requires every criterion satisfied with evidence';
    end if;
    if exists(select 1 from public.tasks child where child.parent_task_id=task_id_in
      and not (child.status='completed' and child.verification_status='verified')) then
      raise exception 'parent loop cannot pass until every child is independently verified';
    end if;
    if exists(select 1 from public.tasks child where child.parent_task_id=task_id_in
      and child.claimed_by_agent_id=agent_id_in) then
      raise exception 'parent loop evaluator must be independent from child workers';
    end if;
    perform public.task_ledger_validate_parameter_values(task_out.parameter_contract,task_out.parameter_values);
  end if;
  insert into public.task_iterations(task_id,iteration_no,agent_id,status,input_payload,
    output_payload,observation,decision,tools_used,evidence,completed_at)
  values(task_id_in,iteration_no_in,agent_id_in,'completed',coalesce(input_payload_in,'{}'::jsonb),
    coalesce(output_payload_in,'{}'::jsonb),
    coalesce(observation_in,'{}'::jsonb)||jsonb_build_object(
      'criterionResults',criterion_results_in,'loopState',coalesce(loop_state_in,'{}'::jsonb)),
    verdict_in||case when next_action_in is null then '' else ': '||next_action_in end,
    coalesce(tools_used_in,'[]'::jsonb),coalesce(evidence_in,'[]'::jsonb),now())
  returning * into iteration_out;
  update public.tasks set loop_iteration=iteration_no_in,loop_state=coalesce(loop_state_in,'{}'::jsonb),
    heartbeat_at=now(),updated_at=now(),current_step=coalesce(next_action_in,'Parent loop iteration recorded')
  where id=task_id_in;
  if verdict_in='pass' then
    update public.tasks set status='completed',verification_status='verified',
      verification_report=jsonb_build_object('parent_loop_iteration',iteration_no_in,
        'criterion_results',criterion_results_in,'evidence',coalesce(evidence_in,'[]'::jsonb)),
      verified_by_agent_id=agent_id_in,verified_at=now(),completed_at=now(),
      outcome=coalesce(next_action_in,'Parent task loop passed after all children were verified'),
      updated_at=now()
    where id=task_id_in;
    insert into public.task_events(task_id,event_type,agent_id,message,payload)
    values(task_id_in,'completed',agent_id_in,'Parent task loop passed; parent marked verified',
      jsonb_build_object('iteration_no',iteration_no_in,'evidence',coalesce(evidence_in,'[]'::jsonb)));
  end if;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'loop_iteration_recorded',agent_id_in,coalesce(next_action_in,verdict_in),
    jsonb_build_object('iteration_no',iteration_no_in,'verdict',verdict_in,
      'criterion_results',criterion_results_in,
      'evidence_count',jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))));
  return iteration_out;
end;
$$;

create or replace function public.goal_ledger_finalize(
  goal_name_in text,
  finalized_by_agent_id_in text,
  verification_report_in jsonb default '{}'::jsonb
) returns public.goals
language plpgsql set search_path=public
as $$
declare goal_out public.goals; changed integer;
begin
  select * into goal_out from public.goals
  where lower(name)=lower(btrim(goal_name_in))
    and (auth.uid() is null or owner_user_id=auth.uid())
  for update;
  if not found then raise exception 'goal not found or access denied'; end if;
  if goal_out.created_by_agent_id<>finalized_by_agent_id_in
     and not (auth.uid() is not null and goal_out.owner_user_id=auth.uid())
     and not exists(select 1 from public.agent_registry a
       where a.agent_id=finalized_by_agent_id_in and a.enabled
         and a.agent_type in ('orchestrator','verifier','supervisor')) then
    raise exception 'goal finalization requires its orchestrator, owner-scoped chat agent or enabled verifier';
  end if;
  if exists(select 1 from public.tasks t where t.goal_id=goal_out.id
    and t.claimed_by_agent_id=finalized_by_agent_id_in) then
    raise exception 'goal finalizer must be independent from all task workers';
  end if;

  if exists(
    select 1 from public.tasks p where p.goal_id=goal_out.id
      and exists(select 1 from public.tasks c where c.parent_task_id=p.id)
      and not exists(
        select 1 from public.task_iterations i where i.task_id=p.id
          and i.iteration_no=(select max(ix.iteration_no) from public.task_iterations ix where ix.task_id=p.id)
          and i.decision like 'pass%'
          and jsonb_typeof(i.observation->'criterionResults')='array'
          and jsonb_array_length(i.observation->'criterionResults')>0
          and not exists(select 1 from jsonb_array_elements(i.observation->'criterionResults') c
            where c->>'status'<>'satisfied')
          and jsonb_array_length(i.evidence)>0
      )
  ) then raise exception 'goal cannot complete: every parent task must pass its own Loop Generator cycle'; end if;

  loop
    update public.tasks p set status='completed',verification_status='verified',
      verification_report=coalesce(verification_report_in,'{}'::jsonb),
      verified_by_agent_id=finalized_by_agent_id_in,verified_at=now(),completed_at=now(),
      outcome=coalesce(p.outcome,'All child tasks independently verified'),updated_at=now()
    where p.goal_id=goal_out.id
      and exists(select 1 from public.tasks c where c.parent_task_id=p.id)
      and not (p.status='completed' and p.verification_status='verified')
      and not exists(select 1 from public.tasks c where c.parent_task_id=p.id
        and not (c.status='completed' and c.verification_status='verified'));
    get diagnostics changed=row_count;
    exit when changed=0;
  end loop;
  if exists(select 1 from public.tasks t where t.goal_id=goal_out.id
    and not (t.status='completed' and t.verification_status in ('verified','not_required'))) then
    raise exception 'goal cannot complete: one or more tasks are unfinished or unverified';
  end if;
  update public.goals set status='completed',completed_at=now(),updated_at=now()
    where id=goal_out.id returning * into goal_out;
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
  values(goal_out.id,'completed',finalized_by_agent_id_in,
    'Goal loop passed and all descendant tasks independently verified',
    jsonb_build_object('goal_key',goal_out.goal_key,
      'verification_report',coalesce(verification_report_in,'{}'::jsonb)));
  return goal_out;
end;
$$;
