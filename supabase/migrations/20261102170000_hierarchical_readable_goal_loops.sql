alter table public.goals
  add column if not exists goal_key text,
  add column if not exists tags text[] not null default '{}',
  add column if not exists goal_loop_definition jsonb not null default '{}',
  add column if not exists goal_loop_state jsonb not null default '{}',
  add column if not exists goal_loop_iteration integer not null default 0;

do $$
declare g record; base_key text; candidate_key text; suffix integer;
begin
  for g in select id,name from public.goals where goal_key is null order by created_at,id loop
    base_key := trim(both '-' from regexp_replace(lower(g.name),'[^a-z0-9]+','-','g'));
    if base_key = '' then base_key := 'goal'; end if;
    candidate_key := base_key; suffix := 2;
    while exists(select 1 from public.goals where goal_key=candidate_key) loop
      candidate_key := base_key || '-' || suffix::text; suffix := suffix + 1;
    end loop;
    update public.goals set goal_key=candidate_key,
      tags=case when jsonb_typeof(metadata->'tags')='array'
        then array(select lower(btrim(value)) from jsonb_array_elements_text(metadata->'tags') value where btrim(value)<>'')
        else '{}'::text[] end
    where id=g.id;
  end loop;
end $$;

alter table public.goals alter column goal_key set not null;
create unique index if not exists goals_goal_key_uidx on public.goals(goal_key);
create index if not exists goals_tags_gin_idx on public.goals using gin(tags);
create index if not exists goals_status_updated_idx on public.goals(status,updated_at desc);

create or replace function public.goals_assign_readable_key()
returns trigger language plpgsql set search_path=public
as $$
declare base_key text; suffix integer:=2;
begin
  if new.goal_key is null or btrim(new.goal_key)='' then
    base_key:=trim(both '-' from regexp_replace(lower(new.name),'[^a-z0-9]+','-','g'));
    if base_key='' then base_key:='goal'; end if;
    perform pg_advisory_xact_lock(hashtextextended('goal-key:'||base_key,0));
    new.goal_key:=base_key;
    while exists(select 1 from public.goals where goal_key=new.goal_key) loop
      new.goal_key:=base_key||'-'||suffix::text; suffix:=suffix+1;
    end loop;
  end if;
  if jsonb_typeof(new.metadata->'tags')='array' and coalesce(cardinality(new.tags),0)=0 then
    new.tags:=array(select distinct lower(btrim(value))
      from jsonb_array_elements_text(new.metadata->'tags') value where btrim(value)<>'');
  end if;
  return new;
end;
$$;
drop trigger if exists goals_assign_readable_key on public.goals;
create trigger goals_assign_readable_key before insert on public.goals
for each row execute function public.goals_assign_readable_key();

alter table public.tasks
  add column if not exists parameters jsonb not null default '{}',
  add column if not exists parameter_contract jsonb not null default '{}',
  add column if not exists parameter_values jsonb not null default '{}';

create or replace function public.task_ledger_validate_parameter_values(
  parameter_contract_in jsonb, parameter_values_in jsonb
) returns boolean language plpgsql immutable set search_path=public
as $$
declare required_key text; property_key text; property_rule jsonb;
  expected_type text; actual_type text;
begin
  if coalesce(jsonb_typeof(parameter_contract_in),'object')<>'object'
     or coalesce(jsonb_typeof(parameter_values_in),'object')<>'object' then
    raise exception 'task parameter contract and values must be JSON objects';
  end if;
  for required_key in select jsonb_array_elements_text(
    coalesce(parameter_contract_in->'required','[]'::jsonb)) loop
    if not (parameter_values_in ? required_key)
       or parameter_values_in->required_key='null'::jsonb then
      raise exception 'required task parameter "%" is missing',required_key;
    end if;
  end loop;
  for property_key,property_rule in select key,value
    from jsonb_each(coalesce(parameter_contract_in->'properties','{}'::jsonb)) loop
    if not (parameter_values_in ? property_key) then continue; end if;
    expected_type:=property_rule->>'type';
    actual_type:=jsonb_typeof(parameter_values_in->property_key);
    if expected_type='integer' and actual_type='number' then
      if (parameter_values_in->>property_key)::numeric % 1<>0 then
        raise exception 'task parameter "%" must be an integer',property_key;
      end if;
    elsif expected_type is not null and expected_type<>actual_type then
      raise exception 'task parameter "%" must have JSON type %, received %',
        property_key,expected_type,actual_type;
    end if;
    if jsonb_typeof(property_rule->'enum')='array'
       and not exists(select 1 from jsonb_array_elements(property_rule->'enum') e
         where e.value=parameter_values_in->property_key) then
      raise exception 'task parameter "%" is outside its allowed enum',property_key;
    end if;
  end loop;
  return true;
