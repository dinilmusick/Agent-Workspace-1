-- Harden ephemeral-worker task coordination around a short heartbeat lease.
-- Heartbeats are durable progress checkpoints; stale recovery is heartbeat-based.
-- claim_token remains the fencing token. Recovery never depends on lease expiry alone.

alter table public.tasks
  add column if not exists heartbeat_context jsonb not null default '{}'::jsonb;

alter table public.task_events
  drop constraint if exists task_events_event_type_check;

alter table public.task_events
  add constraint task_events_event_type_check check (event_type = any (array[
    'registered','started','heartbeat','progress','tagged','blocked','unblocked',
    'completed','failed','cancelled','abandoned','reopened','note','claimed',
    'released','result_submitted','verified','verification_rejected',
    'iteration_recorded','loop_iteration_recorded','dependency_added','tree_created',
    'lease_recovered','handoff'
  ]::text[]));

create index if not exists tasks_heartbeat_recovery_idx
  on public.tasks(status, heartbeat_at, priority, started_at)
  where status='running';

comment on column public.tasks.heartbeat_context is
  'Latest durable worker checkpoint: current activity, progress, discoveries, blockers and next action.';

create or replace function public.task_ledger_heartbeat_policy()
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
  select jsonb_build_object(
    'heartbeat_interval_seconds', 120,
    'ownership_check_interval_seconds', 300,
    'stale_heartbeat_timeout_seconds', 300,
    'recovery_threshold_minutes', 5,
    'lease_expiry_is_recovery_gate', false,
    'fencing_token', 'claim_token',
    'checkpoint_required', true
  );
$function$;

create or replace function public.task_ledger_claim_next(
  agent_id_in text,
  agent_name_in text,
  agent_type_in text default 'worker',
  capabilities_in text[] default '{}'::text[],
  lease_seconds_in integer default 900
)
returns setof public.tasks
language plpgsql
set search_path to 'public'
as $function$
declare
  candidate_id uuid;
  previous_status text;
  previous_agent_id text;
  previous_heartbeat timestamptz;
  previous_claim_token uuid;
  previous_heartbeat_context jsonb;
  task_out public.tasks;
  lease_value integer := greatest(600, least(coalesce(lease_seconds_in,600),86400));
begin
  if nullif(btrim(agent_id_in),'') is null or nullif(btrim(agent_name_in),'') is null then
    raise exception 'agent identity is required';
  end if;

  select t.id,t.status,t.claimed_by_agent_id,t.heartbeat_at,t.claim_token,t.heartbeat_context
    into candidate_id,previous_status,previous_agent_id,previous_heartbeat,previous_claim_token,previous_heartbeat_context
  from public.tasks t
  where t.status in ('queued','running')
    and t.attempt_count<t.max_attempts
    and (
      t.status='queued'
      or (t.status='running'
        and coalesce(t.heartbeat_at,'-infinity'::timestamptz)<=now()-interval '5 minutes')
    )
    and t.required_capabilities<@coalesce(capabilities_in,'{}'::text[])
    and not exists(select 1 from public.tasks child where child.parent_task_id=t.id)
    and (t.parent_task_id is null or not exists(
      select 1 from public.tasks p where p.id=t.parent_task_id
        and p.status in ('failed','cancelled','abandoned','blocked')
    ))
    and (t.goal_id is null or exists(
      select 1 from public.goals g where g.id=t.goal_id and g.status in ('ready','active')
    ))
    and not exists(
      select 1 from public.task_dependencies d
      join public.tasks dep on dep.id=d.depends_on_task_id
      where d.task_id=t.id and d.dependency_type='blocking'
        and (dep.status<>'completed' or dep.verification_status<>'verified')
    )
  order by t.priority asc,t.started_at asc
  for update skip locked
  limit 1;

  if candidate_id is null then return; end if;

  if previous_status='running' and previous_agent_id is not null then
    insert into public.task_events(task_id,event_type,agent_id,message,payload)
    values(
      candidate_id,'lease_recovered',agent_id_in,
      'Task reclaimed after at least 5 minutes without a heartbeat.',
      jsonb_build_object(
        'previous_agent_id',previous_agent_id,
        'previous_claim_token',previous_claim_token,
        'previous_heartbeat_at',previous_heartbeat,
        'previous_heartbeat_context',coalesce(previous_heartbeat_context,'{}'::jsonb),
        'recovery_reason','heartbeat_timeout',
        'recovery_threshold_minutes',5
      )
    );
  end if;

  update public.tasks
  set status='running',
      claimed_by_agent_id=agent_id_in,
      claimed_by_agent_name=agent_name_in,
      claim_token=gen_random_uuid(),
      claimed_at=now(),
      claim_expires_at=now()+make_interval(secs=>lease_value),
      attempt_count=attempt_count+1,
      heartbeat_at=now(),
      updated_at=now(),
      heartbeat_context=jsonb_build_object(
        'activity','claimed',
        'progress','Task claimed; execution checkpoint initialized.',
        'next_action','Begin persisted task loop.'
      ),
      current_step='Claimed by worker agent'
  where id=candidate_id
  returning * into task_out;

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_out.id,'claimed',agent_id_in,'Task claimed by worker',
    jsonb_build_object(
      'lease_expires_at',task_out.claim_expires_at,
      'attempt_count',task_out.attempt_count,
      'heartbeat_policy',public.task_ledger_heartbeat_policy()
    ));

  return next task_out;
