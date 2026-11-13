-- Ensure infrastructure-generated bounded tasks remain constructible while still
-- requiring a machine predicate. Explicit task predicates override this fallback.
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
      jsonb_build_object('key','builtin.evidence_present','version',1)
    );
    if nullif(btrim(c->>'predicate_key'),'') is null then
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
