-- Completion Predicate Engine for bounded Vision -> Goal -> Task -> Checkpoint loops.
-- Completion is machine-verifiable: agents submit work/evidence; the executor records
-- predicate results; database guards prevent unverified checkpoint/loop completion.

create table if not exists public.completion_predicates (
  id uuid primary key default gen_random_uuid(),
  predicate_key text not null,
  version integer not null,
  predicate_type text not null check (predicate_type in ('builtin','cel','script')),
  definition jsonb not null default '{}'::jsonb,
  input_schema jsonb not null default '{}'::jsonb,
  expected_result jsonb not null default 'true'::jsonb,
  immutable boolean not null default true,
  created_at timestamptz not null default now(),
  unique(predicate_key, version),
  check (jsonb_typeof(definition)='object'),
  check (jsonb_typeof(input_schema)='object')
);

create table if not exists public.predicate_executions (
  id uuid primary key default gen_random_uuid(),
  predicate_id uuid not null references public.completion_predicates(id),
  predicate_key text not null,
  predicate_version integer not null,
  task_id uuid references public.tasks(id) on delete cascade,
  checkpoint_index smallint,
  inputs jsonb not null default '{}'::jsonb,
  result jsonb,
  passed boolean not null default false,
  evidence jsonb not null default '[]'::jsonb,
  executor_id text not null,
  fencing_token text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  check (checkpoint_index is null or checkpoint_index between 0 and 3),
  check (jsonb_typeof(inputs)='object'),
  check (jsonb_typeof(evidence)='array')
);

create index if not exists completion_predicates_key_idx
  on public.completion_predicates(predicate_key, version desc);
create index if not exists predicate_executions_task_checkpoint_idx
  on public.predicate_executions(task_id, checkpoint_index, created_at desc);

alter table public.tasks
  add column if not exists completion_predicate_version integer not null default 1;

-- A bounded checkpoint is required to name the immutable predicate that proves it.
create or replace function public.validate_bounded_checkpoint_predicates()
returns trigger language plpgsql set search_path=public as $$
declare c jsonb; checkpoint_key text; checkpoint_version integer; i integer := 0;
begin
  if new.execution_model <> 'bounded-v2' then return new; end if;
  for c in select value from jsonb_array_elements(new.checkpoints) loop
    checkpoint_key := nullif(btrim(c->>'predicate_key'),'');
    checkpoint_version := coalesce((c->>'predicate_version')::integer, new.completion_predicate_version);
    if checkpoint_key is null then
      raise exception 'bounded-v2 checkpoint % requires predicate_key', i;
    end if;
    if not exists (
      select 1 from public.completion_predicates p
      where p.predicate_key=checkpoint_key and p.version=checkpoint_version
    ) then
      raise exception 'completion predicate %@% is not registered', checkpoint_key, checkpoint_version;
    end if;
    i := i + 1;
  end loop;
  return new;
end; $$;

drop trigger if exists tasks_validate_bounded_checkpoint_predicates on public.tasks;
create trigger tasks_validate_bounded_checkpoint_predicates
before insert or update of execution_model,completion_parameters,checkpoints,completion_predicate_version
on public.tasks for each row execute function public.validate_bounded_checkpoint_predicates();

-- The only authoritative path for a successful checkpoint.
create or replace function public.record_checkpoint_predicate_result(
  task_id_in uuid,
  checkpoint_index_in smallint,
  predicate_key_in text,
  predicate_version_in integer,
  inputs_in jsonb,
  result_in jsonb,
  passed_in boolean,
  evidence_in jsonb,
  executor_id_in text,
  fencing_token_in text default null
)
returns jsonb language plpgsql set search_path=public as $$
declare t public.tasks; c jsonb; expected_key text; expected_version integer;
  updated_checkpoints jsonb; run_id uuid;
