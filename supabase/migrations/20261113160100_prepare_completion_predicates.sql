-- Supply predicate bindings from the task definition before bounded-model validation.
create or replace function public.prepare_bounded_checkpoint_predicates()
returns trigger language plpgsql set search_path=public as $$
declare i integer := 0; c jsonb; p jsonb; pred jsonb;
begin
  if new.execution_model <> 'bounded-v2' then return new; end if;
  for c in select value from jsonb_array_elements(new.checkpoints) loop
    p := coalesce(new.completion_parameters->i, '{}'::jsonb);
    pred := coalesce(
      p->'predicate',
      new.task_definition->'completion_predicates'->i,
      '{}'::jsonb
    );
    if nullif(btrim(c->>'predicate_key'),'') is null
       and nullif(btrim(pred->>'key'),'') is not null then
      c := c || jsonb_build_object(
        'predicate_key', pred->>'key',
        'predicate_version', coalesce((pred->>'version')::integer,1)
      );
      new.checkpoints := jsonb_set(new.checkpoints,array[i::text],c,false);
    end if;
    i := i + 1;
  end loop;
  return new;
end; $$;

drop trigger if exists tasks_prepare_bounded_checkpoint_predicates on public.tasks;
create trigger tasks_prepare_bounded_checkpoint_predicates
before insert or update of execution_model,completion_parameters,checkpoints,task_definition
on public.tasks for each row execute function public.prepare_bounded_checkpoint_predicates();

-- Predicate definitions cannot be mutated after publication.
create or replace function public.prevent_completion_predicate_mutation()
returns trigger language plpgsql set search_path=public as $$
begin
  if old.immutable then raise exception 'completion predicate definitions are immutable; create a new version'; end if;
  return new;
end; $$;

drop trigger if exists completion_predicates_immutable on public.completion_predicates;
create trigger completion_predicates_immutable
before update on public.completion_predicates
for each row execute function public.prevent_completion_predicate_mutation();

-- Register the minimal deterministic builtin used by infrastructure-generated
-- checkpoints. Real work should supply a stronger predicate in the task definition.
insert into public.completion_predicates(
  predicate_key,version,predicate_type,definition,input_schema,expected_result
) values (
  'builtin.evidence_present',1,'builtin',
  '{"operation":"evidence_present"}'::jsonb,
  '{"type":"object","required":["evidence"]}'::jsonb,
  'true'::jsonb
) on conflict (predicate_key,version) do nothing;
