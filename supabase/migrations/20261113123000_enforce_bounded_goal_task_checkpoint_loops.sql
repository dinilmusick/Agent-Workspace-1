-- Bounded Vision -> Goal -> Task -> Checkpoint execution model.
-- Vision has unbounded goals; each Goal has at most 4 direct Tasks;
-- each Task has at most 4 completion parameters and exactly one checkpoint per parameter.

alter table public.goals
  add column if not exists completion_parameters jsonb not null default '[]'::jsonb;
alter table public.tasks
  add column if not exists execution_model text not null default 'legacy',
  add column if not exists completion_parameters jsonb not null default '[]'::jsonb,
  add column if not exists checkpoints jsonb not null default '[]'::jsonb,
  add column if not exists current_checkpoint_index smallint not null default 0;

alter table public.goals drop constraint if exists goals_completion_parameters_shape;
alter table public.goals add constraint goals_completion_parameters_shape
  check (jsonb_typeof(completion_parameters)='array' and jsonb_array_length(completion_parameters)<=4);

alter table public.tasks drop constraint if exists tasks_completion_parameters_shape;
alter table public.tasks add constraint tasks_completion_parameters_shape
  check (jsonb_typeof(completion_parameters)='array' and jsonb_array_length(completion_parameters)<=4);

alter table public.tasks drop constraint if exists tasks_checkpoints_shape;
alter table public.tasks add constraint tasks_checkpoints_shape
  check (jsonb_typeof(checkpoints)='array' and jsonb_array_length(checkpoints)<=4
         and current_checkpoint_index between 0 and 4);

create or replace function public.validate_bounded_task_model()
returns trigger language plpgsql set search_path=public as $$
declare p_ids text[]; cp_ids text[];
begin
  if new.execution_model <> 'bounded-v2' then return new; end if;
  if jsonb_typeof(new.completion_parameters)<>'array'
     or jsonb_array_length(new.completion_parameters) not between 1 and 4
    then raise exception 'bounded-v2 task requires 1-4 completion parameters'; end if;
  if jsonb_typeof(new.checkpoints)<>'array'
     or jsonb_array_length(new.checkpoints)<>jsonb_array_length(new.completion_parameters)
    then raise exception 'bounded-v2 task requires exactly one checkpoint per completion parameter'; end if;
  if exists(select 1 from jsonb_array_elements(new.completion_parameters) p
            where jsonb_typeof(p)<>'object'
               or nullif(btrim(p->>'id'),'') is null
               or nullif(btrim(p->>'description'),'') is null)
    then raise exception 'each completion parameter requires id and description'; end if;
  p_ids:=array(select p->>'id' from jsonb_array_elements(new.completion_parameters) p);
  if cardinality(p_ids)<>cardinality(array(select distinct unnest(p_ids)))
    then raise exception 'completion parameter ids must be unique'; end if;
  if exists(select 1 from jsonb_array_elements(new.checkpoints) c
            where jsonb_typeof(c)<>'object'
               or nullif(btrim(c->>'parameter_id'),'') is null
               or nullif(btrim(c->>'objective'),'') is null
               or coalesce(c->>'status','') not in ('pending','running','succeeded','failed','blocked'))
    then raise exception 'each checkpoint requires parameter_id, objective and valid status'; end if;
  cp_ids:=array(select c->>'parameter_id' from jsonb_array_elements(new.checkpoints) c);
  if cardinality(cp_ids)<>cardinality(array(select distinct unnest(cp_ids)))
    then raise exception 'checkpoint parameter_id values must be unique'; end if;
  if exists(select 1 from unnest(cp_ids) id where not (id=any(p_ids)))
    then raise exception 'every checkpoint must correspond to a completion parameter'; end if;
  return new;
end; $$;

drop trigger if exists tasks_validate_bounded_model on public.tasks;
create trigger tasks_validate_bounded_model
before insert or update of execution_model,completion_parameters,checkpoints,current_checkpoint_index
on public.tasks for each row execute function public.validate_bounded_task_model();

