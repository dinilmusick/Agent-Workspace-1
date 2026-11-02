create or replace function public.goal_ledger_summary(goal_id_in uuid)
returns jsonb language sql stable set search_path to 'public' as $function$
 with g as (select id,name,status,context_version from public.goals where id=goal_id_in),
 leaf as (select t.* from public.tasks t where t.goal_id=goal_id_in and not exists(select 1 from public.tasks c where c.parent_task_id=t.id)),
 counts as (
  select count(*)::int total,
   count(*) filter(where status='completed' and verification_status in ('verified','not_required'))::int completed,
   count(*) filter(where status='failed')::int failed,
   count(*) filter(where status='blocked')::int blocked,
   count(*) filter(where status='running' and claim_expires_at>now())::int active,
   count(*) filter(where status in ('queued','running') and (claim_expires_at is null or claim_expires_at<now())
    and not exists(select 1 from public.task_dependencies d join public.tasks dep on dep.id=d.depends_on_task_id
     where d.task_id=leaf.id and d.dependency_type='blocking' and (dep.status<>'completed' or dep.verification_status<>'verified')))::int ready
  from leaf
 )
 select jsonb_build_object('goal',g,'tasks',jsonb_build_object('total',counts.total,'completed',counts.completed,'failed',counts.failed,'blocked',counts.blocked,'active',counts.active,'ready',counts.ready,'remaining',greatest(counts.total-counts.completed,0)),
  'recommended_workers',least(counts.ready,greatest(1,ceil(counts.ready::numeric/2)::int)))
 from g cross join counts;
$function$;

create or replace function public.goal_ledger_list(status_in text default null)
returns setof public.goals language sql stable set search_path to 'public' as $function$
 select g.* from public.goals g where status_in is null or g.status=status_in order by g.updated_at desc,g.name;
$function$;
