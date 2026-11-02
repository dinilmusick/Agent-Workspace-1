
create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  context jsonb not null default '{}'::jsonb,
  instructions text not null default '',
  acceptance_criteria jsonb not null default '[]'::jsonb,
  status text not null default 'planning' check (status in ('planning','ready','active','blocked','completed','cancelled','archived')),
  context_version integer not null default 1 check (context_version > 0),
  created_by_agent_id text not null,
  owner_user_id uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);
create unique index if not exists goals_name_ci_uidx on public.goals (lower(name));
create index if not exists goals_status_updated_idx on public.goals(status, updated_at desc);
create table if not exists public.goal_versions (
  id bigint generated always as identity primary key,
  goal_id uuid not null references public.goals(id) on delete cascade,
  version integer not null,
  snapshot jsonb not null,
  changed_by_agent_id text not null,
  change_reason text,
  created_at timestamptz not null default now(),
  unique(goal_id, version)
);
create index if not exists goal_versions_goal_idx on public.goal_versions(goal_id, version desc);
create table if not exists public.goal_events (
  id bigint generated always as identity primary key,
  goal_id uuid not null references public.goals(id) on delete cascade,
  event_type text not null check (event_type in ('created','planned','resumed','context_updated','status_changed','task_tree_created','completed','blocked','note')),
  agent_id text not null,
  message text,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);
create index if not exists goal_events_goal_time_idx on public.goal_events(goal_id, occurred_at desc);
alter table public.tasks add column if not exists goal_id uuid references public.goals(id) on delete cascade;
create index if not exists tasks_goal_status_priority_idx on public.tasks(goal_id, status, priority, started_at);
create index if not exists tasks_goal_parent_idx on public.tasks(goal_id, parent_task_id);
alter table public.goals enable row level security;
alter table public.goal_versions enable row level security;
alter table public.goal_events enable row level security;
revoke all on public.goals, public.goal_versions, public.goal_events from anon, authenticated;
grant select, insert, update, delete on public.goals, public.goal_versions, public.goal_events to service_role;
grant usage, select on sequence public.goal_versions_id_seq, public.goal_events_id_seq to service_role;
create or replace function public.goal_ledger_create(name_in text, description_in text, context_in jsonb, instructions_in text, acceptance_criteria_in jsonb, created_by_agent_id_in text, owner_user_id_in uuid default null, metadata_in jsonb default '{}'::jsonb)
returns public.goals language plpgsql security invoker set search_path=public as $$
declare goal_out public.goals;
begin
 if nullif(btrim(name_in),'') is null then raise exception 'goal name is required'; end if;
 if nullif(btrim(created_by_agent_id_in),'') is null then raise exception 'created_by_agent_id is required'; end if;
 if jsonb_typeof(coalesce(context_in,'{}'::jsonb)) <> 'object' then raise exception 'context must be an object'; end if;
 if jsonb_typeof(coalesce(acceptance_criteria_in,'[]'::jsonb)) <> 'array' then raise exception 'acceptance_criteria must be an array'; end if;
 insert into public.goals(name,description,context,instructions,acceptance_criteria,created_by_agent_id,owner_user_id,metadata)
 values(btrim(name_in),coalesce(description_in,''),coalesce(context_in,'{}'::jsonb),coalesce(instructions_in,''),coalesce(acceptance_criteria_in,'[]'::jsonb),btrim(created_by_agent_id_in),owner_user_id_in,coalesce(metadata_in,'{}'::jsonb)) returning * into goal_out;
 insert into public.goal_versions(goal_id,version,snapshot,changed_by_agent_id,change_reason)
 values(goal_out.id,1,jsonb_build_object('name',goal_out.name,'description',goal_out.description,'context',goal_out.context,'instructions',goal_out.instructions,'acceptance_criteria',goal_out.acceptance_criteria,'metadata',goal_out.metadata),goal_out.created_by_agent_id,'Initial goal definition');
 insert into public.goal_events(goal_id,event_type,agent_id,message,payload) values(goal_out.id,'created',goal_out.created_by_agent_id,'Goal created',jsonb_build_object('name',goal_out.name,'context_version',1));
 return goal_out;
end; $$;
create or replace function public.goal_ledger_get(goal_id_in uuid default null, name_in text default null)
returns public.goals language plpgsql security invoker set search_path=public as $$
declare goal_out public.goals;
begin
 if goal_id_in is null and nullif(btrim(name_in),'') is null then raise exception 'goal_id or name is required'; end if;
 select * into goal_out from public.goals where (goal_id_in is not null and id=goal_id_in) or (goal_id_in is null and lower(name)=lower(btrim(name_in))) limit 1;
 if not found then raise exception 'goal not found'; end if;
 return goal_out;
