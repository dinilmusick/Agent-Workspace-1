-- A passing parent loop completes that parent so nested parents can proceed bottom-up.
create or replace function public.task_ledger_record_parent_loop_iteration(
 task_id_in uuid,agent_id_in text,iteration_no_in integer,input_payload_in jsonb,output_payload_in jsonb,
 observation_in jsonb,criterion_results_in jsonb,loop_state_in jsonb,
 tools_used_in jsonb default '[]'::jsonb,evidence_in jsonb default '[]'::jsonb,
 verdict_in text default 'continue',next_action_in text default null
) returns public.task_iterations
language plpgsql security invoker set search_path to 'public' as $function$
declare task_out public.tasks; iteration_out public.task_iterations;
 criterion_count integer; satisfied_count integer; max_allowed integer;
begin
 select * into task_out from public.tasks
 where id=task_id_in and agent_id=agent_id_in and status in ('queued','running','blocked')
  and exists(select 1 from public.tasks child where child.parent_task_id=tasks.id)
 for update;
 if not found then raise exception 'parent task must belong to the orchestrator and have children'; end if;
 if jsonb_typeof(criterion_results_in)<>'array' or jsonb_array_length(criterion_results_in)=0 then raise exception 'criterion_results must be a non-empty array'; end if;
 if verdict_in not in ('continue','pass','error','blocked','cancelled') then raise exception 'invalid loop verdict'; end if;
 max_allowed:=coalesce((task_out.loop_definition->>'max_iterations')::integer,8);
 if iteration_no_in<1 or iteration_no_in>max_allowed or iteration_no_in<>task_out.loop_iteration+1 then raise exception 'parent loop iteration must be sequential and within its budget'; end if;
 select count(*),count(*) filter(where value->>'status'='satisfied') into criterion_count,satisfied_count from jsonb_array_elements(criterion_results_in);
 if exists(select 1 from jsonb_array_elements(criterion_results_in) c where c->>'status' not in ('satisfied','unsatisfied','unknown')) then raise exception 'invalid criterion status'; end if;
 if verdict_in='pass' then
  if criterion_count<>satisfied_count or jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))=0 then raise exception 'parent loop pass requires every criterion satisfied with evidence'; end if;
  if exists(select 1 from public.tasks child where child.parent_task_id=task_id_in and not (child.status='completed' and child.verification_status='verified')) then
   raise exception 'parent loop cannot pass until every child is independently verified';
  end if;
 end if;
 insert into public.task_iterations(task_id,iteration_no,agent_id,status,input_payload,output_payload,observation,decision,tools_used,evidence,completed_at)
 values(task_id_in,iteration_no_in,agent_id_in,'completed',coalesce(input_payload_in,'{}'::jsonb),coalesce(output_payload_in,'{}'::jsonb),
  coalesce(observation_in,'{}'::jsonb)||jsonb_build_object('criterionResults',criterion_results_in,'loopState',coalesce(loop_state_in,'{}'::jsonb)),
  verdict_in||case when next_action_in is null then '' else ': '||next_action_in end,
  coalesce(tools_used_in,'[]'::jsonb),coalesce(evidence_in,'[]'::jsonb),now()) returning * into iteration_out;
 update public.tasks set loop_iteration=iteration_no_in,loop_state=coalesce(loop_state_in,'{}'::jsonb),
  heartbeat_at=now(),updated_at=now(),current_step=coalesce(next_action_in,'Parent loop iteration recorded')
 where id=task_id_in;
 if verdict_in='pass' then
  update public.tasks set status='completed',verification_status='verified',
   verification_report=jsonb_build_object('parent_loop_iteration',iteration_no_in,'criterion_results',criterion_results_in,'evidence',coalesce(evidence_in,'[]'::jsonb)),
   verified_by_agent_id=agent_id_in,verified_at=now(),completed_at=now(),
   outcome=coalesce(next_action_in,'Parent loop passed after all children were verified'),updated_at=now()
  where id=task_id_in;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'completed',agent_id_in,'Parent task loop passed; parent marked verified',
   jsonb_build_object('iteration_no',iteration_no_in,'evidence',coalesce(evidence_in,'[]'::jsonb)));
 end if;
 insert into public.task_events(task_id,event_type,agent_id,message,payload)
 values(task_id_in,'loop_iteration_recorded',agent_id_in,coalesce(next_action_in,verdict_in),
  jsonb_build_object('iteration_no',iteration_no_in,'verdict',verdict_in,'criterion_results',criterion_results_in,
   'evidence_count',jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))));
 return iteration_out;
end; $function$;