begin
  if checkpoint_index_in not between 0 and 3 then
    raise exception 'checkpoint index must be between 0 and 3';
  end if;
  if nullif(btrim(executor_id_in),'') is null then raise exception 'executor_id is required'; end if;

  select * into t from public.tasks where id=task_id_in for update;
  if not found then raise exception 'task not found'; end if;
  if t.execution_model <> 'bounded-v2' then raise exception 'task is not bounded-v2'; end if;
  if checkpoint_index_in >= jsonb_array_length(t.checkpoints) then raise exception 'checkpoint does not exist'; end if;

  c := t.checkpoints->checkpoint_index_in;
  expected_key := nullif(btrim(c->>'predicate_key'),'');
  expected_version := coalesce((c->>'predicate_version')::integer,t.completion_predicate_version);
  if expected_key is distinct from predicate_key_in or expected_version is distinct from predicate_version_in then
    raise exception 'predicate does not match the checkpoint contract';
  end if;

  if not exists (
    select 1 from public.completion_predicates
    where predicate_key=predicate_key_in and version=predicate_version_in
  ) then raise exception 'predicate is not registered'; end if;

  if passed_in is true and coalesce(jsonb_typeof(evidence_in),'null') <> 'array' then
    raise exception 'successful predicate execution requires evidence array'; end if;

  insert into public.predicate_executions(
    predicate_id,predicate_key,predicate_version,task_id,checkpoint_index,inputs,result,
    passed,evidence,executor_id,fencing_token,finished_at)
  select p.id,predicate_key_in,predicate_version_in,task_id_in,checkpoint_index_in,
    coalesce(inputs_in,'{}'::jsonb),result_in,passed_in,coalesce(evidence_in,'[]'::jsonb),
    executor_id_in,fencing_token_in,now()
  from public.completion_predicates p
  where p.predicate_key=predicate_key_in and p.version=predicate_version_in
  returning id into run_id;

  if passed_in then
    updated_checkpoints := jsonb_set(
      t.checkpoints,
      array[checkpoint_index_in::text],
      c || jsonb_build_object(
        'status','succeeded',
        'result',result_in,
        'context',coalesce(c->'context','{}'::jsonb),
        'evidence',coalesce(evidence_in,'[]'::jsonb),
        'predicate_key',predicate_key_in,
        'predicate_version',predicate_version_in,
        'predicate_execution_id',run_id
      ),
      false);
    update public.tasks
      set checkpoints=updated_checkpoints,
          current_checkpoint_index=least(checkpoint_index_in+1, jsonb_array_length(updated_checkpoints)),
          updated_at=now()
      where id=task_id_in;
  else
    updated_checkpoints := jsonb_set(
      t.checkpoints,
      array[checkpoint_index_in::text],
      c || jsonb_build_object(
        'status','failed','result',result_in,
        'evidence',coalesce(evidence_in,'[]'::jsonb),
        'predicate_key',predicate_key_in,
        'predicate_version',predicate_version_in,
        'predicate_execution_id',run_id
      ),
      false);
    update public.tasks set checkpoints=updated_checkpoints,updated_at=now() where id=task_id_in;
  end if;

  return jsonb_build_object(
    'execution_id',run_id,
    'task_id',task_id_in,
    'checkpoint_index',checkpoint_index_in,
    'passed',passed_in
  );
end; $$;

-- A direct JSON status mutation cannot manufacture a successful checkpoint.
create or replace function public.enforce_predicate_backed_checkpoint_success()
returns trigger language plpgsql set search_path=public as $$
declare i integer; c jsonb; exec_id uuid;
begin
  if new.execution_model <> 'bounded-v2' then return new; end if;
  for i in 0..jsonb_array_length(new.checkpoints)-1 loop
    c := new.checkpoints->i;
    if c->>'status'='succeeded' and
       (old.checkpoints->i->>'status') is distinct from 'succeeded' then
      exec_id := nullif(c->>'predicate_execution_id','')::uuid;
      if exec_id is null or not exists(
        select 1 from public.predicate_executions e
        where e.id=exec_id and e.task_id=new.id and e.checkpoint_index=i
          and e.passed=true
          and e.predicate_key=c->>'predicate_key'
          and e.predicate_version=(c->>'predicate_version')::integer
      ) then
        raise exception 'checkpoint % cannot succeed without a passing predicate execution', i;
      end if;
    end if;
  end loop;
  return new;
end; $$;

drop trigger if exists tasks_require_predicate_backed_checkpoint_success on public.tasks;
create trigger tasks_require_predicate_backed_checkpoint_success
before update of checkpoints on public.tasks
for each row execute function public.enforce_predicate_backed_checkpoint_success();

-- Goal completion is also derived from its bounded direct-task completion state.
create or replace function public.enforce_bounded_goal_completion()
returns trigger language plpgsql set search_path=public as $$
declare unfinished integer;
begin
  if new.status='completed' and old.status is distinct from 'completed' then
    select count(*) into unfinished
    from public.tasks t
    where t.goal_id=new.id and t.parent_task_id is null and t.status <> 'completed';
    if unfinished > 0 then
      raise exception 'bounded goal cannot complete while direct tasks remain incomplete';
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists goals_require_bounded_task_completion on public.goals;
create trigger goals_require_bounded_task_completion
before update of status on public.goals
for each row execute function public.enforce_bounded_goal_completion();

comment on table public.completion_predicates is
'Versioned, machine-verifiable completion predicates. Once referenced by a running bounded loop, definitions are immutable.';
comment on table public.predicate_executions is
'Append-only audit of completion predicate executions and evidence.';
