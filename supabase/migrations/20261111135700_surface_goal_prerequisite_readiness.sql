create or replace view public.agent_state_matrix with (security_invoker=true) as
with task_readiness as (
 select t.id, case
  when t.status in ('completed','cancelled','abandoned','failed') then 'terminal'
  when t.status='blocked' then 'blocked'
  when t.status='running' then 'running'
  when t.status='waiting' then 'waiting'
  when t.goal_id is not null and exists (select 1 from public.goal_dependencies gd join public.goals p on p.id=gd.depends_on_goal_id where gd.goal_id=t.goal_id and gd.dependency_type='blocking' and (p.status<>'completed' or public.goal_has_unverified_descendant_tasks(p.id))) then 'dependency_blocked'
  when exists (select 1 from public.task_dependencies d join public.tasks dep on dep.id=d.depends_on_task_id where d.task_id=t.id and d.dependency_type in ('required','blocking') and (dep.status<>'completed' or dep.verification_status not in ('verified','not_required'))) then 'dependency_blocked'
  else 'ready' end readiness from public.tasks t
), goal_counts as (
 select goal_id,count(*) filter(where status not in ('completed','cancelled','abandoned'))::integer remaining_tasks,
  count(*) filter(where status='blocked' or blocker is not null)::integer blocked_tasks,
  count(*) filter(where verification_status='pending')::integer pending_verification from public.tasks group by goal_id
)
select 'goal'::text resource_type,g.goal_key resource_id,null::text parent_id,g.name title,g.status,
 case when g.status='blocked' then 5 when g.status='active' then 4 when g.status='ready' then 3 else 1 end priority,
 case when g.status='blocked' then 'goal_blocked' when exists(select 1 from public.goal_dependencies gd join public.goals p on p.id=gd.depends_on_goal_id where gd.goal_id=g.id and gd.dependency_type='blocking' and (p.status<>'completed' or public.goal_has_unverified_descendant_tasks(p.id))) then 'prerequisite_goal_incomplete' else null end blocker,
 case when coalesce(gc.remaining_tasks,0)=0 and g.status='completed' then 'verified' when coalesce(gc.pending_verification,0)>0 then 'pending' else 'not_started' end verification_status,
 g.created_by_agent_id owner,
 case when g.status='blocked' then 'blocked' when exists(select 1 from public.goal_dependencies gd join public.goals p on p.id=gd.depends_on_goal_id where gd.goal_id=g.id and gd.dependency_type='blocking' and (p.status<>'completed' or public.goal_has_unverified_descendant_tasks(p.id))) then 'dependency_blocked' when coalesce(gc.blocked_tasks,0)>0 then 'dependency_blocked' when g.status in ('planning','ready','active') then 'active' else 'terminal' end readiness,
 g.target->>'type' target_type,g.target->>'id' target_id,'goals' source,g.updated_at,
 jsonb_build_object('remaining_tasks',coalesce(gc.remaining_tasks,0),'blocked_tasks',coalesce(gc.blocked_tasks,0),'pending_verification',coalesce(gc.pending_verification,0),'goal_type',g.goal_type,'blocking_prerequisites',(select coalesce(jsonb_agg(jsonb_build_object('goal_key',p.goal_key,'status',p.status)),'[]'::jsonb) from public.goal_dependencies gd join public.goals p on p.id=gd.depends_on_goal_id where gd.goal_id=g.id and gd.dependency_type='blocking')) metadata
from public.goals g left join goal_counts gc on gc.goal_id=g.id
union all
select 'task',t.task_key,t.parent_task_id::text,t.task_name,t.status,t.priority,t.blocker,t.verification_status,coalesce(t.claimed_by_agent_id,t.agent_id),tr.readiness,t.target->>'type',t.target->>'id','tasks',t.updated_at,jsonb_build_object('goal_id',t.goal_id,'current_step',t.current_step,'attempt_count',t.attempt_count,'max_attempts',t.max_attempts,'task_type',t.task_type,'required_capabilities',t.required_capabilities)
from public.tasks t join task_readiness tr on tr.id=t.id
union all
select 'obstacle',o.id::text,null::text,o.title,o.status,o.severity,o.problem,null::text,null::text,case when o.status='active' then 'blocked' else 'terminal' end,null::text,null::text,'obstacles',o.updated_at,jsonb_build_object('occurrence_count',o.occurrence_count,'confidence',o.confidence,'root_cause',o.root_cause,'solution',o.solution)
from public.obstacles o;