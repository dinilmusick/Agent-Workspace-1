-- Rollback-only regression for machine-verifiable checkpoint completion.
do $$
declare
  tid uuid; cp jsonb; rejected boolean:=false; result jsonb;
begin
  tid:=public.task_ledger_create_tree(
    'predicate-test-agent','predicate-test-agent',
    '{"name":"predicate-engine-regression","description":"temporary regression task","general_pattern":"bounded verification","actions":[{"description":"Verify predicate gating"}],"completion_parameters":[{"id":"verify","description":"Predicate must pass"}],"checkpoints":[{"parameter_id":"verify","objective":"Predicate must pass","status":"pending","predicate":{"key":"test.predicate.gating","kind":"builtin","description":"Regression predicate","input_schema":{"type":"object"},"definition":{"name":"regression"}}}]}'::jsonb);

  select checkpoints->0 into cp from public.tasks where id=tid;
  if nullif(cp->>'predicate_id','') is null then raise exception 'REGRESSION FAILED: predicate not attached'; end if;

  begin
    update public.tasks set checkpoints=jsonb_set(checkpoints,'{0,status}','"succeeded"'::jsonb,true) where id=tid;
  exception when others then
    if position('without predicate execution' in sqlerrm)>0 then rejected:=true; else raise; end if;
  end;
  if not rejected then raise exception 'REGRESSION FAILED: direct checkpoint success was accepted'; end if;

  result:=public.task_ledger_record_predicate_execution(
    tid,0::smallint,'test.predicate.gating',1,'{}'::jsonb,'{"ok":true}'::jsonb,
    true,'["test://predicate"]'::jsonb,'predicate-test-agent','test://predicate');

  if (result->>'passed')::boolean is not true then raise exception 'REGRESSION FAILED: execution did not pass'; end if;
  select checkpoints->0 into cp from public.tasks where id=tid;
  if cp->>'status' <> 'succeeded' or nullif(cp->>'execution_id','') is null then raise exception 'REGRESSION FAILED: checkpoint did not advance'; end if;

  delete from public.tasks where id=tid;
end $$;