end; $$;
create or replace function public.goal_ledger_update(goal_id_in uuid, changed_by_agent_id_in text, description_in text default null, context_in jsonb default null, instructions_in text default null, acceptance_criteria_in jsonb default null, status_in text default null, metadata_patch_in jsonb default '{}'::jsonb, change_reason_in text default null)
returns public.goals language plpgsql security invoker set search_path=public as $$
declare old_goal public.goals; goal_out public.goals;
begin
 select * into old_goal from public.goals where id=goal_id_in for update;
 if not found then raise exception 'goal not found'; end if;
 if nullif(btrim(changed_by_agent_id_in),'') is null then raise exception 'changed_by_agent_id is required'; end if;
 if status_in is not null and status_in not in ('planning','ready','active','blocked','completed','cancelled','archived') then raise exception 'invalid goal status'; end if;
 if context_in is not null and jsonb_typeof(context_in) <> 'object' then raise exception 'context must be an object'; end if;
 if acceptance_criteria_in is not null and jsonb_typeof(acceptance_criteria_in) <> 'array' then raise exception 'acceptance_criteria must be an array'; end if;
 update public.goals set description=coalesce(description_in,description),context=coalesce(context_in,context),instructions=coalesce(instructions_in,instructions),acceptance_criteria=coalesce(acceptance_criteria_in,acceptance_criteria),status=coalesce(status_in,status),metadata=metadata||coalesce(metadata_patch_in,'{}'::jsonb),
 context_version=context_version+case when context_in is not null or description_in is not null or instructions_in is not null or acceptance_criteria_in is not null then 1 else 0 end,
 updated_at=now(),completed_at=case when status_in='completed' then now() when status_in is not null then null else completed_at end
 where id=goal_id_in returning * into goal_out;
 if goal_out.context_version <> old_goal.context_version then
  insert into public.goal_versions(goal_id,version,snapshot,changed_by_agent_id,change_reason)
  values(goal_out.id,goal_out.context_version,jsonb_build_object('name',goal_out.name,'description',goal_out.description,'context',goal_out.context,'instructions',goal_out.instructions,'acceptance_criteria',goal_out.acceptance_criteria,'metadata',goal_out.metadata),changed_by_agent_id_in,change_reason_in);
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload) values(goal_out.id,'context_updated',changed_by_agent_id_in,coalesce(change_reason_in,'Goal context updated'),jsonb_build_object('context_version',goal_out.context_version));
 end if;
 if status_in is not null and status_in is distinct from old_goal.status then
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload) values(goal_out.id,case when status_in='completed' then 'completed' when status_in='blocked' then 'blocked' else 'status_changed' end,changed_by_agent_id_in,'Goal status changed',jsonb_build_object('from',old_goal.status,'to',status_in));
 end if;
 return goal_out;
end; $$;
create or replace function public.goal_ledger_summary(goal_id_in uuid)
returns jsonb language sql stable security invoker set search_path=public as $$
 with g as (select id,name,status,context_version from public.goals where id=goal_id_in),
 counts as (
  select count(*)::int total,count(*) filter(where status='completed' and verification_status in ('verified','not_required'))::int completed,count(*) filter(where status='failed')::int failed,count(*) filter(where status='blocked')::int blocked,
  count(*) filter(where status in ('queued','running') and (claim_expires_at is null or claim_expires_at<now()) and not exists(select 1 from public.task_dependencies d join public.tasks dep on dep.id=d.depends_on_task_id where d.task_id=tasks.id and d.dependency_type='blocking' and (dep.status<>'completed' or dep.verification_status<>'verified')))::int ready
  from public.tasks where goal_id=goal_id_in
 )
 select jsonb_build_object('goal',g,'tasks',jsonb_build_object('total',counts.total,'completed',counts.completed,'failed',counts.failed,'blocked',counts.blocked,'ready',counts.ready,'remaining',greatest(counts.total-counts.completed,0)),'recommended_workers',least(counts.ready,greatest(1,ceil(counts.ready::numeric/2)::int))) from g cross join counts;
