-- Completion Predicate Engine: immutable, machine-verifiable checkpoint completion.
-- Agents perform work and submit evidence; only a recorded predicate execution
-- can advance a bounded-v2 checkpoint.

create table if not exists public.completion_predicates (
  id uuid primary key default gen_random_uuid(),
  predicate_key text not null,
  version integer not null check (version > 0),
  kind text not null check (kind in ('builtin','script')),
  description text not null,
  input_schema jsonb not null default '{"type":"object"}'::jsonb,
  definition jsonb not null,
  immutable_hash text not null,
  created_by_agent_id text not null,
  created_at timestamptz not null default now(),
  unique(predicate_key, version),
  unique(predicate_key, immutable_hash)
);

create table if not exists public.completion_executions (
  id uuid primary key default gen_random_uuid(),
  predicate_id uuid not null references public.completion_predicates(id),
  task_id uuid not null references public.tasks(id) on delete cascade,
  checkpoint_index smallint not null check (checkpoint_index between 0 and 3),
  predicate_version integer not null,
  inputs jsonb not null default '{}'::jsonb,
  result jsonb,
  passed boolean not null,
  evidence jsonb not null default '[]'::jsonb,
  executor_agent_id text not null,
  execution_ref text,
  created_at timestamptz not null default now()
);

create index if not exists completion_executions_task_idx on public.completion_executions(task_id,checkpoint_index,created_at desc);
create index if not exists completion_predicates_key_idx on public.completion_predicates(predicate_key,version desc);

alter table public.completion_predicates enable row level security;
alter table public.completion_executions enable row level security;
revoke all on public.completion_predicates from anon, authenticated;
revoke all on public.completion_executions from anon, authenticated;

create or replace function public.lock_completion_predicate()
returns trigger language plpgsql set search_path=public as $$
begin
  if tg_op <> 'INSERT' then raise exception 'completion predicates are immutable; create a new version'; end if;
  new.immutable_hash := encode(extensions.digest(
    (new.predicate_key || ':' || new.version::text || ':' || new.kind || ':' ||
     new.description || ':' || new.input_schema::text || ':' || new.definition::text)::bytea,'sha256'),'hex');
  return new;
end; $$;

drop trigger if exists completion_predicates_immutable on public.completion_predicates;
create trigger completion_predicates_immutable before insert or update or delete on public.completion_predicates
for each row execute function public.lock_completion_predicate();

create or replace function public.validate_completion_predicate_definition()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.kind='builtin' and nullif(btrim(new.definition->>'name'),'') is null then
    raise exception 'builtin predicate requires definition.name';
  end if;
  if new.kind='script' and (nullif(btrim(new.definition->>'script_id'),'') is null or
      nullif(btrim(new.definition->>'entrypoint'),'') is null) then
    raise exception 'script predicate requires definition.script_id and definition.entrypoint';
  end if;
  return new;
end; $$;

drop trigger if exists completion_predicates_definition_guard on public.completion_predicates;
create trigger completion_predicates_definition_guard before insert on public.completion_predicates
for each row execute function public.validate_completion_predicate_definition();

create or replace function public.register_completion_predicate(
  predicate_key_in text, kind_in text, description_in text, input_schema_in jsonb,
  definition_in jsonb, created_by_agent_id_in text, version_in integer default null)
returns public.completion_predicates language plpgsql set search_path=public as $$
declare out_row public.completion_predicates; next_version integer;
begin
  if nullif(btrim(predicate_key_in),'') is null then raise exception 'predicate_key is required'; end if;
  if nullif(btrim(created_by_agent_id_in),'') is null then raise exception 'creator agent is required'; end if;
  select coalesce(max(version),0)+1 into next_version from public.completion_predicates where predicate_key=predicate_key_in;
  insert into public.completion_predicates(predicate_key,version,kind,description,input_schema,definition,immutable_hash,created_by_agent_id)
  values(predicate_key_in,coalesce(version_in,next_version),kind_in,description_in,coalesce(input_schema_in,'{"type":"object"}'::jsonb),definition_in,'',created_by_agent_id_in)
  returning * into out_row;
  return out_row;
end; $$;

create or replace function public.task_ledger_attach_completion_predicate(
  task_id_in uuid, checkpoint_index_in smallint, predicate_key_in text, predicate_version_in integer)
