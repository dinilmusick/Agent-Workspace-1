-- Canonical Omni Loop ontology, typed goals/tasks, single-target behavior contracts and Vision projection metadata.

create or replace function public.validate_omni_target(target_in jsonb)
returns boolean language plpgsql immutable security invoker set search_path=public as $$
declare target_type text;
begin
  if coalesce(jsonb_typeof(target_in),'null') <> 'object' then raise exception 'target must be a JSON object'; end if;
  if nullif(btrim(target_in->>'type'),'') is null or nullif(btrim(target_in->>'id'),'') is null then
    raise exception 'target requires exactly one typed identity: type + id';
  end if;
  target_type:=target_in->>'type';
  if target_type not in ('repository','person','application','service','database','workspace','document','organization','system','device','general') then
    raise exception 'invalid target type: %',target_type;
  end if;
  return true;
end $$;

create or replace function public.validate_omni_loop(loop_in jsonb,target_in jsonb default null)
returns boolean language plpgsql immutable security invoker set search_path=public as $$
declare max_iterations integer;
begin
  if coalesce(jsonb_typeof(loop_in),'null')<>'object' then raise exception 'omni loop must be an object'; end if;
  if coalesce(loop_in->>'kind','')<>'omni' then raise exception 'loop kind must be omni'; end if;
  perform public.validate_omni_target(coalesce(loop_in->'target',target_in));
  if target_in is not null and loop_in->'target' is not null and loop_in->'target'<>target_in then raise exception 'loop target must equal its owning goal/task target'; end if;
  if nullif(btrim(loop_in->>'objective'),'') is null
    or coalesce(jsonb_typeof(loop_in->'edits'),'null')<>'array'
    or jsonb_array_length(coalesce(loop_in->'edits','[]'::jsonb))=0
    or coalesce(jsonb_typeof(loop_in->'input_contract'),'null')<>'object'
    or coalesce(jsonb_typeof(loop_in->'output_contract'),'null')<>'object'
    or nullif(btrim(loop_in->>'transformation'),'') is null
    or coalesce(jsonb_typeof(loop_in->'observation'),'null')<>'object'
    or coalesce(jsonb_typeof(loop_in->'evaluation'),'null')<>'object'
    or coalesce(jsonb_typeof(loop_in->'revision_policy'),'null')<>'object'
    or coalesce(jsonb_typeof(loop_in->'stop_conditions'),'null')<>'array'
    or jsonb_array_length(coalesce(loop_in->'stop_conditions','[]'::jsonb))=0
    or coalesce(jsonb_typeof(loop_in->'initial_input'),'null') not in ('object','array','string','number','boolean')
    or coalesce(jsonb_typeof(loop_in->'tools'),'null')<>'array'
    or coalesce(jsonb_typeof(loop_in->'iteration_policy'),'null')<>'object' then
    raise exception 'omni loop requires target, objective, non-empty edits, input/output contracts, transformation, observation, evaluation, revision_policy, stop_conditions, initial_input, tools and iteration_policy';
  end if;
  max_iterations:=coalesce((loop_in->>'max_iterations')::integer,0);
  if max_iterations not between 1 and 100 then raise exception 'omni loop max_iterations must be between 1 and 100'; end if;
  return true;
end $$;