end;
$$;

create or replace function public.task_ledger_sync_parameter_fields()
returns trigger language plpgsql set search_path=public
as $$
begin
  new.parameters:=coalesce(new.task_definition->'parameters',new.parameters,'{}'::jsonb);
  new.parameter_contract:=coalesce(new.task_definition->'parameter_contract',new.parameter_contract,'{}'::jsonb);
  new.parameter_values:=coalesce(new.task_definition->'parameter_values',new.parameter_values,'{}'::jsonb);
  perform public.task_ledger_validate_parameter_values(new.parameter_contract,new.parameter_values);
  return new;
end;
$$;
drop trigger if exists tasks_sync_parameter_fields on public.tasks;
create trigger tasks_sync_parameter_fields
before insert or update of task_definition,parameter_values,parameter_contract
on public.tasks for each row execute function public.task_ledger_sync_parameter_fields();

create table if not exists public.goal_iterations (
  id bigint generated by default as identity primary key,
  goal_id uuid not null references public.goals(id) on delete cascade,
  iteration_no integer not null check(iteration_no>0),
  agent_id text not null,
  status text not null default 'completed',
  input_payload jsonb not null default '{}',
  output_payload jsonb not null default '{}',
  observation jsonb not null default '{}',
  criterion_results jsonb not null default '[]',
  loop_state jsonb not null default '{}',
  tools_used jsonb not null default '[]',
  evidence jsonb not null default '[]',
  verdict text not null check(verdict in ('continue','pass','error','blocked','cancelled')),
  next_action text,
  started_at timestamptz not null default now(),
  completed_at timestamptz not null default now(),
  unique(goal_id,iteration_no)
);
create index if not exists goal_iterations_goal_order_idx
  on public.goal_iterations(goal_id,iteration_no desc);
alter table public.goal_iterations enable row level security;
drop policy if exists goal_iterations_owner_access on public.goal_iterations;
create policy goal_iterations_owner_access on public.goal_iterations for all to authenticated
  using(exists(select 1 from public.goals g where g.id=goal_iterations.goal_id and g.owner_user_id=(select auth.uid())))
  with check(exists(select 1 from public.goals g where g.id=goal_iterations.goal_id and g.owner_user_id=(select auth.uid())));
grant select,insert on public.goal_iterations to authenticated;
grant usage,select on sequence public.goal_iterations_id_seq to authenticated;

create or replace function public.goal_ledger_create_hierarchical(
  title_in text, description_in text, context_in jsonb, instructions_in text,
  acceptance_criteria_in jsonb, tags_in text[], goal_loop_definition_in jsonb,
  task_definitions_in jsonb, created_by_agent_id_in text,
  owner_user_id_in uuid default auth.uid(), metadata_in jsonb default '{}'
) returns jsonb language plpgsql set search_path=public
as $$
declare goal_out public.goals; owner_id uuid; task_definition jsonb;
  task_id uuid; task_ids jsonb:='[]'::jsonb;
