-- Universal planning law + mandatory Vision/tldraw projection for canonical Omni goals.

create or replace function public.validate_task_action_contract()
returns trigger language plpgsql set search_path=public as $$
declare actions jsonb; pattern text;
begin
  actions := new.task_definition -> 'actions';
  pattern := nullif(btrim(new.task_definition ->> 'general_pattern'),'');
  if actions is null then raise exception 'task action contract is required: every new task must declare 1-4 actions'; end if;
  if jsonb_typeof(actions) <> 'array' then raise exception 'task actions must be a JSON array'; end if;
  if jsonb_array_length(actions) not between 1 and 4 then raise exception 'task actions must contain 1-4 actions; split larger work into additional tasks'; end if;
  if pattern is null then raise exception 'task general_pattern is required for every domain'; end if;
  return new;
end $$;

create or replace function public.validate_omni_task_definition(task_definition_in jsonb,inherited_target_in jsonb default null,depth_in integer default 0)
returns boolean language plpgsql immutable security invoker set search_path=public as $$
declare child jsonb; target_value jsonb; actions jsonb;
begin
  if depth_in>32 then raise exception 'task tree exceeds maximum nesting depth'; end if;
  if coalesce(jsonb_typeof(task_definition_in),'null')<>'object' or nullif(btrim(task_definition_in->>'name'),'') is null then raise exception 'every task must have a name'; end if;
  if coalesce(task_definition_in->>'type','general') not in ('implementation','investigation','research','design','learning','verification','documentation','maintenance','operations','review','general') then raise exception 'invalid task type: %',task_definition_in->>'type'; end if;
  actions:=task_definition_in->'actions';
  if coalesce(jsonb_typeof(actions),'null')<>'array' or jsonb_array_length(coalesce(actions,'[]'::jsonb)) not between 1 and 4 then raise exception 'every task must declare 1-4 actions'; end if;
  if nullif(btrim(task_definition_in->>'general_pattern'),'') is null then raise exception 'every task must declare a general_pattern'; end if;
  target_value:=coalesce(task_definition_in->'target',inherited_target_in);
  perform public.validate_omni_target(target_value);
  if inherited_target_in is not null and target_value<>inherited_target_in then raise exception 'task target must equal its parent target'; end if;
  perform public.validate_omni_loop(task_definition_in->'loop',target_value);
  if coalesce(jsonb_typeof(task_definition_in->'acceptance_criteria'),'null')<>'array' or jsonb_array_length(coalesce(task_definition_in->'acceptance_criteria','[]'::jsonb))=0 then raise exception 'task requires non-empty acceptance criteria'; end if;
  if coalesce(jsonb_typeof(task_definition_in->'subtasks'),'array')<>'array' then raise exception 'task subtasks must be an array'; end if;
  for child in select value from jsonb_array_elements(coalesce(task_definition_in->'subtasks','[]'::jsonb)) loop perform public.validate_omni_task_definition(child,target_value,depth_in+1); end loop;
  return true;
end $$;

