-- Rollback-only regression test for five-minute heartbeat recovery and fencing.
begin;
do $test$
declare
  registered public.tasks;
  first_claim public.tasks;
  early_claim public.tasks;
  recovered public.tasks;
  handoff public.task_events;
  old_token uuid;
begin
  select * into registered from public.task_ledger_register(
    'heartbeat-hardening-test','Heartbeat Hardening Test','5-minute recovery leaf',
    'Disposable integration-test task',array['heartbeat-hardening']::text[],
    'heartbeat-hardening-session','worker',3::smallint,'Testing five-minute recovery','{}'::jsonb,null
  );
  update public.tasks
  set required_capabilities=array['heartbeat-hardening']::text[]
  where id=registered.id;

  select * into first_claim from public.task_ledger_claim_next(
    'heartbeat-hardening-old','Old Worker','worker',array['heartbeat-hardening']::text[],600
  );
  if first_claim.id is distinct from registered.id then
    raise exception 'Initial worker did not claim the test task';
  end if;
  old_token:=first_claim.claim_token;

  perform public.task_ledger_heartbeat_claim(
    first_claim.id,'heartbeat-hardening-old',old_token,
    'Implementing lease hardening',600,
    jsonb_build_object(
      'activity','writing recovery migration',
      'progress','Claim path and heartbeat path audited',
      'discoveries',jsonb_build_array('claim token is the fencing token'),
      'next_action','run stale recovery test'
    )
  );

  if not public.task_ledger_check_claim(first_claim.id,'heartbeat-hardening-old',old_token) then
    raise exception 'Active worker failed its ownership check';
  end if;

  update public.tasks
  set heartbeat_at=now()-interval '4 minutes 59 seconds'
  where id=first_claim.id;

  select * into early_claim from public.task_ledger_claim_next(
    'heartbeat-hardening-early','Early Worker','worker',array['heartbeat-hardening']::text[],600
  );
  if early_claim.id is not null then
    raise exception 'Task was reclaimed before the five-minute heartbeat threshold';
  end if;

  update public.tasks
  set heartbeat_at=now()-interval '5 minutes 1 second'
  where id=first_claim.id;

  select * into recovered from public.task_ledger_claim_next(
    'heartbeat-hardening-new','Recovery Worker','worker',array['heartbeat-hardening']::text[],600
  );
  if recovered.id is distinct from first_claim.id then
    raise exception 'Stale heartbeat did not allow reassignment after five minutes';
  end if;
  if recovered.claimed_by_agent_id<>'heartbeat-hardening-new' then
    raise exception 'Recovered task owner was not replaced';
  end if;
  if recovered.claim_token=old_token then
    raise exception 'Recovery did not rotate the fencing token';
  end if;
  if not exists(
    select 1 from public.task_events e
    where e.task_id=recovered.id
      and e.event_type='lease_recovered'
      and e.payload->>'previous_agent_id'='heartbeat-hardening-old'
      and e.payload->>'recovery_reason'='heartbeat_timeout'
      and (e.payload->'previous_heartbeat_context'->>'activity')='writing recovery migration'
  ) then
    raise exception 'Recovery did not preserve the last heartbeat context';
  end if;

  if public.task_ledger_check_claim(first_claim.id,'heartbeat-hardening-old',old_token) then
    raise exception 'Old worker retained ownership after fencing-token rotation';
  end if;

  select * into handoff from public.task_ledger_record_handoff(
    recovered.id,'heartbeat-hardening-old',old_token,
    'Lost ownership while implementing lease hardening; next worker should continue from the last heartbeat checkpoint.',
    jsonb_build_object('last_known_step','Implementing lease hardening')
  );
  if handoff.event_type<>'handoff' then
    raise exception 'Handoff event was not recorded';
  end if;

  raise notice 'PASS: 5-minute heartbeat recovery, durable checkpoint context, fencing and handoff evidence';
end;
$test$;
rollback;
