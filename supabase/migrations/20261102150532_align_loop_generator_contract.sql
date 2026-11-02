-- Align persisted task-loop contracts with the canonical Loop Generator skill 1.1.0.
create or replace function public.goal_ledger_validate_task_loop(task_definition_in jsonb,depth_in integer default 0)
returns boolean language plpgsql immutable set search_path to 'public' as $function$
declare loop_def jsonb:=task_definition_in->'loop'; child jsonb; criteria jsonb:=task_definition_in->'acceptance_criteria'; max_iterations integer;
begin
 if depth_in>32 then raise exception 'task tree exceeds maximum nesting depth'; end if;
 if jsonb_typeof(task_definition_in)<>'object' or nullif(btrim(task_definition_in->>'name'),'') is null then
  raise exception 'Every task must have a name';
 end if;
 if coalesce(jsonb_typeof(loop_def),'null')<>'object' or coalesce(loop_def->>'enabled','false')<>'true' then
  raise exception 'Task "%" requires an enabled Loop Generator contract',task_definition_in->>'name';
 end if;
 max_iterations:=coalesce((loop_def->>'max_iterations')::integer,0);
 if nullif(btrim(coalesce(loop_def->>'objective',loop_def->>'goal')),'') is null
  or not(loop_def?'input_contract') or not(loop_def?'output_contract')
  or nullif(btrim(loop_def->>'transformation'),'') is null
  or not(loop_def?'observation') or not(loop_def?'evaluation')
  or not(loop_def?'revision_policy')
  or coalesce(jsonb_typeof(loop_def->'stop_conditions'),'null')<>'array'
  or jsonb_array_length(coalesce(loop_def->'stop_conditions','[]'::jsonb))=0
  or max_iterations not between 1 and 100
  or coalesce(jsonb_typeof(loop_def->'initial_input'),'null') not in ('object','array','string','number','boolean')
  or coalesce(jsonb_typeof(loop_def->'tools'),'null')<>'array'
  or coalesce(jsonb_typeof(loop_def->'iteration_policy'),'null')<>'object' then
  raise exception 'Task "%" loop must define objective/goal, input/output contracts, transformation, observation, evaluation, revision_policy, stop_conditions, initial_input, tools, iteration_policy and max_iterations (1-100)',task_definition_in->>'name';
 end if;
 if coalesce(jsonb_typeof(criteria),'null')<>'array' or jsonb_array_length(coalesce(criteria,'[]'::jsonb))=0 then
  raise exception 'Task "%" requires non-empty acceptance_criteria (Loop Generator successCriteria)',task_definition_in->>'name';
 end if;
 if coalesce(jsonb_typeof(task_definition_in->'subtasks'),'array')<>'array' then
  raise exception 'Task "%" subtasks must be an array',task_definition_in->>'name';
 end if;
 for child in select value from jsonb_array_elements(coalesce(task_definition_in->'subtasks','[]'::jsonb)) loop
  perform public.goal_ledger_validate_task_loop(child,depth_in+1);
 end loop;
 return true;
end; $function$;
comment on function public.goal_ledger_validate_task_loop(jsonb,integer)
 is 'Validates each task against Loop Generator goal, input/output, transformation, observation, evaluation, revision, stop and bounded iteration contracts.';