end;
$function$;

create or replace function public.task_ledger_claim_goal_next(
  goal_id_in uuid,
  agent_id_in text,
  agent_name_in text,
  agent_type_in text default 'worker',
  capabilities_in text[] default '{}'::text[],
  lease_seconds_in integer default 900
)
returns setof public.tasks
language plpgsql
set search_path to 'public'
as $function$
declare
  candidate_id uuid;
  previous_status text;
  previous_agent_id text;
  previous_heartbeat timestamptz;
  previous_claim_token uuid;
  previous_heartbeat_context jsonb;
  task_out public.tasks;
  lease_value integer := greatest(600, least(coalesce(lease_seconds_in,600),86400));
begin
  if goal_id_in is null or nullif(btrim(agent_id_in),'') is null or nullif(btrim(agent_name_in),'') is null then
    raise exception 'goal and agent identity are required';
  end if;
  if not exists(
    select 1 from public.goals g
    where g.id=goal_id_in and g.status in ('ready','active')
      and (auth.uid() is null or g.owner_user_id=auth.uid())
  ) then
    raise exception 'goal not found, not claimable, or access denied';
  end if;

  select t.id,t.status,t.claimed_by_agent_id,t.heartbeat_at,t.claim_token,t.heartbeat_context
    into candidate_id,previous_status,previous_agent_id,previous_heartbeat,previous_claim_token,previous_heartbeat_context
  from public.tasks t
  where t.goal_id=goal_id_in
    and t.status in ('queued','running')
    and t.attempt_count<t.max_attempts
    and (
      t.status='queued'
      or (t.status='running'
        and coalesce(t.heartbeat_at,'-infinity'::timestamptz)<=now()-interval '5 minutes')
    )
    and t.required_capabilities<@coalesce(capabilities_in,'{}'::text[])
    and not exists(select 1 from public.tasks child where child.parent_task_id=t.id)
    and (t.parent_task_id is null or not exists(
      select 1 from public.tasks p where p.id=t.parent_task_id
        and p.status in ('failed','cancelled','abandoned','blocked')
    ))
    and not exists(
      select 1 from public.task_dependencies d
      join public.tasks dep on dep.id=d.depends_on_task_id
      where d.task_id=t.id and d.dependency_type='blocking'
        and (dep.status<>'completed' or dep.verification_status<>'verified')
    )
  order by t.priority asc,t.started_at asc
  for update skip locked
  limit 1;

  if candidate_id is null then return; end if;

  if previous_status='running' and previous_agent_id is not null then
    insert into public.task_events(task_id,event_type,agent_id,message,payload)
    values(
      candidate_id,'lease_recovered',agent_id_in,
      'Task reclaimed after at least 5 minutes without a heartbeat.',
      jsonb_build_object(
        'previous_agent_id',previous_agent_id,
        'previous_claim_token',previous_claim_token,
        'previous_heartbeat_at',previous_heartbeat,
        'previous_heartbeat_context',coalesce(previous_heartbeat_context,'{}'::jsonb),
        'recovery_reason','heartbeat_timeout',
        'recovery_threshold_minutes',5
      )
    );
  end if;

  update public.tasks
  set status='running',
      claimed_by_agent_id=agent_id_in,
      claimed_by_agent_name=agent_name_in,
      claim_token=gen_random_uuid(),
      claimed_at=now(),
      claim_expires_at=now()+make_interval(secs=>lease_value),
      attempt_count=attempt_count+1,
      heartbeat_at=now(),
      updated_at=now(),
      heartbeat_context=jsonb_build_object(
        'activity','claimed',
        'progress','Task claimed; execution checkpoint initialized.',
        'next_action','Begin persisted task loop.'
      ),
      current_step='Claimed by chat worker'
  where id=candidate_id
  returning * into task_out;

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_out.id,'claimed',agent_id_in,'Task claimed by chat worker',
    jsonb_build_object(
      'lease_expires_at',task_out.claim_expires_at,
      'attempt_count',task_out.attempt_count,
      'heartbeat_policy',public.task_ledger_heartbeat_policy()
    ));

  return next task_out;
end;
$function$;