begin
  if nullif(btrim(title_in),'') is null then raise exception 'goal title is required'; end if;
  if nullif(btrim(created_by_agent_id_in),'') is null then raise exception 'creator agent identity is required'; end if;
  if coalesce(jsonb_typeof(acceptance_criteria_in),'null')<>'array'
     or jsonb_array_length(coalesce(acceptance_criteria_in,'[]'::jsonb))=0 then
    raise exception 'goal requires non-empty acceptance criteria';
  end if;
  if coalesce(jsonb_typeof(task_definitions_in),'null')<>'array'
     or jsonb_array_length(coalesce(task_definitions_in,'[]'::jsonb))=0 then
    raise exception 'goal requires at least one top-level task';
  end if;
  perform public.goal_ledger_validate_task_loop(jsonb_build_object(
    'name',title_in,'acceptance_criteria',acceptance_criteria_in,
    'loop',goal_loop_definition_in,'subtasks','[]'::jsonb),0);
  for task_definition in select value from jsonb_array_elements(task_definitions_in) loop
    perform public.goal_ledger_validate_task_loop(task_definition,0);
  end loop;
  owner_id:=coalesce(owner_user_id_in,auth.uid());
  if auth.uid() is not null and owner_id is distinct from auth.uid() then
    raise exception 'goal owner must be the authenticated user';
  end if;
  goal_out:=public.goal_ledger_create(title_in,description_in,context_in,instructions_in,
    acceptance_criteria_in,created_by_agent_id_in,owner_id,metadata_in);
  update public.goals set
    tags=coalesce((select array_agg(distinct lower(btrim(tag)))
      from unnest(coalesce(tags_in,'{}'::text[])) tag where btrim(tag)<>''),'{}'::text[]),
    goal_loop_definition=goal_loop_definition_in,
    goal_loop_state=jsonb_build_object('current_input',goal_loop_definition_in->'initial_input','status','ready'),
    goal_loop_iteration=0,status='ready',updated_at=now()
  where id=goal_out.id returning * into goal_out;
  update public.goal_versions set snapshot=snapshot||jsonb_build_object(
    'goal_key',goal_out.goal_key,'tags',to_jsonb(goal_out.tags),
    'goal_loop_definition',goal_out.goal_loop_definition)
  where goal_id=goal_out.id and version=1;
  for task_definition in select value from jsonb_array_elements(task_definitions_in) loop
    task_definition:=jsonb_set(task_definition,'{goal_id}',to_jsonb(goal_out.id::text),true);
    task_id:=public.task_ledger_create_tree(created_by_agent_id_in,created_by_agent_id_in,
      task_definition,null,null,'orchestrator');
    task_ids:=task_ids||to_jsonb(task_id);
  end loop;
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
  values(goal_out.id,'planned',created_by_agent_id_in,
    'Readable goal identity, goal loop and direct task tree created',
    jsonb_build_object('goal_key',goal_out.goal_key,'tags',goal_out.tags,
      'top_level_task_ids',task_ids,'goal_loop_required',true));
  return jsonb_build_object('goal',to_jsonb(goal_out),'goal_key',goal_out.goal_key,
    'top_level_task_ids',task_ids);
end;
$$;

create or replace function public.goal_ledger_list_unfinished(tags_in text[] default null)
returns setof public.goals language sql stable set search_path=public
as $$
  select g.* from public.goals g
  where g.status in ('planning','ready','active','blocked')
    and (tags_in is null or g.tags && tags_in)
    and (auth.uid() is null or g.owner_user_id=auth.uid())
  order by g.updated_at desc,g.name;
$$;

create or replace function public.goal_ledger_get_by_key(goal_key_in text)
returns public.goals language plpgsql stable set search_path=public
as $$
declare goal_out public.goals;
begin
  select * into goal_out from public.goals
  where lower(goal_key)=lower(btrim(goal_key_in))
    and (auth.uid() is null or owner_user_id=auth.uid());
  if not found then raise exception 'goal not found or access denied: %',goal_key_in; end if;
  return goal_out;
end;
$$;

create or replace function public.goal_ledger_resume_by_key(goal_key_in text)
returns jsonb language plpgsql stable set search_path=public
as $$
declare goal_out public.goals; result_out jsonb;
begin
  goal_out:=public.goal_ledger_get_by_key(goal_key_in);
  result_out:=public.goal_ledger_resume(goal_out.name);
  return result_out||jsonb_build_object('goal_iterations',
    coalesce((select jsonb_agg(to_jsonb(i) order by i.iteration_no)
      from public.goal_iterations i where i.goal_id=goal_out.id),'[]'::jsonb));
end;
$$;

create or replace function public.goal_ledger_list_filtered(
  status_in text default null, tags_in text[] default null
) returns setof public.goals language sql stable set search_path=public
as $$
  select g.* from public.goals g
  where (status_in is null or g.status=status_in)
    and (tags_in is null or g.tags && tags_in)
    and (auth.uid() is null or g.owner_user_id=auth.uid())
  order by g.updated_at desc,g.name;
$$;

create or replace function public.goal_ledger_record_loop_iteration(
  goal_id_in uuid, agent_id_in text, iteration_no_in integer,
  input_payload_in jsonb, output_payload_in jsonb, observation_in jsonb,
  criterion_results_in jsonb, loop_state_in jsonb,
  tools_used_in jsonb default '[]', evidence_in jsonb default '[]',
  verdict_in text default 'continue', next_action_in text default null
) returns public.goal_iterations language plpgsql set search_path=public
as $$
declare goal_out public.goals; iteration_out public.goal_iterations;
  criterion_count integer; satisfied_count integer; max_allowed integer;