create or replace function public.enforce_goal_direct_task_cap()
returns trigger language plpgsql set search_path=public as $$
declare direct_count integer;
begin
  if new.goal_id is not null and new.parent_task_id is null then
    perform pg_advisory_xact_lock(hashtextextended('goal-task-cap:'||new.goal_id::text,0));
    select count(*) into direct_count from public.tasks
    where goal_id=new.goal_id and parent_task_id is null
      and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid);
    if direct_count>=4 then
      raise exception 'goal may contain at most 4 direct tasks; create a new goal for additional work';
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists tasks_enforce_goal_direct_task_cap on public.tasks;
create trigger tasks_enforce_goal_direct_task_cap
before insert or update of goal_id,parent_task_id on public.tasks
for each row execute function public.enforce_goal_direct_task_cap();

create or replace function public.sync_goal_completion_parameters()
returns trigger language plpgsql set search_path=public as $$
declare gid uuid;
begin
  gid:=coalesce(new.goal_id,old.goal_id);
  if gid is not null then
    update public.goals g set completion_parameters=coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',t.task_key,'task_id',t.id,
        'description',coalesce(t.description,t.task_name),'required',true)
        order by t.created_at,t.id)
      from public.tasks t where t.goal_id=gid and t.parent_task_id is null
    ),'[]'::jsonb),updated_at=now() where g.id=gid;
  end if;
  if tg_op='UPDATE' and old.goal_id is distinct from new.goal_id and old.goal_id is not null then
    update public.goals g set completion_parameters=coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',t.task_key,'task_id',t.id,
        'description',coalesce(t.description,t.task_name),'required',true)
        order by t.created_at,t.id)
      from public.tasks t where t.goal_id=old.goal_id and t.parent_task_id is null
    ),'[]'::jsonb),updated_at=now() where g.id=old.goal_id;
  end if;
  return coalesce(new,old);
end; $$;

drop trigger if exists tasks_sync_goal_completion_parameters on public.tasks;
create trigger tasks_sync_goal_completion_parameters
after insert or update of goal_id,parent_task_id or delete on public.tasks
for each row execute function public.sync_goal_completion_parameters();

create or replace function public.enforce_bounded_task_completion()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.execution_model='bounded-v2' and new.status='completed'
     and old.status is distinct from 'completed'
     and (jsonb_array_length(new.checkpoints)=0 or exists(
       select 1 from jsonb_array_elements(new.checkpoints) c
       where c->>'status'<>'succeeded')) then
    raise exception 'bounded-v2 task cannot complete until every checkpoint succeeds';
  end if;
  return new;
end; $$;

drop trigger if exists tasks_require_all_bounded_checkpoints on public.tasks;
create trigger tasks_require_all_bounded_checkpoints
before update of status,checkpoints on public.tasks
for each row execute function public.enforce_bounded_task_completion();

-- New task creation is bounded-v2. Legacy rows remain readable/recoverable.
create or replace function public.task_ledger_create_tree(
  agent_id_in text, agent_name_in text, task_definition_in jsonb,
  parent_task_id_in uuid default null, session_id_in text default null,
  agent_type_in text default null)
returns uuid language plpgsql set search_path=public as $$
declare task_id_out uuid; priority_value smallint; goal_id_value uuid;
  actions jsonb; cp jsonb; checkpoints jsonb;