create or replace function public.goal_ledger_claim_task(
  goal_name_in text,
  agent_id_in text,
  agent_name_in text,
  agent_type_in text default 'worker',
  capabilities_in text[] default '{}'::text[],
  session_id_in text default null,
  lease_seconds_in integer default 900
)
returns setof public.tasks
language plpgsql
set search_path to 'public'
as $function$
declare
  goal_id_value uuid;
  creator_id text;
  candidate_id uuid;
  previous_status text;
  previous_agent_id text;
  previous_heartbeat timestamptz;
  previous_claim_token uuid;
  previous_heartbeat_context jsonb;
  task_out public.tasks;
  lease_value integer := greatest(600, least(coalesce(lease_seconds_in,600),86400));
begin
  if nullif(btrim(goal_name_in),'') is null
    or nullif(btrim(agent_id_in),'') is null
    or nullif(btrim(agent_name_in),'') is null
    or nullif(btrim(session_id_in),'') is null then
    raise exception 'goal name, agent identity and unique chat session_id are required';
  end if;

  select id,created_by_agent_id into goal_id_value,creator_id
  from public.goals
  where lower(name)=lower(btrim(goal_name_in))
    and (auth.uid() is null or owner_user_id=auth.uid())
    and status in ('ready','active');

  if goal_id_value is null then
    raise exception 'goal not found or access denied: %',goal_name_in;
  end if;
  if agent_id_in=creator_id then
    raise exception 'worker agent_id must differ from the orchestrator agent_id';
  end if;

  select t.id,t.status,t.claimed_by_agent_id,t.heartbeat_at,t.claim_token,t.heartbeat_context
    into candidate_id,previous_status,previous_agent_id,previous_heartbeat,previous_claim_token,previous_heartbeat_context
  from public.tasks t
  where t.goal_id=goal_id_value
    and t.status in ('queued','running')
    and t.attempt_count<t.max_attempts
    and (
      t.status='queued'
      or (t.status='running'
        and coalesce(t.heartbeat_at,'-infinity'::timestamptz)<=now()-interval '5 minutes')
    )
    and t.required_capabilities<@coalesce(capabilities_in,'{}'::text[])
    and not exists(select 1 from public.tasks child where child.parent_task_id=t.id)
    and (t.parent_task_id is null or not exists(
      select 1 from public.tasks p where p.id=t.parent_task_id
        and p.status in ('failed','cancelled','abandoned','blocked')
    ))
    and not exists(
      select 1 from public.task_dependencies d
      join public.tasks dep on dep.id=d.depends_on_task_id
      where d.task_id=t.id and d.dependency_type='blocking'
        and (dep.status<>'completed' or dep.verification_status<>'verified')
    )
  order by t.priority asc,t.started_at asc
  for update skip locked
  limit 1;

  if candidate_id is null then return; end if;

  if previous_status='running' and previous_agent_id is not null then
    insert into public.task_events(task_id,event_type,agent_id,message,payload)
    values(
      candidate_id,'lease_recovered',agent_id_in,
      'Goal-scoped task reclaimed after at least 5 minutes without a heartbeat.',
      jsonb_build_object(
        'previous_agent_id',previous_agent_id,
        'previous_claim_token',previous_claim_token,
        'previous_heartbeat_at',previous_heartbeat,
        'previous_heartbeat_context',coalesce(previous_heartbeat_context,'{}'::jsonb),
        'recovery_reason','heartbeat_timeout',
        'recovery_threshold_minutes',5
      )
    );
  end if;

  update public.tasks
  set status='running',
      claimed_by_agent_id=agent_id_in,
      claimed_by_agent_name=agent_name_in,
      claimed_session_id=session_id_in,
      claim_token=gen_random_uuid(),
      claimed_at=now(),
      claim_expires_at=now()+make_interval(secs=>lease_value),
      attempt_count=attempt_count+1,
      heartbeat_at=now(),
      updated_at=now(),
      heartbeat_context=jsonb_build_object(
        'activity','claimed',
        'progress','Goal-scoped task claimed; execution checkpoint initialized.',
        'next_action','Begin persisted task loop.'
      ),
      current_step='Claimed by ChatGPT worker'
  where id=candidate_id
  returning * into task_out;

  update public.goals set status='active',updated_at=now()
  where id=goal_id_value and status='ready';

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(
    task_out.id,'claimed',agent_id_in,'Goal-scoped ChatGPT worker claimed task',
    jsonb_build_object(
      'goal_id',goal_id_value,
      'session_id',session_id_in,
      'lease_expires_at',task_out.claim_expires_at,
      'attempt_count',task_out.attempt_count,
      'heartbeat_policy',public.task_ledger_heartbeat_policy()
    )
  );

  return next task_out;
end;
$function$;