returns jsonb language plpgsql set search_path=public as $$
declare p public.completion_predicates; t public.tasks; cps jsonb; cp jsonb;
begin
  select * into t from public.tasks where id=task_id_in for update;
  if not found then raise exception 'task not found'; end if;
  if t.execution_model <> 'bounded-v2' then raise exception 'completion predicates require bounded-v2 tasks'; end if;
  if checkpoint_index_in < 0 or checkpoint_index_in >= jsonb_array_length(t.checkpoints) then raise exception 'checkpoint index out of range'; end if;
  select * into p from public.completion_predicates where predicate_key=predicate_key_in and version=predicate_version_in;
  if not found then raise exception 'completion predicate version not found'; end if;
  cps:=t.checkpoints; cp:=cps->checkpoint_index_in;
  cp:=jsonb_set(cp,'{predicate_id}',to_jsonb(p.id),true);
  cp:=jsonb_set(cp,'{predicate_key}',to_jsonb(p.predicate_key),true);
  cp:=jsonb_set(cp,'{predicate_version}',to_jsonb(p.version),true);
  cp:=jsonb_set(cp,'{predicate_hash}',to_jsonb(p.immutable_hash),true);
  cps:=jsonb_set(cps,array[checkpoint_index_in::text],cp,false);
  update public.tasks set checkpoints=cps,updated_at=now() where id=task_id_in;
  return cp;
end; $$;

create or replace function public.task_ledger_record_predicate_execution(
  task_id_in uuid, checkpoint_index_in smallint, predicate_key_in text, predicate_version_in integer,
  inputs_in jsonb, result_in jsonb, passed_in boolean, evidence_in jsonb,
  executor_agent_id_in text, execution_ref_in text default null)
returns jsonb language plpgsql set search_path=public as $$
declare t public.tasks; p public.completion_predicates; cp jsonb; cps jsonb; exec_id uuid;
begin
  select * into t from public.tasks where id=task_id_in for update;
  if not found then raise exception 'task not found'; end if;
  if t.execution_model <> 'bounded-v2' then raise exception 'predicate execution requires bounded-v2 tasks'; end if;
  if checkpoint_index_in < 0 or checkpoint_index_in >= jsonb_array_length(t.checkpoints) then raise exception 'checkpoint index out of range'; end if;
  select * into p from public.completion_predicates where predicate_key=predicate_key_in and version=predicate_version_in;
  if not found then raise exception 'completion predicate version not found'; end if;
  cp:=t.checkpoints->checkpoint_index_in;
  if (cp->>'predicate_id')::uuid <> p.id or cp->>'predicate_hash' <> p.immutable_hash
    then raise exception 'execution predicate does not match checkpoint predicate version/hash'; end if;
  if passed_in is null then raise exception 'predicate execution must provide passed=true/false'; end if;
  insert into public.completion_executions(predicate_id,task_id,checkpoint_index,predicate_version,inputs,result,passed,evidence,executor_agent_id,execution_ref)
  values(p.id,task_id_in,checkpoint_index_in,p.version,coalesce(inputs_in,'{}'::jsonb),result_in,passed_in,coalesce(evidence_in,'[]'::jsonb),executor_agent_id_in,execution_ref_in)
  returning id into exec_id;
  cps:=t.checkpoints;
  cp:=jsonb_set(cp,'{status}',to_jsonb(case when passed_in then 'succeeded' else 'failed' end),true);
  cp:=jsonb_set(cp,'{result}',coalesce(result_in,'null'::jsonb),true);
  cp:=jsonb_set(cp,'{context}',coalesce(inputs_in,'{}'::jsonb),true);
  cp:=jsonb_set(cp,'{evidence}',coalesce(evidence_in,'[]'::jsonb),true);
  cp:=jsonb_set(cp,'{execution_id}',to_jsonb(exec_id),true);
  cps:=jsonb_set(cps,array[checkpoint_index_in::text],cp,false);
  update public.tasks set checkpoints=cps,current_checkpoint_index=least(checkpoint_index_in+case when passed_in then 1 else 0 end,4),updated_at=now() where id=task_id_in;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'completion_predicate_evaluated',executor_agent_id_in,
    case when passed_in then 'Completion predicate succeeded' else 'Completion predicate failed' end,
    jsonb_build_object('checkpoint_index',checkpoint_index_in,'predicate_key',p.predicate_key,'predicate_version',p.version,'execution_id',exec_id,'passed',passed_in));
  return jsonb_build_object('execution_id',exec_id,'passed',passed_in,'checkpoint',cp);
end; $$;

