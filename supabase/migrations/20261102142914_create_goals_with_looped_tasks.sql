create or replace function public.goal_ledger_validate_task_loop(task_definition_in jsonb, depth_in integer default 0)
returns boolean language plpgsql immutable set search_path to 'public' as $function$
declare loop_def jsonb := task_definition_in->'loop'; child jsonb; criteria jsonb := task_definition_in->'acceptance_criteria'; max_iterations integer;
begin
 if depth_in>32 then raise exception 'task tree exceeds maximum nesting depth'; end if;
 if jsonb_typeof(task_definition_in)<>'object' or nullif(btrim(task_definition_in->>'name'),'') is null then raise exception 'Every task must have a name'; end if;
 if coalesce(jsonb_typeof(loop_def),'null')<>'object' or coalesce(loop_def->>'enabled','false')<>'true' then raise exception 'Task "%" requires an enabled Loop Generator contract',task_definition_in->>'name'; end if;
 max_iterations:=coalesce((loop_def->>'max_iterations')::integer,0);
 if nullif(btrim(loop_def->>'objective'),'') is null or not(loop_def?'input_contract') or not(loop_def?'output_contract')
  or coalesce(jsonb_typeof(loop_def->'cycle'),'null')<>'array' or jsonb_array_length(coalesce(loop_def->'cycle','[]'::jsonb))=0
  or not(loop_def?'evaluation') or coalesce(jsonb_typeof(loop_def->'stop_conditions'),'null')<>'array'
  or jsonb_array_length(coalesce(loop_def->'stop_conditions','[]'::jsonb))=0 or max_iterations not between 1 and 100 then
  raise exception 'Task "%" has an incomplete loop contract',task_definition_in->>'name';
 end if;
 if coalesce(jsonb_typeof(criteria),'null')<>'array' or jsonb_array_length(coalesce(criteria,'[]'::jsonb))=0 then raise exception 'Task "%" requires observable acceptance criteria',task_definition_in->>'name'; end if;
 if coalesce(jsonb_typeof(task_definition_in->'subtasks'),'array')<>'array' then raise exception 'Task "%" subtasks must be an array',task_definition_in->>'name'; end if;
 for child in select value from jsonb_array_elements(coalesce(task_definition_in->'subtasks','[]'::jsonb)) loop perform public.goal_ledger_validate_task_loop(child,depth_in+1); end loop;
 return true;
end; $function$;

create or replace function public.goal_ledger_create_with_tasks(
 name_in text,description_in text,context_in jsonb,instructions_in text,acceptance_criteria_in jsonb,
 created_by_agent_id_in text,task_definition_in jsonb,owner_user_id_in uuid default null,metadata_in jsonb default '{}'::jsonb
) returns jsonb language plpgsql set search_path to 'public' as $function$
declare goal_out public.goals; root_task_id uuid; definition jsonb;
begin
 perform public.goal_ledger_validate_task_loop(task_definition_in,0);
 goal_out:=public.goal_ledger_create(name_in,description_in,context_in,instructions_in,acceptance_criteria_in,created_by_agent_id_in,owner_user_id_in,metadata_in);
 definition:=jsonb_set(task_definition_in,'{goal_id}',to_jsonb(goal_out.id::text),true);
 root_task_id:=public.task_ledger_create_tree(created_by_agent_id_in,created_by_agent_id_in,definition,null,null,'orchestrator');
 update public.goals set status='ready',updated_at=now() where id=goal_out.id returning * into goal_out;
 insert into public.goal_events(goal_id,event_type,agent_id,message,payload) values(goal_out.id,'planned',created_by_agent_id_in,'Goal and loop-backed task tree created',jsonb_build_object('root_task_id',root_task_id,'loop_contracts_required',true));
 return jsonb_build_object('goal',to_jsonb(goal_out),'root_task_id',root_task_id);
end; $function$;