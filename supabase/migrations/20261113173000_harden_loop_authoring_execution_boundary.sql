-- Harden loop-authoring vs execution separation and fenced claim release.
alter table public.tasks
  add column if not exists task_role text not null default 'execution',
  add column if not exists loop_script_status text not null default 'missing',
  add column if not exists loop_author_agent_id text,
  add column if not exists loop_author_claim_token uuid,
  add column if not exists loop_script_version integer not null default 0;

alter table public.tasks
  drop constraint if exists tasks_task_role_check;
alter table public.tasks
  add constraint tasks_task_role_check check (task_role in ('loop_authoring','execution'));

alter table public.tasks
  drop constraint if exists tasks_loop_script_status_check;
alter table public.tasks
  add constraint tasks_loop_script_status_check check (loop_script_status in ('missing','draft','ready','superseded'));

update public.tasks
set loop_script_status='ready'
where loop_script_status='missing'
  and loop_definition is not null
  and jsonb_typeof(loop_definition)='object'
  and loop_definition <> '{}'::jsonb
  and parameter_contract is not null
  and jsonb_typeof(parameter_contract)='object';

create or replace function public.task_ledger_release_claim(
  task_id_in uuid, agent_id_in text, claim_token_in uuid,
  release_status_in text default 'queued', reason_in text default null
) returns public.tasks
language plpgsql set search_path to 'public' as $$
declare task_out public.tasks;
begin
  if release_status_in not in ('queued','abandoned','blocked') then
    raise exception 'invalid release status';
  end if;
  update public.tasks
  set status=release_status_in, claimed_by_agent_id=null, claimed_by_agent_name=null,
      claim_token=null, claimed_at=null, claim_expires_at=null, heartbeat_at=now(),
      heartbeat_context=jsonb_build_object(
        'activity','released',
        'progress',coalesce(reason_in,'Claim released without further execution.'),
        'next_action',case when release_status_in='queued' then 'Return to claimable queue.' else 'Requires ledger review.' end),
      updated_at=now()
  where id=task_id_in and claimed_by_agent_id=agent_id_in
    and claim_token=claim_token_in and status='running'
  returning * into task_out;
  if task_out.id is null then
    raise exception 'Claim not found, expired, or not owned by agent';
  end if;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'released',agent_id_in,coalesce(reason_in,'Claim released.'),
    jsonb_build_object('release_status',release_status_in,'claim_token',claim_token_in));
  return task_out;
end;
$$;

create or replace function public.task_ledger_finalize_loop_script(
  task_id_in uuid, agent_id_in text, claim_token_in uuid,
  loop_definition_in jsonb, parameter_contract_in jsonb,
  completion_parameters_in jsonb default '[]'::jsonb,
  checkpoint_contract_in jsonb default '{}'::jsonb
) returns public.tasks
language plpgsql set search_path to 'public' as $$
declare task_out public.tasks;
begin
  if jsonb_typeof(loop_definition_in)<>'object' or loop_definition_in='{}'::jsonb
    then raise exception 'loop definition must be a non-empty JSON object'; end if;
  if jsonb_typeof(parameter_contract_in)<>'object' or parameter_contract_in='{}'::jsonb
    then raise exception 'parameter contract must be a non-empty JSON object'; end if;
  if jsonb_typeof(completion_parameters_in)<>'array' or jsonb_array_length(completion_parameters_in)>4
    then raise exception 'completion parameters must be an array of at most 4 items'; end if;
  if jsonb_typeof(checkpoint_contract_in)<>'object'
    then raise exception 'checkpoint contract must be a JSON object'; end if;

  update public.tasks
  set task_role='execution', loop_script_status='ready',
      loop_author_agent_id=agent_id_in, loop_author_claim_token=claim_token_in,
      loop_script_version=loop_script_version+1,
      loop_definition=loop_definition_in, parameter_contract=parameter_contract_in,
      completion_parameters=completion_parameters_in,
      metadata=jsonb_set(coalesce(metadata,'{}'::jsonb),
        '{loop_checkpoint_contract}',checkpoint_contract_in,true),
      status='queued', claimed_by_agent_id=null, claimed_by_agent_name=null,
      claim_token=null, claimed_at=null, claim_expires_at=null, heartbeat_at=now(),
      heartbeat_context=jsonb_build_object(
        'activity','loop_contract_ready',
        'progress','Independent loop contract authored and persisted.',
        'next_action','A different agent must execute the task.'),
      current_step='Loop contract ready; awaiting independent executor',
      updated_at=now()
  where id=task_id_in and claimed_by_agent_id=agent_id_in
    and claim_token=claim_token_in and status='running'
    and task_role='loop_authoring'
  returning * into task_out;

  if task_out.id is null then
    raise exception 'Loop-authoring claim not found, expired, or not owned by agent';
  end if;

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'note',agent_id_in,
    'Loop contract authored; task returned for independent execution.',
    jsonb_build_object('event_kind','loop_contract_ready',
      'loop_script_version',task_out.loop_script_version,
      'executor_must_differ_from_author',true));
  return task_out;
