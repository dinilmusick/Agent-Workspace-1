-- Rollback-only integration test. Run against a disposable database with a privileged SQL connection.
begin;
do $test$
declare
  created jsonb;
  goal_key_value text;
  goal_id_value uuid;
  first_claim public.tasks;
  recovered public.tasks;
  overview jsonb;
  goal_row jsonb;
  loop_contract jsonb := jsonb_build_object(
    'enabled',true,
    'objective','Verify stale worker recovery',
    'input_contract',jsonb_build_object('type','object','required',jsonb_build_array('repository')),
    'output_contract',jsonb_build_object('type','object','required',jsonb_build_array('implementation','tests','evidence')),
    'evaluation',jsonb_build_object('method','Check explicit test evidence','pass_condition','All assertions pass'),
    'stop_conditions',jsonb_build_array('All assertions pass'),
    'max_iterations',3
  );
  task_definition jsonb;
begin
  task_definition := jsonb_build_object(
    'name','Recovery test parent',
    'description','Parent task for recovery integration test',
    'acceptance_criteria',jsonb_build_array('Child is independently recoverable'),
    'loop',loop_contract,
    'subtasks',jsonb_build_array(jsonb_build_object(
      'name','Recovery test leaf',
      'description','A leaf task used to test stale worker recovery',
      'acceptance_criteria',jsonb_build_array('A second worker can atomically reclaim this task'),
      'required_capabilities',jsonb_build_array('recovery-test'),
      'loop',loop_contract
    ))
  );

  created := public.goal_ledger_create_with_tasks(
    'Recovery Smoke ' || replace(gen_random_uuid()::text,'-',''),
    'Rollback-only stale-worker recovery test',
    jsonb_build_object('repository','Agent-Workspace-1'),
    'Test one-hour recovery and complete goal discovery.',
    jsonb_build_array('Stale task can be reclaimed after 60 minutes'),
    'recovery-test-orchestrator',
    task_definition,
    null,
    jsonb_build_object('integration_test',true)
  );
  goal_id_value := (created->'goal'->>'id')::uuid;
  goal_key_value := created->'goal'->>'goal_key';
  if goal_id_value is null or goal_key_value is null then
    raise exception 'Goal creation returned no ID or readable key: %',created;
  end if;

  select * into first_claim
  from public.goal_ledger_claim_task_by_key(
    goal_key_value,'recovery-worker-old','Old Worker','worker',
    array['recovery-test']::text[],'recovery-session-old',900
  );
  if first_claim.id is null or first_claim.task_name<>'Recovery test leaf' then
    raise exception 'Initial worker did not claim the expected leaf task';
  end if;

  update public.tasks
  set heartbeat_at=now()-interval '61 minutes',
      claim_expires_at=now()+interval '15 minutes',
      current_step='Simulated abandoned worker'
  where id=first_claim.id;

  select * into recovered
  from public.goal_ledger_claim_task_by_key(
    goal_key_value,'recovery-worker-new','Recovery Worker','worker',
    array['recovery-test']::text[],'recovery-session-new',900
  );
  if recovered.id is distinct from first_claim.id then
    raise exception 'New worker did not reclaim stale task';
  end if;
  if recovered.claimed_by_agent_id<>'recovery-worker-new' then
    raise exception 'Recovered task owner was not replaced';
  end if;
  if recovered.claim_token=first_claim.claim_token then
    raise exception 'Recovery did not rotate the claim token';
  end if;
  if recovered.attempt_count<>first_claim.attempt_count+1 then
    raise exception 'Recovery attempt count was not incremented';
  end if;
  if not exists(
    select 1 from public.task_events e
    where e.task_id=recovered.id and e.event_type='lease_recovered'
      and e.payload->>'previous_agent_id'='recovery-worker-old'
      and e.payload->>'recovery_reason'='heartbeat_timeout'
  ) then
    raise exception 'Recovery event did not preserve previous worker evidence';
  end if;

  overview := public.goal_ledger_overview(null);
  select item into goal_row
  from jsonb_array_elements(overview->'goals') item
  where item->>'id'=goal_id_value::text;
  if goal_row is null then
    raise exception 'Goal overview omitted the active goal';
  end if;
  if not exists(
    select 1 from jsonb_array_elements(goal_row->'tasks') item
    where item->>'agent_id'='recovery-worker-new'
      and item->>'task_key'=recovered.task_key
  ) then
    raise exception 'Goal overview did not expose current task ownership';
  end if;
  if (overview->'policy'->>'stale_worker_timeout_minutes')::int<>60 then
    raise exception 'Goal overview did not expose the recovery policy';
  end if;
  if (goal_row->'task_counts'->>'running')::int<1 then
    raise exception 'Goal overview did not aggregate running tasks';
  end if;

  raise notice 'PASS: one-hour recovery, token rotation, append-only recovery evidence and complete goal overview';
end;
$test$;
rollback;