$$;
create or replace function public.task_ledger_create_tree(agent_id_in text, agent_name_in text, task_definition_in jsonb, parent_task_id_in uuid default null, session_id_in text default null, agent_type_in text default null)
returns uuid language plpgsql set search_path=public as $function$
declare task_id_out uuid; child_definition jsonb; priority_value smallint; goal_id_value uuid;
begin
 if nullif(btrim(agent_id_in),'') is null or nullif(btrim(agent_name_in),'') is null then raise exception 'agent_id and agent_name are required'; end if;
 if jsonb_typeof(task_definition_in)<>'object' or nullif(btrim(task_definition_in->>'name'),'') is null then raise exception 'task_definition must be an object with a non-empty name'; end if;
 priority_value:=coalesce((task_definition_in->>'priority')::smallint,3);
 if priority_value<1 or priority_value>5 then raise exception 'priority must be between 1 and 5'; end if;
 if parent_task_id_in is not null and not exists(select 1 from public.tasks where id=parent_task_id_in) then raise exception 'parent task not found'; end if;
 goal_id_value:=coalesce(nullif(task_definition_in->>'goal_id','')::uuid,(select goal_id from public.tasks where id=parent_task_id_in));
 if goal_id_value is not null and not exists(select 1 from public.goals where id=goal_id_value) then raise exception 'goal not found'; end if;
 if parent_task_id_in is not null and goal_id_value is distinct from (select goal_id from public.tasks where id=parent_task_id_in) then raise exception 'child task goal must match parent goal'; end if;
 if jsonb_typeof(coalesce(task_definition_in->'subtasks','[]'::jsonb))<>'array' then raise exception 'subtasks must be a JSON array'; end if;
 insert into public.tasks(goal_id,agent_id,agent_name,agent_type,session_id,task_name,description,status,tags,priority,parent_task_id,context_summary,metadata,due_at,task_definition,input_contract,output_contract,acceptance_criteria,verification_plan,loop_definition,required_tools,required_capabilities,max_attempts)
 values(goal_id_value,agent_id_in,agent_name_in,agent_type_in,session_id_in,task_definition_in->>'name',task_definition_in->>'description','queued',array(select jsonb_array_elements_text(coalesce(task_definition_in->'tags','[]'::jsonb))),priority_value,parent_task_id_in,task_definition_in->>'context_summary',coalesce(task_definition_in->'metadata','{}'::jsonb),nullif(task_definition_in->>'due_at','')::timestamptz,task_definition_in,coalesce(task_definition_in->'inputs','{}'::jsonb),coalesce(task_definition_in->'outputs','{}'::jsonb),coalesce(task_definition_in->'acceptance_criteria','[]'::jsonb),coalesce(task_definition_in->'verification','{}'::jsonb),coalesce(task_definition_in->'loop','{}'::jsonb),coalesce(task_definition_in->'required_tools','[]'::jsonb),array(select jsonb_array_elements_text(coalesce(task_definition_in->'required_capabilities','[]'::jsonb))),greatest(1,coalesce((task_definition_in->>'max_attempts')::integer,3))) returning id into task_id_out;
 insert into public.task_events(task_id,event_type,agent_id,message,payload) values(task_id_out,'registered',agent_id_in,task_definition_in->>'name',jsonb_build_object('parent_task_id',parent_task_id_in,'goal_id',goal_id_value,'definition',task_definition_in));
 for child_definition in select value from jsonb_array_elements(coalesce(task_definition_in->'subtasks','[]'::jsonb)) loop
  perform public.task_ledger_create_tree(agent_id_in,agent_name_in,child_definition,task_id_out,session_id_in,agent_type_in);
 end loop;
 if jsonb_array_length(coalesce(task_definition_in->'subtasks','[]'::jsonb))>0 then insert into public.task_events(task_id,event_type,agent_id,message,payload) values(task_id_out,'tree_created',agent_id_in,'Nested task tree created',jsonb_build_object('direct_subtask_count',jsonb_array_length(task_definition_in->'subtasks'))); end if;
 return task_id_out;
end; $function$;
revoke all on function public.goal_ledger_create(text,text,jsonb,text,jsonb,text,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.goal_ledger_get(uuid,text) from public,anon,authenticated;
revoke all on function public.goal_ledger_update(uuid,text,text,jsonb,text,jsonb,text,jsonb,text) from public,anon,authenticated;
revoke all on function public.goal_ledger_summary(uuid) from public,anon,authenticated;
revoke all on function public.task_ledger_create_tree(text,text,jsonb,uuid,text,text) from public,anon,authenticated;
grant execute on function public.goal_ledger_create(text,text,jsonb,text,jsonb,text,uuid,jsonb) to service_role;
grant execute on function public.goal_ledger_get(uuid,text) to service_role;
grant execute on function public.goal_ledger_update(uuid,text,text,jsonb,text,jsonb,text,jsonb,text) to service_role;
grant execute on function public.goal_ledger_summary(uuid) to service_role;
grant execute on function public.task_ledger_create_tree(text,text,jsonb,uuid,text,text) to service_role;
revoke execute on function public.task_ledger_pending_verification() from public,anon,authenticated;
