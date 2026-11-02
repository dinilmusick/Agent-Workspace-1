-- Run with a privileged SQL connection against a disposable database.
-- Creates and deletes its own task tree; raises on any failed invariant.
do $test$
declare
  root_id uuid;
  claimed public.tasks;
  summary jsonb;
begin
  root_id := public.task_ledger_create_tree(
    'integration-test-orchestrator','Integration Test Orchestrator',
    jsonb_build_object('name','integration-test-root','tags',jsonb_build_array('integration-test'),
      'subtasks',jsonb_build_array(jsonb_build_object('name','integration-test-child',
        'tags',jsonb_build_array('integration-test'),
        'required_capabilities',jsonb_build_array('test-capability')))),
    null,'integration-test-session','orchestrator');

  select * into claimed from public.task_ledger_claim_next(
    'integration-test-orchestrator','Integration Test Orchestrator','orchestrator',
    array['test-capability']::text[],900);
  if claimed.id is null or claimed.id <> root_id then raise exception 'Root task was not claimed first'; end if;

  perform public.task_ledger_heartbeat_claim(claimed.id,'integration-test-orchestrator',
    claimed.claim_token,'integration test heartbeat',900);
  perform public.task_ledger_record_iteration(claimed.id,'integration-test-orchestrator',
    claimed.claim_token,1,'{"phase":"root"}','{"ok":true}','{"observation":"root"}',
    'root pass','[]','[{"type":"test","name":"root"}]','completed');
  perform public.task_ledger_submit_result(claimed.id,'integration-test-orchestrator',
    claimed.claim_token,'{"ok":true}','root result','[]','[{"type":"test","name":"root"}]','completed');

  select * into claimed from public.task_ledger_claim_next(
    'integration-test-worker','Integration Test Worker','worker',array['test-capability']::text[],900);
  if claimed.id is null or claimed.task_name <> 'integration-test-child' then
    raise exception 'Worker did not claim the capability-matched child';
  end if;
  perform public.task_ledger_record_iteration(claimed.id,'integration-test-worker',
    claimed.claim_token,1,'{"phase":"child"}','{"ok":true}','{"observation":"child"}',
    'child pass','[]','[{"type":"test","name":"child"}]','completed');
  perform public.task_ledger_submit_result(claimed.id,'integration-test-worker',
    claimed.claim_token,'{"ok":true}','child result','[]','[{"type":"test","name":"child"}]','completed');


  select * into claimed from public.task_ledger_pending_verification();
  if claimed.id is null or claimed.task_name <> 'integration-test-child' then
    raise exception 'Verifier queue did not return the leaf child result first';
  end if;
  perform public.task_ledger_verify_result(claimed.id,'integration-test-orchestrator',true,'{"verified":true}');

  summary := public.task_ledger_children_summary(root_id);
  if coalesce((summary->>'all_verified')::boolean,false) is not true then
    raise exception 'Child summary failed verification: %',summary;
  end if;
  perform public.task_ledger_finalize_parent(root_id,'integration-test-orchestrator',
    'Integration test passed',jsonb_build_object('verified',true,'children',summary));
  if not exists(select 1 from public.tasks where id=root_id and status='completed' and verification_status='verified') then
    raise exception 'Parent did not reach verified completion';
  end if;
  select * into claimed from public.task_ledger_pending_verification();
  if claimed.id is not null then raise exception 'Pending verifier queue should be empty after parent finalization'; end if;

  delete from public.task_events where task_id in (select id from public.tasks where id=root_id or parent_task_id=root_id);
  delete from public.task_iterations where task_id in (select id from public.tasks where id=root_id or parent_task_id=root_id);
  delete from public.task_dependencies where task_id in (select id from public.tasks where id=root_id or parent_task_id=root_id)
    or depends_on_task_id in (select id from public.tasks where id=root_id or parent_task_id=root_id);
  delete from public.tasks where id=root_id or parent_task_id=root_id;
end;
$test$;
