-- Mark bounded-v2 explicitly at Goal level. Existing over-cap goals remain legacy
-- until a deliberate reconciliation pass moves their work into <=4-task goals.

alter table public.goals
  add column if not exists execution_model text not null default 'legacy';

alter table public.goals
  drop constraint if exists goals_execution_model_check;
alter table public.goals
  add constraint goals_execution_model_check
  check (execution_model in ('legacy','bounded-v2'));

create or replace function public.enforce_goal_direct_task_cap()
returns trigger language plpgsql set search_path=public as $$
declare direct_count integer; model text;
begin
  if new.goal_id is not null and new.parent_task_id is null then
    select execution_model into model from public.goals where id=new.goal_id for update;
    if model='bounded-v2' then
      perform pg_advisory_xact_lock(hashtextextended('goal-task-cap:'||new.goal_id::text,0));
      select count(*) into direct_count from public.tasks
      where goal_id=new.goal_id and parent_task_id is null
        and id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid);
      if direct_count>=4 then
        raise exception 'bounded-v2 goal may contain at most 4 direct tasks; create a new goal for additional work';
      end if;
    end if;
  end if;
  return new;
end; $$;

create or replace function public.sync_goal_completion_parameters()
returns trigger language plpgsql set search_path=public as $$
declare gid uuid; model text;
begin
  gid:=coalesce(new.goal_id,old.goal_id);
  if gid is not null then
    select execution_model into model from public.goals where id=gid;
    if model='bounded-v2' then
      update public.goals g set completion_parameters=coalesce((
        select jsonb_agg(jsonb_build_object('id',t.task_key,'task_id',t.id,'description',coalesce(t.description,t.task_name),'required',true) order by t.created_at,t.id)
        from public.tasks t where t.goal_id=gid and t.parent_task_id is null
      ),'[]'::jsonb),updated_at=now() where g.id=gid;
    end if;
  end if;
  if tg_op='UPDATE' and old.goal_id is distinct from new.goal_id and old.goal_id is not null then
    select execution_model into model from public.goals where id=old.goal_id;
    if model='bounded-v2' then
      update public.goals g set completion_parameters=coalesce((
        select jsonb_agg(jsonb_build_object('id',t.task_key,'task_id',t.id,'description',coalesce(t.description,t.task_name),'required',true) order by t.created_at,t.id)
        from public.tasks t where t.goal_id=old.goal_id and t.parent_task_id is null
      ),'[]'::jsonb),updated_at=now() where g.id=old.goal_id;
    end if;
  end if;
  return coalesce(new,old);
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
  if jsonb_typeof(acceptance_criteria_in)<>'array' or jsonb_array_length(coalesce(acceptance_criteria_in,'[]'::jsonb))=0 then raise exception 'goal requires non-empty acceptance criteria'; end if;
  if jsonb_typeof(task_definitions_in)<>'array' or jsonb_array_length(coalesce(task_definitions_in,'[]'::jsonb)) not between 1 and 4 then raise exception 'bounded-v2 goal must contain 1-4 direct tasks; create another goal for additional work'; end if;
  if jsonb_typeof(goal_loop_definition_in->'completion_parameters')='array' and jsonb_array_length(goal_loop_definition_in->'completion_parameters')>4 then raise exception 'goal loop may contain at most 4 completion parameters'; end if;
  perform public.goal_ledger_validate_task_loop(jsonb_build_object('name',title_in,'acceptance_criteria',acceptance_criteria_in,'loop',goal_loop_definition_in,'subtasks','[]'::jsonb),0);
  for td in select value from jsonb_array_elements(task_definitions_in) loop
    if jsonb_typeof(td->'subtasks')='array' and jsonb_array_length(td->'subtasks')>0 then raise exception 'bounded-v2 tasks cannot contain nested tasks'; end if;
    perform public.goal_ledger_validate_task_loop(td,0);
  end loop;
  owner_id:=coalesce(owner_user_id_in,auth.uid());
  if auth.uid() is not null and owner_id is distinct from auth.uid() then raise exception 'goal owner must be the authenticated user'; end if;
  goal_out:=public.goal_ledger_create(title_in,description_in,context_in,instructions_in,acceptance_criteria_in,created_by_agent_id_in,owner_id,metadata_in);
  update public.goals set execution_model='bounded-v2',tags=coalesce((select array_agg(distinct lower(btrim(tag))) from unnest(coalesce(tags_in,'{}'::text[])) tag where btrim(tag)<>''),'{}'::text[]),goal_loop_definition=goal_loop_definition_in,goal_loop_state=jsonb_build_object('current_input',goal_loop_definition_in->'initial_input','status','ready'),goal_loop_iteration=0,completion_parameters='[]'::jsonb,status='ready',updated_at=now() where id=goal_out.id returning * into goal_out;
  for td in select value from jsonb_array_elements(task_definitions_in) loop
    td:=jsonb_set(td,'{goal_id}',to_jsonb(goal_out.id::text),true);
    tid:=public.task_ledger_create_tree(created_by_agent_id_in,created_by_agent_id_in,td,null,null,'orchestrator');
    ids:=ids||to_jsonb(tid);
  end loop;
  update public.goals g set completion_parameters=coalesce((select jsonb_agg(jsonb_build_object('id',t.task_key,'task_id',t.id,'description',coalesce(t.description,t.task_name),'required',true) order by t.created_at,t.id) from public.tasks t where t.goal_id=g.id and t.parent_task_id is null),'[]'::jsonb),updated_at=now() where g.id=goal_out.id returning * into goal_out;
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload) values(goal_out.id,'planned',created_by_agent_id_in,'Bounded-v2 goal created with at most four direct tasks',jsonb_build_object('goal_key',goal_out.goal_key,'top_level_task_ids',ids,'completion_parameter_count',jsonb_array_length(goal_out.completion_parameters)));
  return jsonb_build_object('goal',to_jsonb(goal_out),'goal_key',goal_out.goal_key,'top_level_task_ids',ids);
end; $$;

comment on column public.goals.execution_model is 'bounded-v2 enforces the four-direct-task Goal contract; legacy preserves pre-existing over-cap work for safe reconciliation.';
