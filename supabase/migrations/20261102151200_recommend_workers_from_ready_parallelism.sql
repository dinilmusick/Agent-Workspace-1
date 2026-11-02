create or replace function public.goal_ledger_summary(goal_id_in uuid)
returns jsonb language sql stable security invoker set search_path to 'public' as $function$
 with g as (
  select id,name,status,context_version,metadata from public.goals where id=goal_id_in
 ), leaf as (
  select t.* from public.tasks t where t.goal_id=goal_id_in
   and not exists(select 1 from public.tasks c where c.parent_task_id=t.id)
 ), counts as (
  select count(*)::int total,
   count(*) filter(where status='completed' and verification_status in ('verified','not_required'))::int completed,
   count(*) filter(where status='failed')::int failed,
   count(*) filter(where status='blocked')::int blocked,
   count(*) filter(where status='running' and claim_expires_at>now())::int active,
   count(*) filter(where status in ('queued','running') and (claim_expires_at is null or claim_expires_at<now())
    and not exists(select 1 from public.task_dependencies d join public.tasks dep on dep.id=d.depends_on_task_id
     where d.task_id=leaf.id and d.dependency_type='blocking'
      and (dep.status<>'completed' or dep.verification_status<>'verified')))::int ready
  from leaf
 ), policy as (
  select case when (g.metadata#>>'{execution_policy,max_parallel_workers}') ~ '^[0-9]+$'
   then (g.metadata#>>'{execution_policy,max_parallel_workers}')::int else null end max_parallel_workers
  from g
 )
 select jsonb_build_object(
  'goal',jsonb_build_object('id',g.id,'name',g.name,'status',g.status,'context_version',g.context_version),
  'tasks',jsonb_build_object('total',counts.total,'completed',counts.completed,'failed',counts.failed,
   'blocked',counts.blocked,'active',counts.active,'ready',counts.ready,
   'remaining',greatest(counts.total-counts.completed,0)),
  'max_parallel_workers',counts.ready,
  'recommended_workers',least(counts.ready,coalesce(policy.max_parallel_workers,counts.ready)),
  'recommendation_reason','One worker per currently ready independent leaf task, bounded by the goal execution_policy.max_parallel_workers when configured.'
 )
 from g cross join counts cross join policy;
$function$;