begin
  if nullif(btrim(agent_id_in),'') is null then raise exception 'goal loop agent identity is required'; end if;
  if verdict_in not in ('continue','pass','error','blocked','cancelled') then raise exception 'invalid goal loop verdict'; end if;
  if coalesce(jsonb_typeof(criterion_results_in),'null')<>'array'
     or jsonb_array_length(coalesce(criterion_results_in,'[]'::jsonb))=0 then
    raise exception 'goal loop requires non-empty criterion results';
  end if;
  select * into goal_out from public.goals
  where id=goal_id_in and (auth.uid() is null or owner_user_id=auth.uid()) for update;
  if not found then raise exception 'goal not found or access denied'; end if;
  max_allowed:=coalesce((goal_out.goal_loop_definition->>'max_iterations')::integer,0);
  if iteration_no_in<1 or iteration_no_in>max_allowed
     or iteration_no_in<>goal_out.goal_loop_iteration+1 then
    raise exception 'goal loop iteration must be sequential and within its configured budget';
  end if;
  select count(*),count(*) filter(where value->>'status'='satisfied')
    into criterion_count,satisfied_count from jsonb_array_elements(criterion_results_in);
  if exists(select 1 from jsonb_array_elements(criterion_results_in) c
    where c->>'status' not in ('satisfied','unsatisfied','unknown')) then
    raise exception 'invalid goal criterion status';
  end if;
  if verdict_in='pass' then
    if criterion_count<>satisfied_count or jsonb_array_length(coalesce(evidence_in,'[]'::jsonb))=0 then
      raise exception 'goal loop pass requires every criterion satisfied with evidence';
    end if;
    if exists(select 1 from public.tasks t where t.goal_id=goal_id_in
      and not (t.status='completed' and t.verification_status in ('verified','not_required'))) then
      raise exception 'goal loop cannot pass until every task is independently verified';
    end if;
  end if;
  insert into public.goal_iterations(goal_id,iteration_no,agent_id,input_payload,output_payload,
    observation,criterion_results,loop_state,tools_used,evidence,verdict,next_action)
  values(goal_id_in,iteration_no_in,agent_id_in,coalesce(input_payload_in,'{}'),
    coalesce(output_payload_in,'{}'),coalesce(observation_in,'{}'),criterion_results_in,
    coalesce(loop_state_in,'{}'),coalesce(tools_used_in,'[]'),coalesce(evidence_in,'[]'),
    verdict_in,next_action_in) returning * into iteration_out;
  update public.goals set goal_loop_iteration=iteration_no_in,
    goal_loop_state=coalesce(loop_state_in,'{}')||jsonb_build_object(
      'last_verdict',verdict_in,'next_action',next_action_in),
    status=case when status='ready' then 'active' else status end,updated_at=now()
  where id=goal_id_in;
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
  values(goal_id_in,'goal_loop_iteration_recorded',agent_id_in,coalesce(next_action_in,verdict_in),
    jsonb_build_object('iteration_no',iteration_no_in,'verdict',verdict_in,
      'criterion_results',criterion_results_in,'evidence_count',jsonb_array_length(coalesce(evidence_in,'[]'))));
  return iteration_out;
end;
$$;

create or replace function public.goal_ledger_claim_task_by_key(
  goal_key_in text, agent_id_in text, agent_name_in text,
  agent_type_in text default 'worker', capabilities_in text[] default '{}',
  session_id_in text default null, lease_seconds_in integer default 900
) returns setof public.tasks language plpgsql set search_path=public
as $$
declare goal_out public.goals; task_out public.tasks;
begin
  goal_out:=public.goal_ledger_get_by_key(goal_key_in);
  if goal_out.status not in ('ready','active','blocked') then
    raise exception 'goal is not unfinished: %',goal_out.name;
  end if;
  return query select * from public.goal_ledger_claim_task(
    goal_out.name,agent_id_in,agent_name_in,agent_type_in,capabilities_in,session_id_in,lease_seconds_in);
end;
$$;

