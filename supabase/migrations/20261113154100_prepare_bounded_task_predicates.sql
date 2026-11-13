-- Bind inline predicate definitions to bounded-v2 checkpoints and prevent
-- checkpoint success from being written without a successful predicate execution.

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
      if jsonb_typeof(pred)<>'object' then raise exception 'bounded-v2 checkpoint % requires a predicate definition',i; end if;
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

create or replace function public.enforce_bounded_checkpoint_execution()
returns trigger language plpgsql set search_path=public as $$
declare i int; old_cp jsonb; new_cp jsonb; exec_id uuid; exec_passed boolean;
begin
  if new.execution_model <> 'bounded-v2' then return new; end if;
  for i in 0..jsonb_array_length(new.checkpoints)-1 loop
    old_cp:=old.checkpoints->i; new_cp:=new.checkpoints->i;
    if old_cp is distinct from new_cp and (new_cp->>'status'='succeeded' or old_cp->>'status'='succeeded') then
      exec_id:=nullif(new_cp->>'execution_id','')::uuid;
      if exec_id is null then raise exception 'bounded-v2 checkpoint % cannot be marked succeeded without predicate execution',i; end if;
      select passed into exec_passed from public.completion_executions where id=exec_id and task_id=new.id and checkpoint_index=i;
      if not found or exec_passed is not true then raise exception 'bounded-v2 checkpoint % requires a successful recorded predicate execution',i; end if;
    end if;
  end loop;
  return new;
end; $$;

drop trigger if exists aab_tasks_enforce_bounded_checkpoint_execution on public.tasks;
create trigger aab_tasks_enforce_bounded_checkpoint_execution
before update of checkpoints on public.tasks
for each row execute function public.enforce_bounded_checkpoint_execution();

alter table public.task_events drop constraint if exists task_events_event_type_check;
alter table public.task_events add constraint task_events_event_type_check check (event_type = any(array[
'registered','started','heartbeat','progress','tagged','blocked','unblocked','completed','failed','cancelled','abandoned','reopened','note','claimed','released','result_submitted','verified','verification_rejected','iteration_recorded','loop_iteration_recorded','dependency_added','tree_created','lease_recovered','completion_predicate_evaluated'
]));

revoke execute on function public.register_completion_predicate(text,text,text,jsonb,jsonb,text,integer) from public,anon,authenticated;
revoke execute on function public.task_ledger_attach_completion_predicate(uuid,smallint,text,integer) from public,anon,authenticated;
revoke execute on function public.task_ledger_record_predicate_execution(uuid,smallint,text,integer,jsonb,jsonb,boolean,jsonb,text,text) from public,anon,authenticated;
grant execute on function public.register_completion_predicate(text,text,text,jsonb,jsonb,text,integer) to service_role;
grant execute on function public.task_ledger_attach_completion_predicate(uuid,smallint,text,integer) to service_role;
grant execute on function public.task_ledger_record_predicate_execution(uuid,smallint,text,integer,jsonb,jsonb,boolean,jsonb,text,text) to service_role;