create or replace function public.validate_bounded_task_model()
returns trigger language plpgsql set search_path=public as $$
declare p_ids text[]; cp_ids text[]; cp jsonb; pred public.completion_predicates;
begin
  if new.execution_model <> 'bounded-v2' then return new; end if;
  if jsonb_typeof(new.completion_parameters)<>'array' or jsonb_array_length(new.completion_parameters) not between 1 and 4 then raise exception 'bounded-v2 task requires 1-4 completion parameters'; end if;
  if jsonb_typeof(new.checkpoints)<>'array' or jsonb_array_length(new.checkpoints)<>jsonb_array_length(new.completion_parameters) then raise exception 'bounded-v2 task requires exactly one checkpoint per completion parameter'; end if;
  if exists(select 1 from jsonb_array_elements(new.completion_parameters) cp_param where jsonb_typeof(cp_param)<>'object' or nullif(btrim(cp_param->>'id'),'') is null or nullif(btrim(cp_param->>'description'),'') is null) then raise exception 'each completion parameter requires id and description'; end if;
  p_ids:=array(select cp_param->>'id' from jsonb_array_elements(new.completion_parameters) cp_param);
  if cardinality(p_ids)<>cardinality(array(select distinct unnest(p_ids))) then raise exception 'completion parameter ids must be unique'; end if;
  if exists(select 1 from jsonb_array_elements(new.checkpoints) checkpoint_item where jsonb_typeof(checkpoint_item)<>'object' or nullif(btrim(checkpoint_item->>'parameter_id'),'') is null or nullif(btrim(checkpoint_item->>'objective'),'') is null or coalesce(checkpoint_item->>'status','') not in ('pending','running','succeeded','failed','blocked')) then raise exception 'each checkpoint requires parameter_id, objective and valid status'; end if;
  cp_ids:=array(select checkpoint_item->>'parameter_id' from jsonb_array_elements(new.checkpoints) checkpoint_item);
  if cardinality(cp_ids)<>cardinality(array(select distinct unnest(cp_ids))) then raise exception 'checkpoint parameter_id values must be unique'; end if;
  if exists(select 1 from unnest(cp_ids) id where not (id=any(p_ids))) then raise exception 'every checkpoint must correspond to a completion parameter'; end if;
  for cp in select value from jsonb_array_elements(new.checkpoints) loop
    if nullif(cp->>'predicate_id','') is null or nullif(cp->>'predicate_version','') is null then raise exception 'every bounded-v2 checkpoint requires an immutable completion predicate'; end if;
    select * into pred from public.completion_predicates where id=(cp->>'predicate_id')::uuid;
    if not found or pred.version<>(cp->>'predicate_version')::integer or pred.immutable_hash<>cp->>'predicate_hash' then raise exception 'checkpoint completion predicate does not match registered immutable version'; end if;
  end loop;
  return new;
end; $$;

insert into public.completion_predicates(predicate_key,version,kind,description,input_schema,definition,immutable_hash,created_by_agent_id)
select 'legacy.checkpoint.success',1,'builtin','Legacy compatibility predicate: checkpoint success was already persisted.','{"type":"object"}'::jsonb,'{"name":"legacy_checkpoint_success","evaluation":"checkpoint.status == succeeded"}'::jsonb,'','system-migration'
where not exists(select 1 from public.completion_predicates where predicate_key='legacy.checkpoint.success' and version=1);

do $$
declare pid uuid; phash text; t public.tasks; cps jsonb; i int; cp jsonb;
begin
  select id,immutable_hash into pid,phash from public.completion_predicates where predicate_key='legacy.checkpoint.success' and version=1;
  for t in select * from public.tasks where execution_model='bounded-v2' loop
    cps:=t.checkpoints;
    for i in 0..jsonb_array_length(cps)-1 loop
      cp:=cps->i;
      if nullif(cp->>'predicate_id','') is null then
        cp:=jsonb_set(cp,'{predicate_id}',to_jsonb(pid),true);
        cp:=jsonb_set(cp,'{predicate_key}','"legacy.checkpoint.success"'::jsonb,true);
        cp:=jsonb_set(cp,'{predicate_version}','1'::jsonb,true);
        cp:=jsonb_set(cp,'{predicate_hash}',to_jsonb(phash),true);
        cps:=jsonb_set(cps,array[i::text],cp,false);
      end if;
    end loop;
    update public.tasks set checkpoints=cps,updated_at=now() where id=t.id;
  end loop;
end $$;

insert into public.completion_executions(predicate_id,task_id,checkpoint_index,predicate_version,inputs,result,passed,evidence,executor_agent_id,execution_ref)
select p.id,t.id,i-1,p.version,'{}'::jsonb,c->'result',c->>'status'='succeeded',coalesce(c->'evidence','[]'::jsonb),'system-migration','legacy://bounded-v2-upgrade'
from public.tasks t cross join lateral jsonb_array_elements(t.checkpoints) with ordinality cp(c,i)
join public.completion_predicates p on p.predicate_key='legacy.checkpoint.success' and p.version=1
where t.execution_model='bounded-v2'
and not exists(select 1 from public.completion_executions e where e.task_id=t.id and e.checkpoint_index=i-1);

create or replace function public.enforce_bounded_task_completion()
returns trigger language plpgsql set search_path=public as $$
begin
  if new.execution_model='bounded-v2' and new.status='completed' and old.status is distinct from 'completed' and (jsonb_array_length(new.checkpoints)=0 or exists(select 1 from jsonb_array_elements(new.checkpoints) checkpoint_item where checkpoint_item->>'status'<>'succeeded')) then raise exception 'bounded-v2 task cannot complete until every checkpoint predicate succeeds'; end if;
  if new.execution_model='bounded-v2' and new.status='completed' and exists(select 1 from jsonb_array_elements(new.checkpoints) checkpoint_item where nullif(checkpoint_item->>'execution_id','') is null) then raise exception 'bounded-v2 task cannot complete without recorded predicate executions'; end if;
  return new;
end; $$;
