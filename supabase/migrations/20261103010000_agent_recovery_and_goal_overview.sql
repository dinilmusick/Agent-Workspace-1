-- Atomic recovery of abandoned workers and a complete unfinished-goal overview.
-- A running task becomes reclaimable after 60 minutes without a heartbeat,
-- even when its previous lease expiry is later. Blocked goals/tasks remain ineligible.

alter table public.task_events drop constraint if exists task_events_event_type_check;
alter table public.task_events add constraint task_events_event_type_check
  check (event_type = any (array[
    'registered','started','heartbeat','progress','tagged','blocked','unblocked',
    'completed','failed','cancelled','abandoned','reopened','note','claimed',
    'released','result_submitted','verified','verification_rejected',
    'iteration_recorded','loop_iteration_recorded','dependency_added','tree_created',
    'lease_recovered'
  ]::text[]));

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
  task_out public.tasks;
  lease_value integer := greatest(3600, least(coalesce(lease_seconds_in,3600),86400));
begin
  if nullif(btrim(agent_id_in),'') is null or nullif(btrim(agent_name_in),'') is null then
    raise exception 'agent identity is required';
  end if;

  select t.id,t.status,t.claimed_by_agent_id,t.heartbeat_at,t.claim_token
    into candidate_id,previous_status,previous_agent_id,previous_heartbeat,previous_claim_token
  from public.tasks t
  where t.status in ('queued','running')
    and t.attempt_count<t.max_attempts
    and (
      t.status='queued'
      or (t.status='running' and coalesce(t.heartbeat_at,'-infinity'::timestamptz)<=now()-interval '60 minutes')
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
      'Task reclaimed after at least 60 minutes without a heartbeat.',
      jsonb_build_object(
        'previous_agent_id',previous_agent_id,
        'previous_claim_token',previous_claim_token,
        'previous_heartbeat_at',previous_heartbeat,
        'recovery_reason','heartbeat_timeout'
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
      current_step='Claimed by worker agent'
  where id=candidate_id
  returning * into task_out;

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_out.id,'claimed',agent_id_in,'Task claimed by worker',
    jsonb_build_object('lease_expires_at',task_out.claim_expires_at,'attempt_count',task_out.attempt_count));

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
  task_out public.tasks;
  lease_value integer := greatest(3600, least(coalesce(lease_seconds_in,3600),86400));
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

  select t.id,t.status,t.claimed_by_agent_id,t.heartbeat_at,t.claim_token
    into candidate_id,previous_status,previous_agent_id,previous_heartbeat,previous_claim_token
  from public.tasks t
  where t.goal_id=goal_id_in
    and t.status in ('queued','running')
    and t.attempt_count<t.max_attempts
    and (
      t.status='queued'
      or (t.status='running' and coalesce(t.heartbeat_at,'-infinity'::timestamptz)<=now()-interval '60 minutes')
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
      'Task reclaimed after at least 60 minutes without a heartbeat.',
      jsonb_build_object(
        'previous_agent_id',previous_agent_id,
        'previous_claim_token',previous_claim_token,
        'previous_heartbeat_at',previous_heartbeat,
        'recovery_reason','heartbeat_timeout'
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
      current_step='Claimed by chat worker'
  where id=candidate_id
  returning * into task_out;

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_out.id,'claimed',agent_id_in,'Task claimed by chat worker',
    jsonb_build_object('lease_expires_at',task_out.claim_expires_at,'attempt_count',task_out.attempt_count));

  return next task_out;
end;
$function$;

create or replace function public.goal_ledger_overview(tags_in text[] default null)
returns jsonb
language sql
stable
set search_path to 'public'
as $function$
with visible_goals as (
  select g.*
  from public.goals g
  where g.status in ('planning','ready','active','blocked')
    and (tags_in is null or g.tags && tags_in)
    and (auth.uid() is null or g.owner_user_id=auth.uid())
),
goal_rows as (
  select
    g.id,
    g.goal_key,
    g.name,
    g.description,
    g.status,
    g.tags,
    g.acceptance_criteria,
    g.context,
    g.instructions,
    g.goal_loop_definition,
    g.goal_loop_state,
    g.goal_loop_iteration,
    g.metadata,
    g.context_version,
    g.created_at,
    g.updated_at,
    (
      select jsonb_build_object(
        'total',count(*)::int,
        'queued',count(*) filter(where t.status='queued')::int,
        'running',count(*) filter(where t.status='running')::int,
        'blocked',count(*) filter(where t.status='blocked')::int,
        'failed',count(*) filter(where t.status='failed')::int,
        'completed',count(*) filter(where t.status='completed')::int,
        'awaiting_verification',count(*) filter(where t.status='completed' and coalesce(t.verification_status,'pending') not in ('verified','not_required'))::int
      )
      from public.tasks t where t.goal_id=g.id
    ) task_counts,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'task_key',t.task_key,
        'name',t.task_name,
        'status',t.status,
        'priority',t.priority,
        'agent_id',t.claimed_by_agent_id,
        'agent_name',t.claimed_by_agent_name,
        'heartbeat_at',t.heartbeat_at,
        'claim_expires_at',t.claim_expires_at,
        'heartbeat_stale',t.status='running' and coalesce(t.heartbeat_at,'-infinity'::timestamptz)<=now()-interval '60 minutes',
        'current_step',t.current_step,
        'blocker',t.blocker,
        'verification_status',t.verification_status,
        'parent_task_id',t.parent_task_id,
        'acceptance_criteria',t.acceptance_criteria,
        'verification_plan',t.verification_plan,
        'loop_definition',t.loop_definition,
        'loop_state',t.loop_state,
        'loop_iteration',t.loop_iteration,
        'input_contract',t.input_contract,
        'output_contract',t.output_contract,
        'parameter_contract',t.parameter_contract,
        'parameter_values',t.parameter_values,
        'result_summary',t.result_summary,
        'evidence',t.evidence,
        'dependencies',coalesce((
          select jsonb_agg(jsonb_build_object(
            'task_key',dep.task_key,
            'status',dep.status,
            'verification_status',dep.verification_status,
            'dependency_type',d.dependency_type
          ))
          from public.task_dependencies d
          join public.tasks dep on dep.id=d.depends_on_task_id
          where d.task_id=t.id
        ),'[]'::jsonb),
        'recent_events',coalesce((
          select jsonb_agg(jsonb_build_object(
            'event_type',event_row.event_type,
            'agent_id',event_row.agent_id,
            'occurred_at',event_row.occurred_at,
            'message',event_row.message,
            'payload',event_row.payload
          ) order by event_row.occurred_at desc)
          from (
            select e.event_type,e.agent_id,e.occurred_at,e.message,e.payload
            from public.task_events e
            where e.task_id=t.id
            order by e.occurred_at desc
            limit 5
          ) event_row
        ),'[]'::jsonb)
      ) order by t.priority asc,t.updated_at desc)
      from public.tasks t where t.goal_id=g.id
    ),'[]'::jsonb) tasks
  from visible_goals g
)
select jsonb_build_object(
  'generated_at',now(),
  'policy',jsonb_build_object(
    'stale_worker_timeout_minutes',60,
    'reclaim_is_atomic',true,
    'blocked_tasks_are_not_auto_reclaimed',true
  ),
  'summary',jsonb_build_object(
    'total_goals',(select count(*)::int from goal_rows),
    'active_goals',(select count(*)::int from goal_rows where status='active'),
    'ready_goals',(select count(*)::int from goal_rows where status='ready'),
    'blocked_goals',(select count(*)::int from goal_rows where status='blocked'),
    'planning_goals',(select count(*)::int from goal_rows where status='planning')
  ),
  'goals',coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',id,'goal_key',goal_key,'name',name,'description',description,
      'status',status,'tags',tags,'acceptance_criteria',acceptance_criteria,
      'context',context,'instructions',instructions,
      'goal_loop_definition',goal_loop_definition,'goal_loop_state',goal_loop_state,
      'goal_loop_iteration',goal_loop_iteration,'metadata',metadata,
      'context_version',context_version,'created_at',created_at,'updated_at',updated_at,
      'task_counts',task_counts,'tasks',tasks
    ) order by updated_at desc,name)
    from goal_rows
  ),'[]'::jsonb)
);
$function$;


