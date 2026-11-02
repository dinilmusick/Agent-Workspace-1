create or replace function public.goal_ledger_record_loop_iteration(
  goal_id_in uuid, agent_id_in text, iteration_no_in integer,
  input_payload_in jsonb, output_payload_in jsonb, observation_in jsonb,
  criterion_results_in jsonb, loop_state_in jsonb,
  tools_used_in jsonb default '[]'::jsonb, evidence_in jsonb default '[]'::jsonb,
  verdict_in text default 'continue', next_action_in text default null
) returns public.goal_iterations language plpgsql set search_path=public
as $$
declare goal_out public.goals; iteration_out public.goal_iterations;
  criterion_count integer; satisfied_count integer; max_allowed integer;
begin
  if nullif(btrim(agent_id_in),'') is null then raise exception 'goal loop agent identity is required'; end if;
  if verdict_in not in ('continue','pass','error','blocked','cancelled') then raise exception 'invalid goal loop verdict'; end if;
  if coalesce(jsonb_typeof(criterion_results_in),'null')<>'array'
     or jsonb_array_length(coalesce(criterion_results_in,'[]'::jsonb))=0 then
    raise exception 'goal loop requires non-empty criterion results';
  end if;
  select * into goal_out from public.goals
  where id=goal_id_in and (auth.uid() is null or owner_user_id=auth.uid()) for update;
  if not found then raise exception 'goal not found or access denied'; end if;
  max_allowed:=coalesce((goal_out.goal_loop_definition->>'max_iterations')::integer,0);
  if iteration_no_in<1 or iteration_no_in>max_allowed
     or iteration_no_in<>goal_out.goal_loop_iteration+1 then
    raise exception 'goal loop iteration must be sequential and within its configured budget';
  end if;
  select count(*),count(*) filter(where value->>'status'='satisfied')
    into criterion_count,satisfied_count from jsonb_array_elements(criterion_results_in);
  if exists(select 1 from jsonb_array_elements(criterion_results_in) c
    where c->>'status' not in ('satisfied','unsatisfied','unknown')) then
    raise exception 'invalid goal criterion status';
  end if;
  if verdict_in='pass' then
    if criterion_count<>satisfied_count or jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))=0 then
      raise exception 'goal loop pass requires every criterion satisfied with evidence';
    end if;
    if exists(select 1 from public.tasks t where t.goal_id=goal_id_in
      and not (t.status='completed' and t.verification_status in ('verified','not_required'))) then
      raise exception 'goal loop cannot pass until every task is independently verified';
    end if;
    if exists(select 1 from public.tasks t where t.goal_id=goal_id_in
      and t.claimed_by_agent_id=agent_id_in) then
      raise exception 'goal loop evaluator must be independent from all task workers';
    end if;
  end if;
  insert into public.goal_iterations(goal_id,iteration_no,agent_id,input_payload,output_payload,
    observation,criterion_results,loop_state,tools_used,evidence,verdict,next_action)
  values(goal_id_in,iteration_no_in,agent_id_in,coalesce(input_payload_in,'{}'::jsonb),
    coalesce(output_payload_in,'{}'::jsonb),coalesce(observation_in,'{}'::jsonb),
    criterion_results_in,coalesce(loop_state_in,'{}'::jsonb),coalesce(tools_used_in,'[]'::jsonb),
    coalesce(evidence_in,'[]'::jsonb),verdict_in,next_action_in)
  returning * into iteration_out;
  update public.goals set goal_loop_iteration=iteration_no_in,
    goal_loop_state=coalesce(loop_state_in,'{}'::jsonb)||jsonb_build_object(
      'last_verdict',verdict_in,'next_action',next_action_in),
    status=case when status='ready' then 'active' else status end,updated_at=now()
  where id=goal_id_in;
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
  values(goal_id_in,'goal_loop_iteration_recorded',agent_id_in,coalesce(next_action_in,verdict_in),
    jsonb_build_object('iteration_no',iteration_no_in,'verdict',verdict_in,
      'criterion_results',criterion_results_in,'evidence_count',jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))));
  return iteration_out;
end;
$$;
