-- Parent tasks also execute persistent loops; only the orchestrator/goal creator can record them.
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
 if jsonb_typeof(criterion_results_in)<>'array' or jsonb_array_length(criterion_results_in)=0 then
  raise exception 'criterion_results must be a non-empty array';
 end if;
 if verdict_in not in ('continue','pass','error','blocked','cancelled') then raise exception 'invalid loop verdict'; end if;
 max_allowed:=coalesce((task_out.loop_definition->>'max_iterations')::integer,8);
 if iteration_no_in<1 or iteration_no_in>max_allowed or iteration_no_in<>task_out.loop_iteration+1 then
  raise exception 'parent loop iteration must be sequential and within its budget';
 end if;
 select count(*),count(*) filter(where value->>'status'='satisfied')
 into criterion_count,satisfied_count from jsonb_array_elements(criterion_results_in);
 if exists(select 1 from jsonb_array_elements(criterion_results_in) c
  where c->>'status' not in ('satisfied','unsatisfied','unknown')) then raise exception 'invalid criterion status'; end if;
 if verdict_in='pass' then
  if criterion_count<>satisfied_count or jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))=0 then
   raise exception 'parent loop pass requires every criterion satisfied with evidence';
  end if;
  if exists(select 1 from public.tasks child where child.parent_task_id=task_id_in
   and not (child.status='completed' and child.verification_status='verified')) then
   raise exception 'parent loop cannot pass until every child is independently verified';
  end if;
 end if;
 insert into public.task_iterations(task_id,iteration_no,agent_id,status,input_payload,output_payload,
  observation,decision,tools_used,evidence,completed_at)
 values(task_id_in,iteration_no_in,agent_id_in,'completed',coalesce(input_payload_in,'{}'::jsonb),
  coalesce(output_payload_in,'{}'::jsonb),
  coalesce(observation_in,'{}'::jsonb)||jsonb_build_object('criterionResults',criterion_results_in,'loopState',coalesce(loop_state_in,'{}'::jsonb)),
  verdict_in||case when next_action_in is null then '' else ': '||next_action_in end,
  coalesce(tools_used_in,'[]'::jsonb),coalesce(evidence_in,'[]'::jsonb),now())
 returning * into iteration_out;
 update public.tasks set loop_iteration=iteration_no_in,loop_state=coalesce(loop_state_in,'{}'::jsonb),
  heartbeat_at=now(),updated_at=now(),current_step=coalesce(next_action_in,'Parent loop iteration recorded')
 where id=task_id_in;
 insert into public.task_events(task_id,event_type,agent_id,message,payload)
 values(task_id_in,'loop_iteration_recorded',agent_id_in,coalesce(next_action_in,verdict_in),
  jsonb_build_object('iteration_no',iteration_no_in,'verdict',verdict_in,
   'criterion_results',criterion_results_in,'evidence_count',jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))));
 return iteration_out;
end; $function$;

create or replace function public.goal_ledger_finalize(
 goal_name_in text,finalized_by_agent_id_in text,verification_report_in jsonb default '{}'::jsonb
) returns public.goals language plpgsql security invoker set search_path to 'public' as $function$
declare goal_out public.goals; changed integer;
begin
 select * into goal_out from public.goals
 where lower(name)=lower(btrim(goal_name_in))
  and (auth.uid() is null or owner_user_id=auth.uid())
 for update;
 if not found then raise exception 'goal not found or access denied'; end if;
 if goal_out.created_by_agent_id<>finalized_by_agent_id_in and not exists(
  select 1 from public.agent_registry a where a.agent_id=finalized_by_agent_id_in and a.enabled
   and a.agent_type in ('orchestrator','verifier','supervisor')
 ) then raise exception 'goal finalization requires its orchestrator or an enabled verifier'; end if;

 if exists(
  select 1 from public.tasks p where p.goal_id=goal_out.id
   and exists(select 1 from public.tasks c where c.parent_task_id=p.id)
   and not exists(
    select 1 from public.task_iterations i where i.task_id=p.id and i.agent_id=finalized_by_agent_id_in
     and i.decision like 'pass%'
     and jsonb_typeof(i.observation->'criterionResults')='array'
     and jsonb_array_length(i.observation->'criterionResults')>0
     and not exists(select 1 from jsonb_array_elements(i.observation->'criterionResults') c where c->>'status'<>'satisfied')
     and jsonb_array_length(i.evidence)>0
     and i.iteration_no=(select max(ix.iteration_no) from public.task_iterations ix where ix.task_id=p.id and ix.agent_id=finalized_by_agent_id_in)
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
 values(goal_out.id,'completed',finalized_by_agent_id_in,'All leaf and parent task loops passed; all work verified',
  jsonb_build_object('verification_report',coalesce(verification_report_in,'{}'::jsonb)));
 return goal_out;
end; $function$;

revoke all on function public.task_ledger_record_parent_loop_iteration(uuid,text,integer,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,text,text) from public,anon;
grant execute on function public.task_ledger_record_parent_loop_iteration(uuid,text,integer,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,text,text) to authenticated,service_role;