create or replace function public.goal_ledger_create_omni_hierarchical(
 title_in text,description_in text,context_in jsonb,instructions_in text,acceptance_criteria_in jsonb,tags_in text[],
 goal_type_in text,target_in jsonb,behavior_inputs_in jsonb,expected_outputs_in jsonb,goal_loop_definition_in jsonb,
 task_definitions_in jsonb,created_by_agent_id_in text,owner_user_id_in uuid default auth.uid(),metadata_in jsonb default '{}'
)
returns jsonb language plpgsql set search_path=public as $$
declare goal_out public.goals; owner_id uuid; task_definition jsonb; task_id uuid; task_ids jsonb:='[]'::jsonb;
vision_id_value uuid; vision_target_id_value uuid; vt public.vision_targets; v public.visions;
begin
  perform public.validate_omni_goal_definition(goal_type_in,target_in,behavior_inputs_in,expected_outputs_in,goal_loop_definition_in,acceptance_criteria_in);
  if coalesce(jsonb_typeof(task_definitions_in),'null')<>'array' or jsonb_array_length(coalesce(task_definitions_in,'[]'::jsonb))=0 then raise exception 'vision goal requires at least one top-level task'; end if;
  for task_definition in select value from jsonb_array_elements(task_definitions_in) loop perform public.validate_omni_task_definition(task_definition,target_in,0); end loop;
  vision_id_value := nullif(metadata_in->>'vision_id','')::uuid;
  vision_target_id_value := nullif(metadata_in->>'vision_target_id','')::uuid;
  if vision_id_value is null or vision_target_id_value is null then raise exception 'mandatory Vision projection: metadata must include vision_id and vision_target_id'; end if;
  select * into v from public.visions where id=vision_id_value for update;
  if not found then raise exception 'mandatory Vision projection: vision not found'; end if;
  if v.tldraw_workspace_id is null or v.tldraw_board_id is null then raise exception 'mandatory Vision projection: tldraw board is not attached to Vision'; end if;
  select * into vt from public.vision_targets where id=vision_target_id_value and vision_id=vision_id_value for update;
  if not found then raise exception 'mandatory Vision projection: target not found in Vision'; end if;
  if vt.target<>target_in then raise exception 'goal target must equal its Vision target'; end if;
  owner_id:=coalesce(owner_user_id_in,auth.uid());
  if auth.uid() is not null and owner_id is distinct from auth.uid() then raise exception 'goal owner must be the authenticated user'; end if;
  goal_out:=public.goal_ledger_create(title_in,description_in,context_in,instructions_in,acceptance_criteria_in,created_by_agent_id_in,owner_id,metadata_in);
  insert into public.vision_target_goals(vision_target_id,goal_id) values(vision_target_id_value,goal_out.id) on conflict do nothing;
  update public.goals set goal_type=goal_type_in,target=target_in,behavior_inputs=behavior_inputs_in,expected_outputs=expected_outputs_in,
    tags=coalesce((select array_agg(distinct lower(btrim(tag))) from unnest(coalesce(tags_in,'{}'::text[])) tag where btrim(tag)<>''),'{}'::text[]),
    goal_loop_definition=jsonb_set(goal_loop_definition_in,'{target}',target_in,true),
    goal_loop_state=jsonb_build_object('current_input',goal_loop_definition_in->'initial_input','status','ready'),goal_loop_iteration=0,status='ready',updated_at=now()
  where id=goal_out.id returning * into goal_out;
  update public.goal_versions set snapshot=snapshot||jsonb_build_object('goal_key',goal_out.goal_key,'goal_type',goal_out.goal_type,'target',goal_out.target,'behavior_inputs',goal_out.behavior_inputs,'expected_outputs',goal_out.expected_outputs,'tags',to_jsonb(goal_out.tags),'goal_loop_definition',goal_out.goal_loop_definition,'vision_id',vision_id_value,'vision_target_id',vision_target_id_value)
  where goal_id=goal_out.id and version=1;
  for task_definition in select value from jsonb_array_elements(task_definitions_in) loop
    task_definition:=jsonb_set(task_definition,'{goal_id}',to_jsonb(goal_out.id::text),true);
    task_definition:=jsonb_set(task_definition,'{target}',target_in,true);
    task_id:=public.task_ledger_create_tree(created_by_agent_id_in,created_by_agent_id_in,task_definition,null,null,'orchestrator');
    task_ids:=task_ids||to_jsonb(task_id);
  end loop;
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
  values(goal_out.id,'planned',created_by_agent_id_in,'Canonical Omni Loop goal and target-locked task tree created with mandatory Vision/tldraw projection',
    jsonb_build_object('goal_key',goal_out.goal_key,'goal_type',goal_out.goal_type,'target',goal_out.target,'behavior_inputs',goal_out.behavior_inputs,'expected_outputs',goal_out.expected_outputs,'top_level_task_ids',task_ids,'loop_kind','omni','vision_id',vision_id_value,'vision_target_id',vision_target_id_value));
  return jsonb_build_object('goal',to_jsonb(goal_out),'goal_key',goal_out.goal_key,'top_level_task_ids',task_ids,'vision_id',vision_id_value,'vision_target_id',vision_target_id_value);
end $$;
