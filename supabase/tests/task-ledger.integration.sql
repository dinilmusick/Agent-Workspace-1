-- Run with a privileged SQL connection against a disposable database.
-- Verifies parent decomposition, leaf-only claims, result submission and independent verification.
do $test$
declare
  root_id uuid;
  claimed public.tasks;
  verifier public.tasks;
  summary jsonb;
begin
  root_id := public.task_ledger_create_tree(
    'integration-test-orchestrator','Integration Test Orchestrator',
    jsonb_build_object('name','integration-test-root','tags',jsonb_build_array('integration-test'),
      'required_capabilities',jsonb_build_array('orchestrator-only'),
      'loop',jsonb_build_object(
        'enabled',true,'objective','Coordinate child execution and finalize after verification',
        'input_contract',jsonb_build_object('type','object','required',jsonb_build_array('subtasks')),
        'output_contract',jsonb_build_object('type','object','required',jsonb_build_array('verified')),
        'transformation','Wait for child evidence, evaluate verification, then finalize the parent.',
        'observation',jsonb_build_object('required',jsonb_build_array('test_results','runtime_observations','known_gaps')),
        'evaluation',jsonb_build_object('criteria','all children independently verified'),
        'revision_policy',jsonb_build_object('on_failure','Inspect child evidence and retry','max_revisions',2),
        'initial_input',jsonb_build_object('phase','inspect'),
        'tools',jsonb_build_array('Supabase PostgreSQL','Task ledger'),
        'iteration_policy',jsonb_build_object('mode','persistent','heartbeat_required',true,'continue_on_partial_success',true,'record_observation_each_iteration',true),
        'stop_conditions',jsonb_build_array('all children verified'),'max_iterations',3
      ),
      'subtasks',jsonb_build_array(jsonb_build_object('name','integration-test-child',
        'tags',jsonb_build_array('integration-test'),
        'required_capabilities',jsonb_build_array('test-capability'),
        'loop',jsonb_build_object(
          'enabled',true,'objective','Execute and verify the integration-test child task',
          'input_contract',jsonb_build_object('type','object','required',jsonb_build_array('task_name')),
          'output_contract',jsonb_build_object('type','object','required',jsonb_build_array('result')),
          'transformation','Run the child test and capture reproducible evidence.',
          'observation',jsonb_build_object('required',jsonb_build_array('test_results','runtime_observations','known_gaps')),
          'evaluation',jsonb_build_object('criteria','child test passes'),
          'revision_policy',jsonb_build_object('on_failure','Diagnose and retry child test','max_revisions',2),
          'initial_input',jsonb_build_object('phase','inspect'),
          'tools',jsonb_build_array('Supabase PostgreSQL','SQL integration test'),
          'iteration_policy',jsonb_build_object('mode','persistent','heartbeat_required',true,'continue_on_partial_success',true,'record_observation_each_iteration',true),
          'stop_conditions',jsonb_build_array('pass'),'max_iterations',3
        )
      ))),
    null,'integration-test-session','orchestrator');

  select * into claimed from public.task_ledger_claim_next(
    'integration-test-worker','Integration Test Worker','worker',array['test-capability']::text[],900);
  if claimed.id is null or claimed.task_name<>'integration-test-child' then
    raise exception 'Worker did not claim the eligible leaf task';
  end if;
  if claimed.parent_task_id<>root_id then raise exception 'Worker claimed a task outside the expected parent'; end if;

  perform public.task_ledger_record_iteration(claimed.id,'integration-test-worker',claimed.claim_token,
    1,'{"phase":"child"}','{"ok":true}','{"observation":"child"}','child pass','[]',
    '[{"type":"test","name":"child"}]','completed');
  perform public.task_ledger_submit_result(claimed.id,'integration-test-worker',claimed.claim_token,
    '{"ok":true}','child result','[]','[{"type":"test","name":"child"}]','completed');

  select * into verifier from public.task_ledger_claim_verification('integration-test-orchestrator',900);
  if verifier.id is null or verifier.id<>claimed.id then
    raise exception 'Independent verifier did not claim the submitted leaf result';
  end if;
  perform public.task_ledger_verify_result_claimed(verifier.id,'integration-test-orchestrator',
    verifier.verification_claim_token,true,'{"verified":true}');

  summary := public.task_ledger_children_summary(root_id);
  if coalesce((summary->>'all_verified')::boolean,false) is not true then
    raise exception 'Child summary failed verification: %',summary;
  end if;
  perform public.task_ledger_finalize_parent(root_id,'integration-test-orchestrator',
    'Integration test passed',jsonb_build_object('verified',true,'children',summary));
  if not exists(select 1 from public.tasks where id=root_id and status='completed' and verification_status='verified') then
    raise exception 'Parent did not reach verified completion';
  end if;

  delete from public.task_events where task_id in (select id from public.tasks where id=root_id or parent_task_id=root_id);
  delete from public.task_iterations where task_id in (select id from public.tasks where id=root_id or parent_task_id=root_id);
  delete from public.task_dependencies where task_id in (select id from public.tasks where id=root_id or parent_task_id=root_id)
    or depends_on_task_id in (select id from public.tasks where id=root_id or parent_task_id=root_id);
  delete from public.tasks where id=root_id or parent_task_id=root_id;
end;
$test$;
