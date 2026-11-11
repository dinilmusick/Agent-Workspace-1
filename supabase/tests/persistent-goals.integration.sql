-- Rollback-only integration test for resumable goal and ChatGPT worker flow.
-- Run with a privileged SQL connection against a disposable database.
begin;
do $test$
declare
  goal_name text := 'Goal Smoke ' || replace(gen_random_uuid()::text,'-','');
  created jsonb; goal_id_value uuid; root_id uuid;
  claimed public.tasks; second_claim public.tasks; verifier public.tasks;
  final_goal public.goals; resumed jsonb;
begin
  created := public.goal_ledger_create_with_tasks(
    goal_name,'Rollback-only end-to-end goal test',
    jsonb_build_object('repo','Agent-Workspace-1','purpose','validate resumable goal flow'),
    'Execute only persisted task contract.',
    jsonb_build_array('One leaf task is independently verified'),
    'smoke-orchestrator',
    jsonb_build_object(
      'name','Smoke parent','description','Decomposition-only parent',
      'actions',jsonb_build_array('Inspect child task outcomes','Confirm independent verification evidence','Finalize only after all child criteria pass'),
      'general_pattern',jsonb_build_object('objective','Coordinate and verify child tasks','approach','Evaluate child results and evidence'),
      'acceptance_criteria',jsonb_build_array('All child tasks verified'),
      'verification',jsonb_build_object('required',true),
      'loop',jsonb_build_object('enabled',true,'objective','Parent complete',
        'input_contract',jsonb_build_object('type','object','required',jsonb_build_array('task_tree')),
        'output_contract',jsonb_build_object('type','object','required',jsonb_build_array('verified')),
        'transformation','Inspect child task results and finalize the parent only after independent verification.',
        'observation',jsonb_build_object('required',jsonb_build_array('test_results','runtime_observations','known_gaps')),
        'cycle',jsonb_build_array('plan','check'),'evaluation',jsonb_build_object('criteria','children verified'),
        'revision_policy',jsonb_build_object('on_failure','Inspect incomplete child evidence','max_revisions',2),
        'initial_input',jsonb_build_object('phase','inspect','task_tree','Smoke leaf'),
        'tools',jsonb_build_array('Supabase PostgreSQL','Task ledger'),
        'iteration_policy',jsonb_build_object('mode','persistent','heartbeat_required',true,'continue_on_partial_success',true,'record_observation_each_iteration',true),
        'stop_conditions',jsonb_build_array('verified'),'max_iterations',3),
      'subtasks',jsonb_build_array(jsonb_build_object(
        'name','Smoke leaf','description','One independently claimable leaf',
        'actions',jsonb_build_array('Run the smoke check','Capture reproducible test evidence'),
        'general_pattern',jsonb_build_object('objective','Complete the smoke check','approach','Execute, observe and report'),
        'acceptance_criteria',jsonb_build_array('Smoke check passes'),
        'verification',jsonb_build_object('required',true,'method','independent'),
        'loop',jsonb_build_object('enabled',true,'objective','Pass smoke check',
          'input_contract',jsonb_build_object('type','object','required',jsonb_build_array('task_name')),
          'output_contract',jsonb_build_object('type','object','required',jsonb_build_array('result')),
          'transformation','Run the smoke check and capture independent evidence.',
          'observation',jsonb_build_object('required',jsonb_build_array('test_results','runtime_observations','known_gaps')),
          'cycle',jsonb_build_array('run','observe','evaluate'),
          'evaluation',jsonb_build_object('criteria','smoke passes'),
          'revision_policy',jsonb_build_object('on_failure','Diagnose and retry the smoke check','max_revisions',2),
          'initial_input',jsonb_build_object('phase','inspect','task_name','Smoke leaf'),
          'tools',jsonb_build_array('Supabase PostgreSQL','SQL integration test'),
          'iteration_policy',jsonb_build_object('mode','persistent','heartbeat_required',true,'continue_on_partial_success',true,'record_observation_each_iteration',true),
          'stop_conditions',jsonb_build_array('pass','blocked'),'max_iterations',3)
      ))
    ),
    null,'{}'::jsonb
  );
  goal_id_value := (created->'goal'->>'id')::uuid;
  root_id := (created->>'root_task_id')::uuid;
  if goal_id_value is null or root_id is null then raise exception 'Goal/tree creation returned incomplete IDs'; end if;

  select * into claimed from public.goal_ledger_claim_task(
    goal_name,'smoke-worker','Smoke Worker','worker',array[]::text[],'session-smoke',900
  );
  if claimed.id is null or claimed.task_name<>'Smoke leaf' or claimed.claimed_session_id<>'session-smoke' then
    raise exception 'Goal worker did not claim expected leaf task';
  end if;

  select * into second_claim from public.goal_ledger_claim_task(
    goal_name,'smoke-worker-2','Smoke Worker 2','worker',array[]::text[],'session-smoke-2',900
  );
  if second_claim.id is not null then raise exception 'A second worker duplicated an active task claim'; end if;

  perform public.task_ledger_record_loop_iteration(
    claimed.id,'smoke-worker',claimed.claim_token,1,'{}','{"ok":true}','{"observed":"pass"}',
    '[{"criterion":"Smoke check passes","status":"satisfied"}]','{"iteration":1}',
    '[]','[{"type":"test","result":"passed"}]','pass','Smoke check passed'
  );
  perform public.task_ledger_submit_result(
    claimed.id,'smoke-worker',claimed.claim_token,'{"ok":true}','Smoke leaf completed',
    '[]','[{"type":"test","result":"passed"}]','completed'
  );

  select * into verifier from public.task_ledger_claim_verification('smoke-orchestrator',900);
  if verifier.id is null or verifier.id<>claimed.id then raise exception 'Verifier did not claim submitted leaf result'; end if;
  perform public.task_ledger_verify_result_claimed(
    verifier.id,'smoke-orchestrator',verifier.verification_claim_token,true,'{"independent":true}'
  );

  perform public.task_ledger_record_parent_loop_iteration(
    root_id,'smoke-orchestrator',1,
    '{"task_tree":"Smoke leaf"}','{"verified":true}',
    '{"child_task":"Smoke leaf","verification":"independent pass"}',
    '[{"criterion":"All child tasks verified","status":"satisfied"}]',
    '{"phase":"complete","iteration":1}',
    '["Supabase PostgreSQL","Task ledger"]',
    '[{"type":"verification","result":"passed","task_key":"Smoke leaf"}]',
    'pass','All child tasks independently verified; parent loop passed'
  );

  final_goal := public.goal_ledger_finalize(goal_name,'smoke-orchestrator','{"verified":true}');
  if final_goal.status<>'completed' then raise exception 'Goal did not finalize'; end if;
  resumed := public.goal_ledger_resume(goal_name);
  if resumed->'summary'->'tasks'->>'completed'<>'1' then raise exception 'Resume summary incorrect: %',resumed; end if;
  raise notice 'PASS: goal creation, task tree, exclusive session claim, loop evidence, result submission, verifier lease, finalization and resume';
end;
$test$;
rollback;