end;
$$;

-- Replace the claim function with the loop-role gate.
create or replace function public.task_ledger_claim_next(
  agent_id_in text, agent_name_in text, agent_type_in text default 'worker',
  capabilities_in text[] default '{}', lease_seconds_in integer default 900
) returns setof public.tasks
language plpgsql set search_path to 'public' as $$
declare
  candidate_id uuid; previous_status text; previous_agent_id text;
  previous_heartbeat timestamptz; previous_claim_token uuid;
  previous_heartbeat_context jsonb; previous_loop_author text;
  task_out public.tasks;
  lease_value integer := greatest(600, least(coalesce(lease_seconds_in,600),86400));
begin
  if nullif(btrim(agent_id_in),'') is null or nullif(btrim(agent_name_in),'') is null
    then raise exception 'agent identity is required'; end if;

  select t.id,t.status,t.claimed_by_agent_id,t.heartbeat_at,t.claim_token,
         t.heartbeat_context,t.loop_author_agent_id
    into candidate_id,previous_status,previous_agent_id,previous_heartbeat,
         previous_claim_token,previous_heartbeat_context,previous_loop_author
  from public.tasks t
  where t.status in ('queued','running')
    and t.attempt_count<t.max_attempts
    and (t.status='queued' or
      (t.status='running' and coalesce(t.heartbeat_at,'-infinity'::timestamptz)
        <=now()-interval '5 minutes'))
    and t.required_capabilities<@coalesce(capabilities_in,'{}'::text[])
    and not exists(select 1 from public.tasks child where child.parent_task_id=t.id)
    and (t.parent_task_id is null or not exists(
      select 1 from public.tasks p where p.id=t.parent_task_id
        and p.status in ('failed','cancelled','abandoned','blocked')))
    and (t.goal_id is null or exists(
      select 1 from public.goals g where g.id=t.goal_id and g.status in ('ready','active')))
    and not exists(
      select 1 from public.task_dependencies d
      join public.tasks dep on dep.id=d.depends_on_task_id
      where d.task_id=t.id and d.dependency_type='blocking'
        and (dep.status<>'completed' or dep.verification_status<>'verified'))
    and (t.task_role='loop_authoring' or
      (t.task_role='execution' and t.loop_script_status='ready'
       and (t.loop_author_agent_id is null or t.loop_author_agent_id<>agent_id_in)))
  order by t.priority asc,t.started_at asc
  for update skip locked limit 1;

  if candidate_id is null then return; end if;

  if previous_status='running' and previous_agent_id is not null then
    insert into public.task_events(task_id,event_type,agent_id,message,payload)
    values(candidate_id,'lease_recovered',agent_id_in,
      'Task reclaimed after at least 5 minutes without a heartbeat.',
      jsonb_build_object('previous_agent_id',previous_agent_id,
        'previous_claim_token',previous_claim_token,
        'previous_heartbeat_at',previous_heartbeat,
        'previous_heartbeat_context',coalesce(previous_heartbeat_context,'{}'::jsonb),
        'previous_loop_author_agent_id',previous_loop_author,
        'recovery_reason','heartbeat_timeout','recovery_threshold_minutes',5));
  end if;

  update public.tasks
  set status='running', claimed_by_agent_id=agent_id_in,
      claimed_by_agent_name=agent_name_in, claim_token=gen_random_uuid(),
      claimed_at=now(), claim_expires_at=now()+make_interval(secs=>lease_value),
      attempt_count=attempt_count+1, heartbeat_at=now(), updated_at=now(),
      heartbeat_context=jsonb_build_object('activity','claimed',
        'progress',case when task_role='loop_authoring'
          then 'Loop-contract authoring claimed; executor must be a different agent.'
          else 'Execution task claimed with pre-existing loop contract.' end,
        'next_action',case when task_role='loop_authoring'
          then 'Author and validate loop contract; do not execute task.'
          else 'Execute only against persisted loop contract.' end),
      current_step=case when task_role='loop_authoring'
        then 'Authoring loop contract' else 'Claimed with verified loop contract' end
  where id=candidate_id returning * into task_out;

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_out.id,'claimed',agent_id_in,'Task claimed by worker',
    jsonb_build_object('lease_expires_at',task_out.claim_expires_at,
      'attempt_count',task_out.attempt_count,'task_role',task_out.task_role,
      'loop_script_status',task_out.loop_script_status,
      'loop_script_version',task_out.loop_script_version,
      'heartbeat_policy',public.task_ledger_heartbeat_policy()));
  return next task_out;
end;
$$;
