-- Allow authorized RPC callers to read the complete goal overview without granting direct table access.
create or replace function public.goal_ledger_overview(tags_in text[] default null)
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
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
