-- Rollback-only integration test for one-hour task recovery and full goal discovery.
-- Run with a privileged SQL connection against a disposable database.
begin;
do $test$
declare
  goal_name text := 'Recovery Smoke ' || replace(gen_random_uuid()::text,'-','');
  created jsonb;
  goal_id_value uuid;
  first_claim public.tasks;
  recovered public.tasks;
  overview jsonb;
  goal_row jsonb;
begin
  created := public.goal_ledger_create_with_tasks(
    goal_name,'Rollback-only stale-worker recovery test',
    jsonb_build_object('repository','Agent-Workspace-1'),
    'Test one-hour stale recovery and goal overview.',
    jsonb_build_array('Stale task can be reclaimed after 60 minutes'),
    'recovery-test-orchestrator',
    jsonb_build_object(
      'name','Recovery test task',
      'acceptance_criteria',jsonb_build_array('Reclaimed by a second worker'),
      'verification',jsonb_build_object('required',true),
      'loop',jsonb_build_object(
        'enabled',true,'objective','Verify stale task recovery',
        'input_contract',jsonb_build_object('type','input'),
        'output_contract',jsonb_build_object('type','result'),
        'cycle',jsonb_build_array('claim','simulate-stale','reclaim','verify'),
        'evaluation',jsonb_build_object('criteria','second worker owns task'),
        'stop_conditions',jsonb_build_array('reclaimed'),
        'max_iterations',3
      )
    ),
    null,'{}'::jsonb
  );
  goal_id_value := (created->'goal'->>'id')::uuid;
  if goal_id_value is null then raise exception 'Goal creation returned no ID'; end if;

  select * into first_claim from public.goal_ledger_claim_task(
    goal_name,'recovery-worker-old','Old Worker','worker',array[]::text[],'recovery-session-old',3600
  );
  if first_claim.id is null then raise exception 'Initial worker did not claim test task'; end if;

  update public.tasks
  set heartbeat_at=now()-interval '61 minutes',
      claim_expires_at=now()+interval '15 minutes',
      current_step='Simulated abandoned worker'
  where id=first_claim.id;

  select * into recovered from public.task_ledger_claim_goal_next(
    goal_id_value,'recovery-worker-new','Recovery Worker','worker',array[]::text[],900
  );
  if recovered.id is distinct from first_claim.id then raise exception 'New worker did not reclaim stale task'; end if;
  if recovered.claimed_by_agent_id<>'recovery-worker-new' then raise exception 'Recovered task owner was not replaced'; end if;
  if recovered.claim_token=first_claim.claim_token then raise exception 'Recovery did not rotate the claim token'; end if;
  if recovered.attempt_count<>first_claim.attempt_count+1 then raise exception 'Recovery attempt count was not incremented'; end if;
  if not exists(
    select 1 from public.task_events e
    where e.task_id=recovered.id and e.event_type='lease_recovered'
      and e.payload->>'previous_agent_id'='recovery-worker-old'
      and e.payload->>'recovery_reason'='heartbeat_timeout'
  ) then raise exception 'Recovery event did not preserve previous worker evidence'; end if;

  overview := public.goal_ledger_overview(null);
  select item into goal_row from jsonb_array_elements(overview->'goals') item
  where item->>'id'=goal_id_value::text;
  if goal_row is null then raise exception 'Goal overview omitted the active goal'; end if;
  if goal_row->'tasks'->0->>'agent_id'<>'recovery-worker-new' then
    raise exception 'Goal overview did not expose the current task owner';
  end if;
  if (overview->'policy'->>'stale_worker_timeout_minutes')::int<>60 then
    raise exception 'Goal overview did not expose the recovery policy';
  end if;
  raise notice 'PASS: stale heartbeat recovery, ownership rotation, event history and complete goal overview';
end;
$test$;
rollback;