alter table public.goals add column if not exists goal_type text,add column if not exists target jsonb,add column if not exists behavior_inputs jsonb,add column if not exists expected_outputs jsonb;
update public.goals set goal_type=coalesce(nullif(goal_type,''),'general'),target=coalesce(target,jsonb_build_object('type','system','id','legacy-goal:'||id::text)),behavior_inputs=coalesce(behavior_inputs,'[]'::jsonb),expected_outputs=coalesce(expected_outputs,'[]'::jsonb) where goal_type is null or target is null or behavior_inputs is null or expected_outputs is null;
alter table public.goals alter column goal_type set default 'general',alter column goal_type set not null,alter column target set default jsonb_build_object('type','system','id','unspecified'),alter column target set not null,alter column behavior_inputs set default '[]'::jsonb,alter column behavior_inputs set not null,alter column expected_outputs set default '[]'::jsonb,alter column expected_outputs set not null;
alter table public.goals drop constraint if exists goals_goal_type_check;
alter table public.goals add constraint goals_goal_type_check check(goal_type in ('coding','learning','research','design','creative','operations','business','personal_development','maintenance','system','general'));
alter table public.goals drop constraint if exists goals_target_shape_check;
alter table public.goals add constraint goals_target_shape_check check(jsonb_typeof(target)='object' and nullif(btrim(target->>'type'),'') is not null and nullif(btrim(target->>'id'),'') is not null);
alter table public.goals drop constraint if exists goals_behavior_inputs_array_check;
alter table public.goals add constraint goals_behavior_inputs_array_check check(jsonb_typeof(behavior_inputs)='array');
alter table public.goals drop constraint if exists goals_expected_outputs_array_check;
alter table public.goals add constraint goals_expected_outputs_array_check check(jsonb_typeof(expected_outputs)='array');
create index if not exists goals_goal_type_idx on public.goals(goal_type);
create index if not exists goals_target_type_idx on public.goals((target->>'type'),(target->>'id'));

alter table public.tasks add column if not exists task_type text,add column if not exists target jsonb;
update public.tasks t set task_type=coalesce(nullif(t.task_type,''),'general'),target=coalesce(t.target,(select g.target from public.goals g where g.id=t.goal_id),jsonb_build_object('type','system','id','legacy-task:'||t.task_key)) where t.task_type is null or t.target is null;
alter table public.tasks alter column task_type set default 'general',alter column task_type set not null,alter column target set default jsonb_build_object('type','system','id','unspecified'),alter column target set not null;
alter table public.tasks drop constraint if exists tasks_task_type_check;
alter table public.tasks add constraint tasks_task_type_check check(task_type in ('implementation','investigation','research','design','learning','verification','documentation','maintenance','operations','review','general'));
alter table public.tasks drop constraint if exists tasks_target_shape_check;
alter table public.tasks add constraint tasks_target_shape_check check(jsonb_typeof(target)='object' and nullif(btrim(target->>'type'),'') is not null and nullif(btrim(target->>'id'),'') is not null);
create index if not exists tasks_task_type_idx on public.tasks(task_type);
create index if not exists tasks_target_type_idx on public.tasks((target->>'type'),(target->>'id'));

create or replace function public.sync_and_validate_task_ontology()
returns trigger language plpgsql security invoker set search_path=public as $$
declare parent_target jsonb;goal_target jsonb;
begin
  new.task_type:=coalesce(nullif(btrim(new.task_type),''),'general');
  select g.target into goal_target from public.goals g where g.id=new.goal_id;
  select p.target into parent_target from public.tasks p where p.id=new.parent_task_id;
  if new.goal_id is not null then
    if goal_target is null then raise exception 'task goal target not found'; end if;
    if new.target is null or new.target='{}'::jsonb or new.target->>'id'='unspecified' then new.target:=goal_target;
    elsif new.target<>goal_target then raise exception 'task target must equal its parent goal target'; end if;
  elsif new.parent_task_id is not null then
    if parent_target is null then raise exception 'parent task target not found'; end if;
    if new.target is null or new.target='{}'::jsonb or new.target->>'id'='unspecified' then new.target:=parent_target;
    elsif new.target<>parent_target then raise exception 'child task target must equal parent task target'; end if;
  elsif new.target is null or new.target='{}'::jsonb or new.target->>'id'='unspecified' then
    new.target:=jsonb_build_object('type','system','id','standalone-task:'||new.task_key);
  end if;
  perform public.validate_omni_target(new.target);
  return new;
end $$;
drop trigger if exists tasks_sync_and_validate_ontology on public.tasks;
create trigger tasks_sync_and_validate_ontology before insert or update of goal_id,parent_task_id,target,task_type,task_definition on public.tasks for each row execute function public.sync_and_validate_task_ontology();