begin
  if nullif(btrim(agent_id_in),'') is null or nullif(btrim(agent_name_in),'') is null
    then raise exception 'agent_id and agent_name are required'; end if;
  if jsonb_typeof(task_definition_in)<>'object'
     or nullif(btrim(task_definition_in->>'name'),'') is null
    then raise exception 'task_definition must be an object with a non-empty name'; end if;
  actions:=task_definition_in->'actions';
  if actions is null or jsonb_typeof(actions)<>'array'
     or jsonb_array_length(actions) not between 1 and 4
    then raise exception 'each task must contain 1-4 actions; split tasks requiring more than 4 actions'; end if;
  if parent_task_id_in is not null
    then raise exception 'bounded-v2 tasks cannot contain nested tasks; create another top-level task or goal'; end if;
  priority_value:=coalesce((task_definition_in->>'priority')::smallint,3);
  if priority_value not between 1 and 5 then raise exception 'priority must be between 1 and 5'; end if;
  goal_id_value:=nullif(task_definition_in->>'goal_id','')::uuid;
  if goal_id_value is not null and not exists(select 1 from public.goals where id=goal_id_value)
    then raise exception 'goal not found'; end if;

  cp:=coalesce(task_definition_in->'completion_parameters',
    (select jsonb_agg(jsonb_build_object(
      'id','cp-'||ord::text,'description',value->>'description','required',true)
      order by ord) from jsonb_array_elements(actions) with ordinality a(value,ord)),
    '[]'::jsonb);

  checkpoints:=coalesce(task_definition_in->'checkpoints',
    (select jsonb_agg(jsonb_build_object(
      'parameter_id','cp-'||ord::text,'objective',value->>'description',
      'status','pending','result',null,'context',coalesce(value->'context','{}'::jsonb),
      'evidence','[]'::jsonb) order by ord)
     from jsonb_array_elements(actions) with ordinality a(value,ord)),
    '[]'::jsonb);

  insert into public.tasks(
    goal_id,agent_id,agent_name,agent_type,session_id,task_name,description,status,tags,
    priority,parent_task_id,context_summary,metadata,due_at,task_definition,input_contract,
    output_contract,acceptance_criteria,verification_plan,loop_definition,required_tools,
    required_capabilities,max_attempts,execution_model,completion_parameters,checkpoints,
    current_checkpoint_index)
  values(
    goal_id_value,agent_id_in,agent_name_in,agent_type_in,session_id_in,
    task_definition_in->>'name',task_definition_in->>'description','queued',
    array(select jsonb_array_elements_text(coalesce(task_definition_in->'tags','[]'::jsonb))),
    priority_value,parent_task_id_in,task_definition_in->>'context_summary',
    coalesce(task_definition_in->'metadata','{}'::jsonb),
    nullif(task_definition_in->>'due_at','')::timestamptz,task_definition_in,
    coalesce(task_definition_in->'inputs','{}'::jsonb),
    coalesce(task_definition_in->'outputs','{}'::jsonb),
    coalesce(task_definition_in->'acceptance_criteria','[]'::jsonb),
    coalesce(task_definition_in->'verification','{}'::jsonb),
    coalesce(task_definition_in->'loop','{}'::jsonb),
    coalesce(task_definition_in->'required_tools','[]'::jsonb),
    array(select jsonb_array_elements_text(coalesce(task_definition_in->'required_capabilities','[]'::jsonb))),
    greatest(1,coalesce((task_definition_in->>'max_attempts')::integer,3)),
    'bounded-v2',cp,checkpoints,0)
  returning id into task_id_out;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_out,'registered',agent_id_in,task_definition_in->>'name',
    jsonb_build_object('goal_id',goal_id_value,'execution_model','bounded-v2',
      'checkpoint_count',jsonb_array_length(checkpoints)));
  return task_id_out;
end; $$;

create or replace function public.goal_ledger_create_hierarchical(
  title_in text,description_in text,context_in jsonb,instructions_in text,
  acceptance_criteria_in jsonb,tags_in text[],goal_loop_definition_in jsonb,
  task_definitions_in jsonb,created_by_agent_id_in text,
  owner_user_id_in uuid default auth.uid(),metadata_in jsonb default '{}'::jsonb)