create or replace function public.goal_ledger_claim_task_by_key(
  goal_key_in text,
  agent_id_in text,
  agent_name_in text,
  agent_type_in text default 'worker',
  capabilities_in text[] default '{}',
  session_id_in text default null,
  lease_seconds_in integer default 900
)
returns setof public.tasks
language plpgsql
set search_path to 'public'
as $function$
declare goal_out public.goals;
begin
  goal_out:=public.goal_ledger_get_by_key(goal_key_in);
  if goal_out.status='blocked' then
    raise exception 'goal is blocked; inspect and resolve its blocker before claiming a task';
  end if;
  if goal_out.status not in ('ready','active') then
    raise exception 'goal is not available for task claims: %',goal_out.status;
  end if;
  return query select * from public.goal_ledger_claim_task(
    goal_out.name,agent_id_in,agent_name_in,agent_type_in,capabilities_in,session_id_in,lease_seconds_in
  );
end;
$function$;

create or replace function public.task_ledger_heartbeat_claim(
  task_id_in uuid,
  agent_id_in text,
  claim_token_in uuid,
  current_step_in text default null,
  lease_seconds_in integer default 900,
  heartbeat_context_in jsonb default '{}'::jsonb
)
returns public.tasks
language plpgsql
set search_path to 'public'
as $function$
declare
  task_out public.tasks;
  context_value jsonb := coalesce(heartbeat_context_in,'{}'::jsonb);
begin
  if jsonb_typeof(context_value)<>'object' then
    raise exception 'heartbeat_context must be a JSON object';
  end if;

  update public.tasks
  set heartbeat_at=now(),
      updated_at=now(),
      current_step=coalesce(current_step_in,current_step),
      heartbeat_context=context_value,
      claim_expires_at=now()+make_interval(secs=>greatest(600,least(coalesce(lease_seconds_in,600),86400)))
  where id=task_id_in
    and claimed_by_agent_id=agent_id_in
    and claim_token=claim_token_in
    and status='running'
  returning * into task_out;

  if task_out.id is null then
    raise exception 'Claim not found, expired, or not owned by agent';
  end if;

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(
    task_id_in,'heartbeat',agent_id_in,current_step_in,
    jsonb_build_object(
      'heartbeat_at',task_out.heartbeat_at,
      'current_step',task_out.current_step,
      'heartbeat_context',context_value,
      'claim_token',claim_token_in
    )
  );
  return task_out;
end;
$function$;

create or replace function public.task_ledger_check_claim(
  task_id_in uuid,
  agent_id_in text,
  claim_token_in uuid
)
returns boolean
language sql
stable
set search_path to 'public'
as $function$
  select exists(
    select 1 from public.tasks
    where id=task_id_in
      and status='running'
      and claimed_by_agent_id=agent_id_in
      and claim_token=claim_token_in
  );
$function$;

create or replace function public.task_ledger_record_handoff(
  task_id_in uuid,
  previous_agent_id_in text,
  previous_claim_token_in uuid,
  handoff_note_in text,
  context_in jsonb default '{}'
)
returns public.task_events
language plpgsql
set search_path to 'public'
as $function$
declare event_out public.task_events;
begin
  if nullif(btrim(previous_agent_id_in),'') is null
     or previous_claim_token_in is null
     or nullif(btrim(handoff_note_in),'') is null then
    raise exception 'previous agent, claim token and handoff note are required';
  end if;
  if jsonb_typeof(coalesce(context_in,'{}'))<>'object' then
    raise exception 'handoff context must be a JSON object';
  end if;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(
    task_id_in,'handoff',previous_agent_id_in,handoff_note_in,
    jsonb_build_object(
      'previous_claim_token',previous_claim_token_in,
      'handoff_context',coalesce(context_in,'{}'),
      'ownership_check',public.task_ledger_check_claim(task_id_in,previous_agent_id_in,previous_claim_token_in)
    )
  )
  returning * into event_out;
  return event_out;
end;
$function$;

revoke all on function public.task_ledger_check_claim(uuid,text,uuid) from public,anon,authenticated;
revoke all on function public.task_ledger_record_handoff(uuid,text,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.task_ledger_check_claim(uuid,text,uuid) to service_role;
grant execute on function public.task_ledger_record_handoff(uuid,text,uuid,text,jsonb) to service_role;

comment on function public.task_ledger_heartbeat_policy() is
'Canonical ephemeral-worker coordination policy: heartbeat every ~2 minutes, ownership check every 5 minutes, recover after 5 minutes of heartbeat silence.';

comment on function public.task_ledger_check_claim(uuid,text,uuid) is
'Fencing check for active workers. A false result means the worker must stop and hand off.';

comment on function public.task_ledger_record_handoff(uuid,text,uuid,text,jsonb) is
'Append-only handoff checkpoint for a worker that discovered it lost task ownership.';