create or replace function public.validate_omni_goal_definition(goal_type_in text,target_in jsonb,behavior_inputs_in jsonb,expected_outputs_in jsonb,loop_in jsonb,acceptance_criteria_in jsonb)
returns boolean language plpgsql immutable security invoker set search_path=public as $$
begin
  if goal_type_in not in ('coding','learning','research','design','creative','operations','business','personal_development','maintenance','system','general') then raise exception 'invalid goal type: %',goal_type_in; end if;
  perform public.validate_omni_target(target_in);
  if coalesce(jsonb_typeof(behavior_inputs_in),'null')<>'array' or coalesce(jsonb_typeof(expected_outputs_in),'null')<>'array' or jsonb_array_length(coalesce(behavior_inputs_in,'[]'::jsonb))=0 or jsonb_array_length(coalesce(expected_outputs_in,'[]'::jsonb))=0 then raise exception 'goal requires non-empty behavior_inputs and expected_outputs arrays'; end if;
  if coalesce(jsonb_typeof(acceptance_criteria_in),'null')<>'array' or jsonb_array_length(coalesce(acceptance_criteria_in,'[]'::jsonb))=0 then raise exception 'goal requires non-empty acceptance criteria'; end if;
  perform public.validate_omni_loop(loop_in,target_in);
  return true;
end $$;

create or replace function public.validate_omni_task_definition(task_definition_in jsonb,inherited_target_in jsonb default null,depth_in integer default 0)
returns boolean language plpgsql immutable security invoker set search_path=public as $$
declare child jsonb;target_value jsonb;
begin
  if depth_in>32 then raise exception 'task tree exceeds maximum nesting depth'; end if;
  if coalesce(jsonb_typeof(task_definition_in),'null')<>'object' or nullif(btrim(task_definition_in->>'name'),'') is null then raise exception 'every task must have a name'; end if;
  if coalesce(task_definition_in->>'type','general') not in ('implementation','investigation','research','design','learning','verification','documentation','maintenance','operations','review','general') then raise exception 'invalid task type: %',task_definition_in->>'type'; end if;
  target_value:=coalesce(task_definition_in->'target',inherited_target_in);
  perform public.validate_omni_target(target_value);
  if inherited_target_in is not null and target_value<>inherited_target_in then raise exception 'task target must equal its parent target'; end if;
  perform public.validate_omni_loop(task_definition_in->'loop',target_value);
  if coalesce(jsonb_typeof(task_definition_in->'acceptance_criteria'),'null')<>'array' or jsonb_array_length(coalesce(task_definition_in->'acceptance_criteria','[]'::jsonb))=0 then raise exception 'task requires non-empty acceptance criteria'; end if;
  if coalesce(jsonb_typeof(task_definition_in->'subtasks'),'array')<>'array' then raise exception 'task subtasks must be an array'; end if;
  for child in select value from jsonb_array_elements(coalesce(task_definition_in->'subtasks','[]'::jsonb)) loop perform public.validate_omni_task_definition(child,target_value,depth_in+1); end loop;
  return true;
end $$;