returns jsonb language plpgsql set search_path=public as $$
declare goal_out public.goals; owner_id uuid; td jsonb; tid uuid; ids jsonb:='[]'::jsonb;
begin
  if nullif(btrim(title_in),'') is null then raise exception 'goal title is required'; end if;
  if nullif(btrim(created_by_agent_id_in),'') is null then raise exception 'creator agent identity is required'; end if;
  if jsonb_typeof(acceptance_criteria_in)<>'array'
     or jsonb_array_length(coalesce(acceptance_criteria_in,'[]'::jsonb))=0
    then raise exception 'goal requires non-empty acceptance criteria'; end if;
  if jsonb_typeof(task_definitions_in)<>'array'
     or jsonb_array_length(coalesce(task_definitions_in,'[]'::jsonb)) not between 1 and 4
    then raise exception 'goal must contain 1-4 direct tasks; create another goal for additional work'; end if;
  if jsonb_typeof(goal_loop_definition_in->'completion_parameters')='array'
     and jsonb_array_length(goal_loop_definition_in->'completion_parameters')>4
    then raise exception 'goal loop may contain at most 4 completion parameters'; end if;
  perform public.goal_ledger_validate_task_loop(jsonb_build_object(
    'name',title_in,'acceptance_criteria',acceptance_criteria_in,
    'loop',goal_loop_definition_in,'subtasks','[]'::jsonb),0);
  for td in select value from jsonb_array_elements(task_definitions_in) loop
    if jsonb_typeof(td->'subtasks')='array' and jsonb_array_length(td->'subtasks')>0
      then raise exception 'bounded-v2 tasks cannot contain nested tasks'; end if;
    perform public.goal_ledger_validate_task_loop(td,0);
  end loop;
  owner_id:=coalesce(owner_user_id_in,auth.uid());
  if auth.uid() is not null and owner_id is distinct from auth.uid()
    then raise exception 'goal owner must be the authenticated user'; end if;

  goal_out:=public.goal_ledger_create(title_in,description_in,context_in,instructions_in,
    acceptance_criteria_in,created_by_agent_id_in,owner_id,metadata_in);

  update public.goals set tags=coalesce((
    select array_agg(distinct lower(btrim(tag))) from unnest(coalesce(tags_in,'{}'::text[])) tag
    where btrim(tag)<>''
  ),'{}'::text[]),goal_loop_definition=goal_loop_definition_in,
  goal_loop_state=jsonb_build_object('current_input',goal_loop_definition_in->'initial_input','status','ready'),
  goal_loop_iteration=0,completion_parameters='[]'::jsonb,status='ready',updated_at=now()
  where id=goal_out.id returning * into goal_out;

  for td in select value from jsonb_array_elements(task_definitions_in) loop
    td:=jsonb_set(td,'{goal_id}',to_jsonb(goal_out.id::text),true);
    tid:=public.task_ledger_create_tree(created_by_agent_id_in,created_by_agent_id_in,td,null,null,'orchestrator');
    ids:=ids||to_jsonb(tid);
  end loop;

  update public.goals g set completion_parameters=coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',t.task_key,'task_id',t.id,'description',coalesce(t.description,t.task_name),'required',true)
      order by t.created_at,t.id)
    from public.tasks t where t.goal_id=g.id and t.parent_task_id is null
  ),'[]'::jsonb),updated_at=now() where g.id=goal_out.id returning * into goal_out;

  insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
  values(goal_out.id,'planned',created_by_agent_id_in,
    'Bounded-v2 goal created with at most four direct tasks',
    jsonb_build_object('goal_key',goal_out.goal_key,'top_level_task_ids',ids,
      'completion_parameter_count',jsonb_array_length(goal_out.completion_parameters)));
  return jsonb_build_object('goal',to_jsonb(goal_out),'goal_key',goal_out.goal_key,
    'top_level_task_ids',ids);
end; $$;

comment on column public.goals.completion_parameters is
'Bounded-v2 goal completion parameters: direct top-level tasks, maximum 4.';
comment on column public.tasks.execution_model is
'bounded-v2 enforces 1-4 completion parameters and one checkpoint per parameter.';
comment on column public.tasks.completion_parameters is
'Bounded-v2 task completion parameters, maximum 4.';
comment on column public.tasks.checkpoints is
'Bounded-v2 checkpoint array: parameter_id, objective, status, result, context and evidence.';
comment on column public.tasks.current_checkpoint_index is
'Zero-based pointer to the checkpoint currently being attempted.';
