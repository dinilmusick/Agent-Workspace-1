create or replace function public.task_ledger_record_loop_iteration(
 task_id_in uuid,agent_id_in text,claim_token_in uuid,iteration_no_in integer,
 input_payload_in jsonb,output_payload_in jsonb,observation_in jsonb,criterion_results_in jsonb,loop_state_in jsonb,
 tools_used_in jsonb default '[]'::jsonb,evidence_in jsonb default '[]'::jsonb,
 verdict_in text default 'continue',next_action_in text default null
) returns public.task_iterations language plpgsql set search_path to 'public' as $function$
declare task_out public.tasks; iteration_out public.task_iterations; criterion_count integer; satisfied_count integer; max_allowed integer;
begin
 if verdict_in not in ('continue','pass','error','blocked','cancelled') then raise exception 'invalid loop verdict'; end if;
 if coalesce(jsonb_typeof(criterion_results_in),'null')<>'array' or jsonb_array_length(coalesce(criterion_results_in,'[]'::jsonb))=0 then raise exception 'criterion_results must be a non-empty array'; end if;
 select * into task_out from public.tasks where id=task_id_in and claimed_by_agent_id=agent_id_in and claim_token=claim_token_in and status='running' and claim_expires_at>now() for update;
 if not found then raise exception 'active, unexpired task claim required'; end if;
 max_allowed:=coalesce((task_out.loop_definition->>'max_iterations')::integer,8);
 if iteration_no_in<1 or iteration_no_in>max_allowed then raise exception 'iteration exceeds loop budget'; end if;
 if iteration_no_in<>(task_out.loop_iteration+1) then raise exception 'iteration number must be the next sequential iteration'; end if;
 select count(*),count(*) filter(where value->>'status'='satisfied') into criterion_count,satisfied_count from jsonb_array_elements(criterion_results_in);
 if exists(select 1 from jsonb_array_elements(criterion_results_in) c where c->>'status' not in ('satisfied','unsatisfied','unknown')) then raise exception 'invalid criterion status'; end if;
 if verdict_in='pass' and (criterion_count<>satisfied_count or jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))=0) then raise exception 'pass requires every criterion satisfied and evidence'; end if;
 insert into public.task_iterations(task_id,iteration_no,agent_id,status,input_payload,output_payload,observation,decision,tools_used,evidence,completed_at)
 values(task_id_in,iteration_no_in,agent_id_in,'completed',coalesce(input_payload_in,'{}'::jsonb),coalesce(output_payload_in,'{}'::jsonb),
  coalesce(observation_in,'{}'::jsonb)||jsonb_build_object('criterionResults',criterion_results_in,'loopState',coalesce(loop_state_in,'{}'::jsonb)),
  verdict_in||case when next_action_in is null then '' else ': '||next_action_in end,
  coalesce(tools_used_in,'[]'::jsonb),coalesce(evidence_in,'[]'::jsonb),now()) returning * into iteration_out;
 update public.tasks set loop_iteration=iteration_no_in,loop_state=coalesce(loop_state_in,'{}'::jsonb),heartbeat_at=now(),updated_at=now(),current_step=coalesce(next_action_in,'Loop iteration recorded') where id=task_id_in;
 insert into public.task_events(task_id,event_type,agent_id,message,payload) values(task_id_in,'loop_iteration_recorded',agent_id_in,coalesce(next_action_in,verdict_in),jsonb_build_object('iteration_no',iteration_no_in,'verdict',verdict_in,'criterion_results',criterion_results_in,'evidence_count',jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))));
 return iteration_out;
end; $function$;

create or replace function public.enforce_leaf_task_loop_pass()
returns trigger language plpgsql set search_path to 'public' as $function$
begin
 if new.status='completed' and old.status='running'
  and coalesce((new.loop_definition->>'enabled')::boolean,false)
  and not exists(select 1 from public.tasks child where child.parent_task_id=new.id)
  and not exists(
   select 1 from public.task_iterations i where i.task_id=new.id and i.agent_id=old.claimed_by_agent_id
    and i.decision like 'pass%' and jsonb_typeof(i.observation->'criterionResults')='array'
    and jsonb_array_length(i.observation->'criterionResults')>0
    and not exists(select 1 from jsonb_array_elements(i.observation->'criterionResults') c where c->>'status'<>'satisfied')
    and jsonb_array_length(i.evidence)>0
    and i.iteration_no=(select max(ix.iteration_no) from public.task_iterations ix where ix.task_id=new.id and ix.agent_id=old.claimed_by_agent_id)
  ) then raise exception 'Loop is not satisfied: latest iteration must pass every criterion with evidence'; end if;
 return new;
end; $function$;
drop trigger if exists tasks_require_loop_pass on public.tasks;
create trigger tasks_require_loop_pass before update of status on public.tasks for each row execute function public.enforce_leaf_task_loop_pass();

create or replace function public.goal_ledger_resume(name_in text)
returns jsonb language plpgsql stable set search_path to 'public' as $function$
declare goal_out public.goals; summary_out jsonb; tasks_out jsonb; events_out jsonb;
begin
 if nullif(btrim(name_in),'') is null then raise exception 'goal name is required'; end if;
 select * into goal_out from public.goals where lower(name)=lower(btrim(name_in));
 if not found then raise exception 'goal not found: %',name_in; end if;
 summary_out:=public.goal_ledger_summary(goal_out.id);
 select coalesce(jsonb_agg(to_jsonb(t)||jsonb_build_object('iterations',coalesce((select jsonb_agg(to_jsonb(i) order by i.iteration_no) from public.task_iterations i where i.task_id=t.id),'[]'::jsonb)) order by t.priority,t.started_at),'[]'::jsonb)
 into tasks_out from public.tasks t where t.goal_id=goal_out.id;
 select coalesce(jsonb_agg(to_jsonb(e) order by e.occurred_at),'[]'::jsonb) into events_out from public.goal_events e where e.goal_id=goal_out.id;
 return jsonb_build_object('goal',to_jsonb(goal_out),'summary',summary_out,'tasks',tasks_out,'events',events_out);
end; $function$;