create or replace function public.goal_ledger_create_omni_hierarchical(title_in text,description_in text,context_in jsonb,instructions_in text,acceptance_criteria_in jsonb,tags_in text[],goal_type_in text,target_in jsonb,behavior_inputs_in jsonb,expected_outputs_in jsonb,goal_loop_definition_in jsonb,task_definitions_in jsonb,created_by_agent_id_in text,owner_user_id_in uuid default auth.uid(),metadata_in jsonb default '{}')
returns jsonb language plpgsql security invoker set search_path=public as $$
declare goal_out public.goals;owner_id uuid;task_definition jsonb;task_id uuid;task_ids jsonb:='[]'::jsonb;
begin
  perform public.validate_omni_goal_definition(goal_type_in,target_in,behavior_inputs_in,expected_outputs_in,goal_loop_definition_in,acceptance_criteria_in);
  if coalesce(jsonb_typeof(task_definitions_in),'null')<>'array' or jsonb_array_length(coalesce(task_definitions_in,'[]'::jsonb))=0 then raise exception 'vision goal requires at least one top-level task'; end if;
  for task_definition in select value from jsonb_array_elements(task_definitions_in) loop perform public.validate_omni_task_definition(task_definition,target_in,0); end loop;
  owner_id:=coalesce(owner_user_id_in,auth.uid());
  if auth.uid() is not null and owner_id is distinct from auth.uid() then raise exception 'goal owner must be the authenticated user'; end if;
  goal_out:=public.goal_ledger_create(title_in,description_in,context_in,instructions_in,acceptance_criteria_in,created_by_agent_id_in,owner_id,metadata_in);
  update public.goals set goal_type=goal_type_in,target=target_in,behavior_inputs=behavior_inputs_in,expected_outputs=expected_outputs_in,tags=coalesce((select array_agg(distinct lower(btrim(tag))) from unnest(coalesce(tags_in,'{}'::text[])) tag where btrim(tag)<>''),'{}'::text[]),goal_loop_definition=jsonb_set(goal_loop_definition_in,'{target}',target_in,true),goal_loop_state=jsonb_build_object('current_input',goal_loop_definition_in->'initial_input','status','ready'),goal_loop_iteration=0,status='ready',updated_at=now() where id=goal_out.id returning * into goal_out;
  update public.goal_versions set snapshot=snapshot||jsonb_build_object('goal_key',goal_out.goal_key,'goal_type',goal_out.goal_type,'target',goal_out.target,'behavior_inputs',goal_out.behavior_inputs,'expected_outputs',goal_out.expected_outputs,'tags',to_jsonb(goal_out.tags),'goal_loop_definition',goal_out.goal_loop_definition) where goal_id=goal_out.id and version=1;
  for task_definition in select value from jsonb_array_elements(task_definitions_in) loop
    task_definition:=jsonb_set(task_definition,'{goal_id}',to_jsonb(goal_out.id::text),true);
    task_definition:=jsonb_set(task_definition,'{target}',target_in,true);
    task_id:=public.task_ledger_create_tree(created_by_agent_id_in,created_by_agent_id_in,task_definition,null,null,'orchestrator');
    task_ids:=task_ids||to_jsonb(task_id);
  end loop;
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload) values(goal_out.id,'planned',created_by_agent_id_in,'Canonical Omni Loop goal and target-locked task tree created',jsonb_build_object('goal_key',goal_out.goal_key,'goal_type',goal_out.goal_type,'target',goal_out.target,'behavior_inputs',goal_out.behavior_inputs,'expected_outputs',goal_out.expected_outputs,'top_level_task_ids',task_ids,'loop_kind','omni'));
  return jsonb_build_object('goal',to_jsonb(goal_out),'goal_key',goal_out.goal_key,'top_level_task_ids',task_ids);
end $$;

