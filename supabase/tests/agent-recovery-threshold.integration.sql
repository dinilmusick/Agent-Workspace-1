-- Rollback-only test of the exact 60-minute stale-worker threshold.
begin;
do $test$
declare
  registered public.tasks;
  first_claim public.tasks;
  early_claim public.tasks;
  recovered public.tasks;
begin
  select * into registered from public.task_ledger_register(
    'recovery-threshold-test','Recovery Threshold Test','60-minute threshold leaf',
    'Disposable integration-test task',array['recovery-threshold']::text[],
    'recovery-threshold-session','worker',3::smallint,'Testing heartbeat-based recovery','{}'::jsonb,null
  );
  select * into first_claim from public.task_ledger_claim_next(
    'recovery-threshold-old','Old Worker','worker',array['recovery-threshold']::text[],900
  );
  update public.tasks set required_capabilities=array['recovery-threshold']::text[] where id=registered.id;

  if first_claim.id is distinct from registered.id then
    raise exception 'Initial worker did not claim the test task';
  end if;

  update public.tasks
  set heartbeat_at=now()-interval '59 minutes',
      claim_expires_at=now()-interval '1 minute'
  where id=first_claim.id;

  select * into early_claim from public.task_ledger_claim_next(
    'recovery-threshold-early','Early Worker','worker',array['recovery-threshold']::text[],900
  );
  if early_claim.id is not null then
    raise exception 'Expired lease incorrectly allowed reassignment before 60 minutes';
  end if;

  update public.tasks
  set heartbeat_at=now()-interval '61 minutes',
      claim_expires_at=now()+interval '15 minutes'
  where id=first_claim.id;

  select * into recovered from public.task_ledger_claim_next(
    'recovery-threshold-new','Recovery Worker','worker',array['recovery-threshold']::text[],900
  );
  if recovered.id is distinct from first_claim.id then
    raise exception 'Stale heartbeat did not allow reassignment after 60 minutes';
  end if;
  if recovered.claimed_by_agent_id<>'recovery-threshold-new' then
    raise exception 'New worker did not receive ownership';
  end if;
  if recovered.claim_token=first_claim.claim_token then
    raise exception 'Recovery did not rotate the claim token';
  end if;
  if recovered.claim_expires_at<now()+interval '60 minutes' then
    raise exception 'New claim lease is shorter than the recovery window';
  end if;
  if not exists(
    select 1 from public.task_events e
    where e.task_id=recovered.id and e.event_type='lease_recovered'
      and e.payload->>'previous_agent_id'='recovery-threshold-old'
      and e.payload->>'recovery_reason'='heartbeat_timeout'
  ) then
    raise exception 'Recovery event did not preserve previous worker evidence';
  end if;

  raise notice 'PASS: expired lease cannot bypass the 60-minute heartbeat threshold; stale task is atomically reassigned';
end;
$test$;
rollback;