create or replace function public.task_ledger_heartbeat_claim(
  task_id_in uuid,
  agent_id_in text,
  claim_token_in uuid,
  current_step_in text default null,
  lease_seconds_in integer default 900
)
returns public.tasks
language plpgsql
set search_path to 'public'
as $function$
declare
  task_out public.tasks;
begin
  update public.tasks
  set heartbeat_at=now(),
      updated_at=now(),
      current_step=coalesce(current_step_in,current_step),
      claim_expires_at=now()+make_interval(secs=>greatest(3600,least(coalesce(lease_seconds_in,3600),86400)))
  where id=task_id_in
    and claimed_by_agent_id=agent_id_in
    and claim_token=claim_token_in
    and status='running'
  returning * into task_out;

  if task_out.id is null then
    raise exception 'Claim not found or not owned by agent';
  end if;

  insert into public.task_events(task_id,event_type,agent_id,message)
  values(task_id_in,'heartbeat',agent_id_in,current_step_in);
  return task_out;
end;
$function$;

grant execute on function public.goal_ledger_overview(text[]) to anon, authenticated, service_role;

-- The ChatGPT worker entry point is goal_ledger_claim_task_by_key -> this function.
-- Apply the same stale-heartbeat recovery rule here, not only to generic claim RPCs.
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
  task_out public.tasks;
  lease_value integer := greatest(3600,least(coalesce(lease_seconds_in,3600),86400));
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

  select t.id,t.status,t.claimed_by_agent_id,t.heartbeat_at,t.claim_token
    into candidate_id,previous_status,previous_agent_id,previous_heartbeat,previous_claim_token
  from public.tasks t
  where t.goal_id=goal_id_value
    and t.status in ('queued','running')
    and t.attempt_count<t.max_attempts
    and (
      t.status='queued'
      or (t.status='running' and coalesce(t.heartbeat_at,'-infinity'::timestamptz)<=now()-interval '60 minutes')
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
      'Goal-scoped task reclaimed after at least 60 minutes without a heartbeat.',
      jsonb_build_object(
        'previous_agent_id',previous_agent_id,
        'previous_claim_token',previous_claim_token,
        'previous_heartbeat_at',previous_heartbeat,
        'recovery_reason',case
          when coalesce(previous_heartbeat,'-infinity'::timestamptz)<=now()-interval '60 minutes'
            then 'heartbeat_timeout'
          else 'lease_expired'
        end
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
      'attempt_count',task_out.attempt_count
    )
  );

  return next task_out;
end;
$function$;