create table if not exists public.visions(
  id uuid primary key default gen_random_uuid(),vision_key text not null unique,title text not null,description text not null default '',target jsonb not null,decomposition_graph jsonb not null default '{"nodes":[],"edges":[]}'::jsonb,status text not null default 'planning' check(status in ('planning','active','completed','blocked','cancelled','archived')),tldraw_workspace_id text,tldraw_board_id text,tldraw_board_url text,created_by_agent_id text not null,owner_user_id uuid references auth.users(id) on delete set null,metadata jsonb not null default '{}',created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create index if not exists visions_target_idx on public.visions((target->>'type'),(target->>'id'));
create index if not exists visions_status_updated_idx on public.visions(status,updated_at desc);

create table if not exists public.vision_targets(
  id uuid primary key default gen_random_uuid(),vision_id uuid not null references public.visions(id) on delete cascade,parent_target_id uuid references public.vision_targets(id) on delete cascade,target jsonb not null,label text not null,position jsonb not null default '{"x":0,"y":0}'::jsonb,metadata jsonb not null default '{}',created_at timestamptz not null default now(),unique(vision_id,id)
);
create index if not exists vision_targets_vision_parent_idx on public.vision_targets(vision_id,parent_target_id);

create table if not exists public.vision_target_goals(
  vision_target_id uuid not null references public.vision_targets(id) on delete cascade,goal_id uuid not null references public.goals(id) on delete cascade,created_at timestamptz not null default now(),primary key(vision_target_id,goal_id)
);
create index if not exists vision_target_goals_goal_idx on public.vision_target_goals(goal_id);

create table if not exists public.vision_canvas_pages(
  id uuid primary key default gen_random_uuid(),vision_id uuid not null references public.visions(id) on delete cascade,page_role text not null check(page_role in ('overview','target')),vision_target_id uuid references public.vision_targets(id) on delete cascade,tldraw_page_id text not null,page_title text not null,metadata jsonb not null default '{}',created_at timestamptz not null default now(),unique(vision_id,tldraw_page_id),unique(vision_id,page_role,vision_target_id)
);
create index if not exists vision_canvas_pages_vision_idx on public.vision_canvas_pages(vision_id,page_role);

alter table public.visions enable row level security;
alter table public.vision_targets enable row level security;
alter table public.vision_target_goals enable row level security;
alter table public.vision_canvas_pages enable row level security;
revoke all on public.visions,public.vision_targets,public.vision_target_goals,public.vision_canvas_pages from anon,authenticated;
grant select,insert,update,delete on public.visions,public.vision_targets,public.vision_canvas_pages,public.vision_target_goals to service_role;

create or replace function public.vision_ledger_create(title_in text,description_in text,target_in jsonb,created_by_agent_id_in text,owner_user_id_in uuid default null,metadata_in jsonb default '{}')
returns public.visions language plpgsql security invoker set search_path=public as $$
declare out_vision public.visions;base_key text;candidate_key text;suffix integer:=2;
begin
  if nullif(btrim(title_in),'') is null then raise exception 'vision title is required'; end if;
  if nullif(btrim(created_by_agent_id_in),'') is null then raise exception 'vision creator is required'; end if;
  perform public.validate_omni_target(target_in);
  base_key:=trim(both '-' from regexp_replace(lower(title_in),'[^a-z0-9]+','-','g'));if base_key='' then base_key:='vision';end if;
  perform pg_advisory_xact_lock(hashtextextended('vision-key:'||base_key,0));candidate_key:=base_key;
  while exists(select 1 from public.visions where vision_key=candidate_key) loop candidate_key:=base_key||'-'||suffix::text;suffix:=suffix+1;end loop;
  insert into public.visions(vision_key,title,description,target,created_by_agent_id,owner_user_id,metadata) values(candidate_key,btrim(title_in),coalesce(description_in,''),target_in,btrim(created_by_agent_id_in),owner_user_id_in,coalesce(metadata_in,'{}')) returning * into out_vision;
  return out_vision;
end $$;

create or replace function public.vision_ledger_attach_tldraw(vision_id_in uuid,workspace_id_in text,board_id_in text,board_url_in text,overview_page_id_in text)
returns public.visions language plpgsql security invoker set search_path=public as $$
declare out_vision public.visions;
begin
  if nullif(btrim(workspace_id_in),'') is null or nullif(btrim(board_id_in),'') is null or nullif(btrim(overview_page_id_in),'') is null then raise exception 'tldraw workspace, board and overview page are required'; end if;
  update public.visions set tldraw_workspace_id=workspace_id_in,tldraw_board_id=board_id_in,tldraw_board_url=board_url_in,updated_at=now() where id=vision_id_in returning * into out_vision;
  if not found then raise exception 'vision not found'; end if;
  insert into public.vision_canvas_pages(vision_id,page_role,tldraw_page_id,page_title) values(vision_id_in,'overview',overview_page_id_in,'Vision Overview') on conflict(vision_id,tldraw_page_id) do update set page_title=excluded.page_title;
  return out_vision;
end $$;

create or replace function public.vision_ledger_add_target(vision_id_in uuid,parent_target_id_in uuid,label_in text,target_in jsonb,position_in jsonb default '{"x":0,"y":0}',metadata_in jsonb default '{}')
returns public.vision_targets language plpgsql security invoker set search_path=public as $$
declare out_target public.vision_targets;
begin
  perform public.validate_omni_target(target_in);
  if nullif(btrim(label_in),'') is null then raise exception 'vision target label is required'; end if;
  if parent_target_id_in is not null and not exists(select 1 from public.vision_targets where id=parent_target_id_in and vision_id=vision_id_in) then raise exception 'parent vision target not found in this vision'; end if;
  insert into public.vision_targets(vision_id,parent_target_id,target,label,position,metadata) values(vision_id_in,parent_target_id_in,target_in,btrim(label_in),coalesce(position_in,'{"x":0,"y":0}'),coalesce(metadata_in,'{}')) returning * into out_target;
  update public.visions set updated_at=now() where id=vision_id_in;
  return out_target;
end $$;

create or replace function public.vision_ledger_link_goal(vision_target_id_in uuid,goal_id_in uuid)
returns public.vision_target_goals language plpgsql security invoker set search_path=public as $$
declare out_link public.vision_target_goals;vt public.vision_targets;g public.goals;
begin
  select * into vt from public.vision_targets where id=vision_target_id_in for update;if not found then raise exception 'vision target not found';end if;
  select * into g from public.goals where id=goal_id_in for update;if not found then raise exception 'goal not found';end if;
  if g.target<>vt.target then raise exception 'goal target must equal its vision component target';end if;
  insert into public.vision_target_goals(vision_target_id,goal_id) values(vision_target_id_in,goal_id_in) on conflict do nothing returning * into out_link;
  return out_link;
end $$;

comment on column public.goals.goal_type is 'Closed vocabulary classification for the goal.';
comment on column public.goals.target is 'Exactly one behavior target. Shape: {type,id,...}.';
comment on column public.goals.behavior_inputs is 'Inputs supplied to the target whose behavior should change.';
comment on column public.goals.expected_outputs is 'Expected observable outputs from the target for the declared behavior inputs.';
comment on column public.tasks.task_type is 'Closed vocabulary classification for the task.';
comment on column public.tasks.target is 'Exactly one target inherited from the goal/parent task; child tasks cannot retarget.';
comment on table public.visions is 'Persistent decomposition of one target into component targets, each linked to goals.';
comment on table public.vision_canvas_pages is 'tldraw page identities for the Vision Overview and component-target pages.';

revoke all on function public.validate_omni_target(jsonb) from public,anon,authenticated;
revoke all on function public.validate_omni_loop(jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.validate_omni_goal_definition(text,jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.validate_omni_task_definition(jsonb,jsonb,integer) from public,anon,authenticated;
revoke all on function public.goal_ledger_create_omni_hierarchical(text,text,jsonb,text,jsonb,text[],text,jsonb,jsonb,jsonb,jsonb,jsonb,text,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.vision_ledger_create(text,text,jsonb,text,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.vision_ledger_attach_tldraw(uuid,text,text,text,text) from public,anon,authenticated;
revoke all on function public.vision_ledger_add_target(uuid,uuid,text,jsonb,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.vision_ledger_link_goal(uuid,uuid) from public,anon,authenticated;
grant execute on function public.goal_ledger_create_omni_hierarchical(text,text,jsonb,text,jsonb,text[],text,jsonb,jsonb,jsonb,jsonb,jsonb,text,uuid,jsonb) to service_role;
grant execute on function public.vision_ledger_create(text,text,jsonb,text,uuid,jsonb) to service_role;
grant execute on function public.vision_ledger_attach_tldraw(uuid,text,text,text,text) to service_role;
grant execute on function public.vision_ledger_add_target(uuid,uuid,text,jsonb,jsonb,jsonb) to service_role;
grant execute on function public.vision_ledger_link_goal(uuid,uuid) to service_role;