create or replace function public.goal_ledger_finalize_by_key(
  goal_key_in text, finalized_by_agent_id_in text, verification_report_in jsonb default '{}'
) returns public.goals language plpgsql set search_path=public
as $$
declare goal_out public.goals;
begin
  goal_out:=public.goal_ledger_get_by_key(goal_key_in);
  return public.goal_ledger_finalize(goal_out.name,finalized_by_agent_id_in,verification_report_in);
end;
$$;

create or replace function public.goals_require_goal_loop_pass()
returns trigger language plpgsql set search_path=public
as $$
declare latest public.goal_iterations;
begin
  if new.status='completed' and old.status is distinct from 'completed'
     and new.goal_loop_definition->>'enabled'='true' then
    select * into latest from public.goal_iterations
      where goal_id=new.id order by iteration_no desc limit 1;
    if latest.id is null or latest.verdict<>'pass'
       or jsonb_array_length(latest.evidence)=0
       or exists(select 1 from jsonb_array_elements(latest.criterion_results) c
         where c->>'status'<>'satisfied') then
      raise exception 'goal cannot complete before its own goal loop passes with evidence';
    end if;
    if exists(select 1 from public.tasks t where t.goal_id=new.id
      and not (t.status='completed' and t.verification_status in ('verified','not_required'))) then
      raise exception 'goal cannot complete before every task is independently verified';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists goals_require_goal_loop_pass on public.goals;
create trigger goals_require_goal_loop_pass before update of status on public.goals
for each row execute function public.goals_require_goal_loop_pass();

create or replace function public.task_ledger_submit_result(
  task_id_in uuid, agent_id_in text, claim_token_in uuid, result_in jsonb,
  result_summary_in text default null, tools_used_in jsonb default '[]',
  evidence_in jsonb default '[]', status_in text default 'completed'
) returns public.tasks language plpgsql set search_path=public
as $$
declare task_out public.tasks; values_out jsonb; latest_iteration public.task_iterations;
begin
  if status_in not in ('completed','failed','blocked','waiting') then
    raise exception 'result status must be completed, failed, blocked, or waiting';
  end if;
  select * into task_out from public.tasks
  where id=task_id_in and claimed_by_agent_id=agent_id_in
    and claim_token=claim_token_in and status='running' for update;
  if not found then raise exception 'task claim not found or not owned by submitting agent'; end if;
  values_out:=coalesce(result_in->'parameter_values',task_out.parameter_values,'{}'::jsonb);
  perform public.task_ledger_validate_parameter_values(task_out.parameter_contract,values_out);
  if status_in='completed' and task_out.loop_definition->>'enabled'='true' then
    select * into latest_iteration from public.task_iterations
      where task_id=task_id_in order by iteration_no desc limit 1;
    if latest_iteration.id is null or latest_iteration.agent_id<>agent_id_in
       or latest_iteration.decision not like 'pass%'
       or jsonb_array_length(latest_iteration.evidence)=0
       or exists(select 1 from jsonb_array_elements(latest_iteration.observation->'criterionResults') c
         where c->>'status'<>'satisfied') then
      raise exception 'completed submission requires a passing task loop iteration with evidence';
    end if;
  end if;
  update public.tasks set result=coalesce(result_in,'{}'),result_summary=result_summary_in,
    tools_used=coalesce(tools_used_in,'[]'),evidence=coalesce(evidence_in,'[]'),
    parameter_values=values_out,result_submitted_at=now(),status=status_in,
    verification_status=case when status_in='completed' then 'pending' else 'not_started' end,
    outcome=result_summary_in,heartbeat_at=now(),updated_at=now(),
    completed_at=case when status_in='completed' then now() else null end,
    claim_expires_at=null,claim_token=null
  where id=task_id_in returning * into task_out;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'result_submitted',agent_id_in,result_summary_in,
    jsonb_build_object('status',status_in,'result',coalesce(result_in,'{}'),
      'parameter_values',values_out,'tools_used',coalesce(tools_used_in,'[]'),
      'evidence',coalesce(evidence_in,'[]')));
  return task_out;
end;
$$;

comment on column public.goals.goal_key is 'Stable readable slug derived from the goal title; UUID is an internal relational key.';
comment on column public.goals.goal_loop_definition is 'Goal-level Loop Generator contract; tasks are direct children of the goal.';
comment on column public.tasks.parameters is 'Task-specific parameter configuration.';
comment on column public.tasks.parameter_contract is 'Required task parameter keys, JSON types and optional enum constraints.';
comment on column public.tasks.parameter_values is 'Worker-provided parameter values validated before completion.';
