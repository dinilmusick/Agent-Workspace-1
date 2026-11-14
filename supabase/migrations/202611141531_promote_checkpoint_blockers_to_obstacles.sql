-- Deterministic checkpoint-blocker promotion.
-- A blocker enters durable obstacles memory when:
--   distinct reporting agents > 5 OR notoriety > 10.
-- Promotion is idempotent via checkpoint_blockers.metadata.obstacle_id.

create or replace function public.promote_checkpoint_blocker_to_obstacle(
  blocker_id_in uuid,
  task_id_in uuid default null,
  agent_id_in text default null,
  context_in jsonb default '{}'::jsonb,
  evidence_in jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $function$
declare
  b public.checkpoint_blockers;
  t public.tasks;
  distinct_agents integer;
  obstacle_row record;
begin
  select * into b from public.checkpoint_blockers where id = blocker_id_in for update;
  if not found then raise exception 'checkpoint blocker not found'; end if;

  select count(distinct agent_id)::integer into distinct_agents
  from public.checkpoint_blocker_occurrences
  where blocker_id = blocker_id_in;

  if distinct_agents <= 5 and b.notoriety <= 10 then
    return jsonb_build_object('promoted', false, 'reason', 'threshold_not_reached',
      'distinct_agents', distinct_agents, 'notoriety', b.notoriety);
  end if;

  if coalesce(b.metadata->>'obstacle_id','') <> '' then
    return jsonb_build_object('promoted', true, 'already_promoted', true,
      'obstacle_id', b.metadata->>'obstacle_id',
      'distinct_agents', distinct_agents, 'notoriety', b.notoriety);
  end if;

  if task_id_in is not null then
    select * into t from public.tasks where id = task_id_in;
  end if;

  select * into obstacle_row
  from public.upsert_obstacle(
    'Checkpoint blocker: ' || b.text,
    b.text,
    array['checkpoint-blocker'],
    null,
    b.resolution,
    array['checkpoint-blocker','notoriety-' || b.notoriety::text],
    case when b.notoriety > 10 then 5 else 4 end,
    least(1.0, greatest(0.5, b.notoriety::numeric / 10.0)),
    null,
    case when t.id is not null then t.goal_id else null end,
    task_id_in,
    agent_id_in,
    coalesce(context_in,'{}'::jsonb)::text,
    b.text,
    b.resolution,
    coalesce(evidence_in,'{}'::jsonb),
    0.82
  );

  update public.checkpoint_blockers
  set metadata = coalesce(metadata,'{}'::jsonb) ||
    jsonb_build_object(
      'obstacle_id', obstacle_row.obstacle_id,
      'promoted_at', now(),
      'promotion_reason', case
        when distinct_agents > 5 and b.notoriety > 10 then 'agent_count_and_notoriety'
        when distinct_agents > 5 then 'agent_count'
        else 'notoriety'
      end,
      'distinct_agent_count', distinct_agents
    ),
    updated_at = now()
  where id = blocker_id_in;

  return jsonb_build_object('promoted', true, 'already_promoted', false,
    'obstacle_id', obstacle_row.obstacle_id,
    'obstacle_occurrence_id', obstacle_row.occurrence_id,
    'distinct_agents', distinct_agents, 'notoriety', b.notoriety);
end;
$function$;

-- Wire promotion into every newly recorded blocker occurrence.
create or replace function public.report_checkpoint_blocker(
  task_id_in uuid,
  checkpoint_index_in smallint,
  blocker_text_in text,
  agent_id_in text,
  claim_token_in uuid default null,
  context_in jsonb default '{}'::jsonb,
  evidence_in jsonb default '[]'::jsonb
) returns jsonb
language plpgsql
set search_path = public
as $function$
declare
  t public.tasks; c jsonb; normalized text; blocker public.checkpoint_blockers;
  occurrence_inserted boolean; blocker_entry jsonb; blockers jsonb; promotion jsonb;
begin
  if checkpoint_index_in not between 0 and 3 then raise exception 'checkpoint index must be between 0 and 3'; end if;
  if nullif(btrim(blocker_text_in),'') is null then raise exception 'blocker text is required'; end if;
  if nullif(btrim(agent_id_in),'') is null then raise exception 'agent_id is required'; end if;

  select * into t from public.tasks where id=task_id_in for update;
  if not found then raise exception 'task not found'; end if;
  if t.execution_model <> 'bounded-v2' then raise exception 'task is not bounded-v2'; end if;
  if checkpoint_index_in >= jsonb_array_length(t.checkpoints) then raise exception 'checkpoint does not exist'; end if;
  if claim_token_in is not null and
     (t.claimed_by_agent_id is distinct from agent_id_in or t.claim_token is distinct from claim_token_in)
  then raise exception 'claim token does not fence the current task owner'; end if;

  normalized:=public.normalize_checkpoint_blocker_text(blocker_text_in);
  if normalized='' then raise exception 'blocker text normalizes to empty'; end if;

  insert into public.checkpoint_blockers(blocker_key,normalized_text,text,status)
  values('blocker-'||substr(md5(normalized),1,16),normalized,btrim(blocker_text_in),'active')
  on conflict(normalized_text) do update set
    text=excluded.text,status='active',last_reported_at=now(),updated_at=now(),
    resolved_at=null,resolved_by_agent_id=null,resolution=null
  returning * into blocker;

  insert into public.checkpoint_blocker_occurrences(
    blocker_id,task_id,checkpoint_index,agent_id,attempt_count,context,evidence)
  values(
    blocker.id,task_id_in,checkpoint_index_in,agent_id_in,t.attempt_count,
    coalesce(context_in,'{}'::jsonb),coalesce(evidence_in,'[]'::jsonb))
  on conflict(blocker_id,task_id,checkpoint_index,agent_id,attempt_count) do nothing;
  occurrence_inserted:=found;

  if occurrence_inserted then
    update public.checkpoint_blockers
    set notoriety=(select count(*)::integer from public.checkpoint_blocker_occurrences
                   where blocker_id=blocker.id),
        last_reported_at=now(),updated_at=now()
    where id=blocker.id returning * into blocker;

    promotion := public.promote_checkpoint_blocker_to_obstacle(
      blocker.id, task_id_in, agent_id_in, context_in,
      jsonb_build_object('checkpoint_index',checkpoint_index_in,
                         'evidence',coalesce(evidence_in,'[]'::jsonb)));
  else
    promotion := jsonb_build_object('promoted',false,'reason','duplicate_occurrence');
  end if;

  c:=t.checkpoints->checkpoint_index_in;
  blockers:=coalesce(c->'blockers','[]'::jsonb);
  blocker_entry:=jsonb_build_object(
    'blocker_id',blocker.id,'blocker_key',blocker.blocker_key,'text',blocker.text,
    'notoriety',blocker.notoriety,'status','active','reported_by_agent_id',agent_id_in,
    'last_reported_at',blocker.last_reported_at,
    'context',coalesce(context_in,'{}'::jsonb),
    'evidence',coalesce(evidence_in,'[]'::jsonb),
    'obstacle_promotion',promotion);

  if exists(select 1 from jsonb_array_elements(blockers) x
            where x->>'blocker_id'=blocker.id::text) then
    select coalesce(jsonb_agg(
      case when x->>'blocker_id'=blocker.id::text then blocker_entry else x end),'[]'::jsonb)
    into blockers from jsonb_array_elements(blockers) x;
  else
    blockers:=blockers||jsonb_build_array(blocker_entry);
  end if;

  c:=c||jsonb_build_object('blockers',blockers,'blocker_notoriety',blocker.notoriety);

  update public.tasks
  set checkpoints=jsonb_set(t.checkpoints,array[checkpoint_index_in::text],c,false),
      blocker=blocker.text,
      blocker_notoriety=greatest(coalesce(blocker_notoriety,0),blocker.notoriety),
      status='blocked',updated_at=now(),
      heartbeat_context=coalesce(heartbeat_context,'{}'::jsonb)||
        jsonb_build_object('blocker_id',blocker.id,'blocker_key',blocker.blocker_key,
          'blocker_notoriety',blocker.notoriety,'blocked_at',now())
  where id=task_id_in;

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'blocked',agent_id_in,
    'Checkpoint blocker recorded; task blocked until the blocker is resolved.',
    jsonb_build_object('checkpoint_index',checkpoint_index_in,'blocker_id',blocker.id,
      'blocker_key',blocker.blocker_key,'notoriety',blocker.notoriety,
      'occurrence_inserted',occurrence_inserted,'obstacle_promotion',promotion));

  return jsonb_build_object(
    'task_id',task_id_in,'checkpoint_index',checkpoint_index_in,'blocker_id',blocker.id,
    'blocker_key',blocker.blocker_key,'notoriety',blocker.notoriety,
    'distinct_agent_count',(select count(distinct agent_id)
      from public.checkpoint_blocker_occurrences where blocker_id=blocker.id),
    'notorious',blocker.notoriety>5,'obstacle_promotion',promotion,
    'occurrence_inserted',occurrence_inserted);
end;
$function$;
