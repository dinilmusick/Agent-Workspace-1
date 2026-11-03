-- Four-action task decomposition contract.
-- New hierarchical tasks must declare 1-4 actions. Existing historical tasks are preserved.

create or replace function public.validate_task_action_contract()
returns trigger
language plpgsql
set search_path = public
as $$
declare actions jsonb;
begin
  actions := new.task_definition -> 'actions';
  if actions is null then
    raise exception 'task action contract is required: every new task must declare 1-4 actions';
  end if;
  if jsonb_typeof(actions) <> 'array' then
    raise exception 'task actions must be a JSON array';
  end if;
  if jsonb_array_length(actions) < 1 then
    raise exception 'task actions must contain at least one action';
  end if;
  if jsonb_array_length(actions) > 4 then
    raise exception 'task contains % actions; the maximum is 4. Split the work into another task', jsonb_array_length(actions);
  end if;
  return new;
end;
$$;

drop trigger if exists tasks_validate_action_contract on public.tasks;
create trigger tasks_validate_action_contract
before insert on public.tasks
for each row
when (new.task_definition is not null and new.task_definition <> '{}'::jsonb)
execute function public.validate_task_action_contract();

create or replace function public.task_ledger_create_tree(
  agent_id_in text, agent_name_in text, task_definition_in jsonb,
  parent_task_id_in uuid default null, session_id_in text default null, agent_type_in text default null
)
returns uuid
language plpgsql
set search_path = public
as $function$
declare task_id_out uuid; child_definition jsonb; priority_value smallint; goal_id_value uuid; actions jsonb;
begin
  if nullif(btrim(agent_id_in),'') is null or nullif(btrim(agent_name_in),'') is null then raise exception 'agent_id and agent_name are required'; end if;
  if jsonb_typeof(task_definition_in)<>'object' or nullif(btrim(task_definition_in->>'name'),'') is null then raise exception 'task_definition must be an object with a non-empty name'; end if;
  actions := task_definition_in->'actions';
  if actions is null or jsonb_typeof(actions)<>'array' then raise exception 'task_definition.actions is required and must be a JSON array'; end if;
  if jsonb_array_length(actions) < 1 or jsonb_array_length(actions) > 4 then raise exception 'each task must contain 1-4 actions; split tasks requiring more than 4 actions'; end if;
  priority_value:=coalesce((task_definition_in->>'priority')::smallint,3);
  if priority_value<1 or priority_value>5 then raise exception 'priority must be between 1 and 5'; end if;
  if parent_task_id_in is not null and not exists(select 1 from public.tasks where id=parent_task_id_in) then raise exception 'parent task not found'; end if;
  goal_id_value:=coalesce(nullif(task_definition_in->>'goal_id','')::uuid,(select goal_id from public.tasks where id=parent_task_id_in));
  if goal_id_value is not null and not exists(select 1 from public.goals where id=goal_id_value) then raise exception 'goal not found'; end if;
  if parent_task_id_in is not null and goal_id_value is distinct from (select goal_id from public.tasks where id=parent_task_id_in) then raise exception 'child task goal must match parent goal'; end if;
  if jsonb_typeof(coalesce(task_definition_in->'subtasks','[]'::jsonb))<>'array' then raise exception 'subtasks must be a JSON array'; end if;
  insert into public.tasks(goal_id,agent_id,agent_name,agent_type,session_id,task_name,description,status,tags,priority,parent_task_id,context_summary,metadata,due_at,task_definition,input_contract,output_contract,acceptance_criteria,verification_plan,loop_definition,required_tools,required_capabilities,max_attempts)
  values(goal_id_value,agent_id_in,agent_name_in,agent_type_in,session_id_in,task_definition_in->>'name',task_definition_in->>'description','queued',array(select jsonb_array_elements_text(coalesce(task_definition_in->'tags','[]'::jsonb))),priority_value,parent_task_id_in,task_definition_in->>'context_summary',coalesce(task_definition_in->'metadata','{}'::jsonb),nullif(task_definition_in->>'due_at','')::timestamptz,task_definition_in,coalesce(task_definition_in->'inputs','{}'::jsonb),coalesce(task_definition_in->'outputs','{}'::jsonb),coalesce(task_definition_in->'acceptance_criteria','[]'::jsonb),coalesce(task_definition_in->'verification','{}'::jsonb),coalesce(task_definition_in->'loop','{}'::jsonb),coalesce(task_definition_in->'required_tools','[]'::jsonb),array(select jsonb_array_elements_text(coalesce(task_definition_in->'required_capabilities','[]'::jsonb))),greatest(1,coalesce((task_definition_in->>'max_attempts')::integer,3))
  ) returning id into task_id_out;
  insert into public.task_events(task_id,event_type,agent_id,message,payload) values(task_id_out,'registered',agent_id_in,task_definition_in->>'name',jsonb_build_object('parent_task_id',parent_task_id_in,'goal_id',goal_id_value,'definition',task_definition_in));
  for child_definition in select value from jsonb_array_elements(coalesce(task_definition_in->'subtasks','[]'::jsonb)) loop
    perform public.task_ledger_create_tree(agent_id_in,agent_name_in,child_definition,task_id_out,session_id_in,agent_type_in);
  end loop;
  if jsonb_array_length(coalesce(task_definition_in->'subtasks','[]'::jsonb))>0 then
    insert into public.task_events(task_id,event_type,agent_id,message,payload) values(task_id_out,'tree_created',agent_id_in,'Nested task tree created',jsonb_build_object('direct_subtask_count',jsonb_array_length(task_definition_in->'subtasks')));
  end if;
  return task_id_out;
end;
$function$;

drop function if exists public.goal_ledger_validate_task_loop(jsonb, integer);
create function public.goal_ledger_validate_task_loop(task_definition_in jsonb, depth_in integer default 0)
returns void
language plpgsql
set search_path = public
as $function$
declare child_definition jsonb; actions jsonb;
begin
  if jsonb_typeof(task_definition_in)<>'object' or nullif(btrim(task_definition_in->>'name'),'') is null then raise exception 'task definition must have a non-empty name'; end if;
  actions := task_definition_in->'actions';
  if actions is null or jsonb_typeof(actions)<>'array' then raise exception 'task % must declare an actions array', task_definition_in->>'name'; end if;
  if jsonb_array_length(actions) < 1 or jsonb_array_length(actions) > 4 then raise exception 'task % must contain 1-4 actions; split work requiring more than 4 actions', task_definition_in->>'name'; end if;
  if jsonb_typeof(coalesce(task_definition_in->'subtasks','[]'::jsonb))<>'array' then raise exception 'subtasks must be a JSON array'; end if;
  for child_definition in select value from jsonb_array_elements(coalesce(task_definition_in->'subtasks','[]'::jsonb)) loop
    perform public.goal_ledger_validate_task_loop(child_definition, depth_in + 1);
  end loop;
end;
$function$;
