-- Original recovery event and unfinished-goal overview migration.
-- The later 20261102203128 migration tightens every claim entry point to the
-- heartbeat-only 60-minute threshold.

alter table public.task_events drop constraint if exists task_events_event_type_check;
alter table public.task_events add constraint task_events_event_type_check
  check (event_type = any (array[
    'registered','started','heartbeat','progress','tagged','blocked','unblocked',
    'completed','failed','cancelled','abandoned','reopened','note','claimed',
    'released','result_submitted','verified','verification_rejected',
    'iteration_recorded','loop_iteration_recorded','dependency_added','tree_created',
    'lease_recovered'
  ]::text[]));

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
    g.id,g.goal_key,g.name,g.description,g.status,g.tags,
    g.acceptance_criteria,g.context_version,g.updated_at,
    (
      select jsonb_build_object(
        'total',count(*)::int,
        'queued',count(*) filter(where t.status='queued')::int,
        'running',count(*) filter(where t.status='running')::int,
        'blocked',count(*) filter(where t.status='blocked')::int,
        'failed',count(*) filter(where t.status='failed')::int,
        'completed',count(*) filter(where t.status='completed')::int,
        'awaiting_verification',count(*) filter(
          where t.status='completed'
            and coalesce(t.verification_status,'pending') not in ('verified','not_required')
        )::int
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
        'heartbeat_stale',t.status='running' and t.heartbeat_at<=now()-interval '60 minutes',
        'current_step',t.current_step,
        'blocker',t.blocker,
        'verification_status',t.verification_status,
        'parent_task_id',t.parent_task_id
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
      'context_version',context_version,'updated_at',updated_at,
      'task_counts',task_counts,'tasks',tasks
    ) order by updated_at desc,name)
    from goal_rows
  ),'[]'::jsonb)
);
$function$;

grant execute on function public.goal_ledger_overview(text[]) to anon,authenticated,service_role;
