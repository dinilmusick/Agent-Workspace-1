-- Require an inline predicate definition when a bounded-v2 task is created.
create or replace function public.prepare_bounded_task_predicates()
returns trigger language plpgsql set search_path=public as $$
declare
  cps jsonb; cp jsonb; pred jsonb; p public.completion_predicates;
  existing public.completion_predicates; i int;
  key text; kind text; descr text; schema jsonb; def jsonb;
  requested_version int;
begin
  if new.execution_model <> 'bounded-v2' then return new; end if;
  cps:=new.checkpoints;
  for i in 0..jsonb_array_length(cps)-1 loop
    cp:=cps->i;
    if nullif(cp->>'predicate_id','') is null then
      pred:=cp->'predicate';
      if jsonb_typeof(pred)<>'object' then
        raise exception 'bounded-v2 checkpoint % requires a predicate definition',i;
      end if;
      key:=nullif(btrim(pred->>'key'),'');
      kind:=coalesce(pred->>'kind','script');
      descr:=nullif(btrim(pred->>'description'),'');
      schema:=coalesce(pred->'input_schema','{"type":"object"}'::jsonb);
      def:=coalesce(pred->'definition','{}'::jsonb);
      requested_version:=nullif(pred->>'version','')::integer;
      if key is null or descr is null then raise exception 'checkpoint % predicate requires key and description',i; end if;
      if kind not in ('builtin','script') then raise exception 'checkpoint % predicate kind must be builtin or script',i; end if;
      if requested_version is not null then
        select * into existing from public.completion_predicates where predicate_key=key and version=requested_version;
        if not found then
          select * into p from public.register_completion_predicate(key,kind,descr,schema,def,'task-definition',requested_version);
        else
          if existing.kind<>kind or existing.description<>descr or existing.input_schema<>schema or existing.definition<>def then
            raise exception 'predicate %.% is immutable and its definition does not match',key,requested_version;
          end if;
          p:=existing;
        end if;
      else
        select * into existing from public.completion_predicates where predicate_key=key order by version desc limit 1;
        if found and existing.kind=kind and existing.description=descr and existing.input_schema=schema and existing.definition=def then
          p:=existing;
        else
          select * into p from public.register_completion_predicate(key,kind,descr,schema,def,'task-definition',null);
        end if;
      end if;
      cp:=jsonb_set(cp,'{predicate_id}',to_jsonb(p.id),true);
      cp:=jsonb_set(cp,'{predicate_key}',to_jsonb(p.predicate_key),true);
      cp:=jsonb_set(cp,'{predicate_version}',to_jsonb(p.version),true);
      cp:=jsonb_set(cp,'{predicate_hash}',to_jsonb(p.immutable_hash),true);
      cp:=cp-'predicate';
      cps:=jsonb_set(cps,array[i::text],cp,false);
    end if;
  end loop;
  new.checkpoints:=cps;
  return new;
end; $$;

drop trigger if exists aaa_tasks_prepare_bounded_predicates on public.tasks;
create trigger aaa_tasks_prepare_bounded_predicates
before insert or update of execution_model,completion_parameters,checkpoints
on public.tasks for each row execute function public.prepare_bounded_task_predicates();
