-- Deterministic skill routing and unified project-state matrix.
update public.skills
set metadata = jsonb_set(
  jsonb_set(coalesce(metadata,'{}'::jsonb), '{routing_priority}', to_jsonb(r.priority)),
  '{routing_class}', to_jsonb(r.class_name)
)
from (values
  ('universal-task-router',1000,'router'),
  ('coding-router',900,'router'),
  ('coding-task-lifecycle',850,'lifecycle'),
  ('implementation-push',840,'lifecycle'),
  ('reconciliation-pass',830,'lifecycle'),
  ('skill-creator',820,'lifecycle'),
  ('coding-workflow',700,'specialist'),
  ('feature-implementation',690,'specialist'),
  ('testing-strategy',680,'specialist'),
  ('task-ledger',900,'system')
) r(slug,priority,class_name)
where public.skills.slug=r.slug;

insert into public.skill_triggers(skill_id,trigger_type,value,weight)
select s.id,v.trigger_type,v.value,v.weight
from public.skills s
cross join (values
 ('intent','coding:new_repo',1.00),('intent','coding:feature',1.00),
 ('intent','coding:implementation_push',1.00),('intent','coding:reconciliation',1.00),
 ('phrase','new repository',0.95),('phrase','new repo',0.95),
 ('phrase','implementation push',0.99),('phrase','implementation pass',0.99),
 ('phrase','reconcile all PRs',0.99),('phrase','reconciliation pass',0.99),
 ('phrase','implement a feature',0.90)
) v(trigger_type,value,weight)
where s.slug='coding-task-lifecycle'
and not exists(select 1 from public.skill_triggers t where t.skill_id=s.id and t.trigger_type=v.trigger_type and t.value=v.value);

insert into public.skill_triggers(skill_id,trigger_type,value,weight)
select s.id,v.trigger_type,v.value,v.weight
from public.skills s
cross join (values
 ('intent','skill:create',1.00),('phrase','create a skill',1.00),
 ('phrase','make a new skill',0.98),('phrase','add a skill',0.95),
 ('phrase','missing capability',0.90),('phrase','capability gap',0.90),
 ('phrase','skill does not exist',0.90),('phrase','create the missing skill',0.98)
) v(trigger_type,value,weight)
where s.slug='skill-creator'
and not exists(select 1 from public.skill_triggers t where t.skill_id=s.id and t.trigger_type=v.trigger_type and t.value=v.value);

insert into public.skill_dependencies(skill_id,depends_on_skill_id,dependency_type)
select s.id,d.depends_on_skill_id,'required'
from public.skills s
cross join (values (17),(7),(4),(25)) d(depends_on_skill_id)
where s.slug='coding-task-lifecycle'
and not exists(select 1 from public.skill_dependencies x where x.skill_id=s.id and x.depends_on_skill_id=d.depends_on_skill_id);

drop view if exists public.skill_routing_matrix;
create view public.skill_routing_matrix with (security_invoker=true) as
with required_deps as (
 select skill_id,count(*)::integer required_dependency_count
 from public.skill_dependencies where dependency_type='required' group by skill_id
), missing_deps as (
 select d.skill_id,count(*)::integer missing_required_dependency_count
 from public.skill_dependencies d join public.skills dep on dep.id=d.depends_on_skill_id
 where d.dependency_type='required'
 and (dep.status<>'active' or dep.current_version_id is null or not exists(
   select 1 from public.skill_versions sv where sv.id=dep.current_version_id and sv.is_published=true))
 group by d.skill_id
), required_tools as (
 select skill_id,count(*)::integer required_tool_count
 from public.skill_tool_links where is_required=true group by skill_id
), trigger_stats as (
 select skill_id,count(*)::integer trigger_count,coalesce(max(weight),0)::numeric max_trigger_weight
 from public.skill_triggers group by skill_id
), eval_stats as (
 select skill_id,count(*)::integer evaluation_count,
        coalesce(avg(score) filter(where score is not null),0)::numeric mean_evaluation_score,
        coalesce(bool_or(passed=true),false) has_passed_evaluation
 from public.skill_evaluations group by skill_id
)
select s.id skill_id,s.slug,s.name,s.status,
 coalesce((s.metadata->>'routing_priority')::integer,500) routing_priority,
 coalesce(s.metadata->>'routing_class','specialist') routing_class,
 coalesce(ts.trigger_count,0) trigger_count,
 coalesce(ts.max_trigger_weight,0)::numeric max_trigger_weight,
 coalesce(rd.required_dependency_count,0) required_dependency_count,
 coalesce(md.missing_required_dependency_count,0) missing_required_dependency_count,
 coalesce(rt.required_tool_count,0) required_tool_count,
 coalesce(es.evaluation_count,0) evaluation_count,
 coalesce(es.mean_evaluation_score,0)::numeric mean_evaluation_score,
 coalesce(es.has_passed_evaluation,false) has_passed_evaluation,
 case
  when s.status<>'active' then 'inactive'
  when s.current_version_id is null then 'missing_current_version'
  when not exists(select 1 from public.skill_versions sv where sv.id=s.current_version_id and sv.is_published=true) then 'unpublished'
  when coalesce(ts.trigger_count,0)=0 then 'missing_triggers'
  when coalesce(md.missing_required_dependency_count,0)>0 then 'missing_required_dependencies'
  else 'ready'
 end route_state,
 case
  when s.status<>'active' or s.current_version_id is null then false
  when not exists(select 1 from public.skill_versions sv where sv.id=s.current_version_id and sv.is_published=true) then false
  when coalesce(ts.trigger_count,0)=0 then false
  when coalesce(md.missing_required_dependency_count,0)>0 then false
  else true
 end routable
from public.skills s
left join required_deps rd on rd.skill_id=s.id
left join missing_deps md on md.skill_id=s.id
left join required_tools rt on rt.skill_id=s.id
left join trigger_stats ts on ts.skill_id=s.id
left join eval_stats es on es.skill_id=s.id;

drop view if exists public.agent_state_matrix;
create view public.agent_state_matrix with (security_invoker=true) as
with task_readiness as (
 select t.id,
 case
  when t.status in ('completed','cancelled','abandoned','failed') then 'terminal'
  when t.status='blocked' then 'blocked'
  when t.status='running' then 'running'
  when t.status='waiting' then 'waiting'
  when exists(
   select 1 from public.task_dependencies d join public.tasks dep on dep.id=d.depends_on_task_id
   where d.task_id=t.id and d.dependency_type in ('required','blocking')
   and (dep.status<>'completed' or dep.verification_status not in ('verified','not_required'))
  ) then 'dependency_blocked'
  else 'ready'
 end readiness
 from public.tasks t
), goal_counts as (
 select goal_id,
 count(*) filter(where status not in ('completed','cancelled','abandoned'))::integer remaining_tasks,
 count(*) filter(where status='blocked' or blocker is not null)::integer blocked_tasks,
 count(*) filter(where verification_status='pending')::integer pending_verification
 from public.tasks group by goal_id
)
select 'goal'::text resource_type,g.goal_key resource_id,null::text parent_id,g.name title,g.status,
 case when g.status='blocked' then 5 when g.status='active' then 4 when g.status='ready' then 3 else 1 end priority,
 case when g.status='blocked' then 'goal_blocked' end blocker,
 case when coalesce(gc.remaining_tasks,0)=0 and g.status='completed' then 'verified'
      when coalesce(gc.pending_verification,0)>0 then 'pending' else 'not_started' end verification_status,
 g.created_by_agent_id owner,
 case when g.status='blocked' then 'blocked' when coalesce(gc.blocked_tasks,0)>0 then 'dependency_blocked'
      when g.status in ('planning','ready','active') then 'active' else 'terminal' end readiness,
 g.target->>'type' target_type,g.target->>'id' target_id,'goals' source,g.updated_at,
 jsonb_build_object('remaining_tasks',coalesce(gc.remaining_tasks,0),'blocked_tasks',coalesce(gc.blocked_tasks,0),
 'pending_verification',coalesce(gc.pending_verification,0),'goal_type',g.goal_type) metadata
from public.goals g left join goal_counts gc on gc.goal_id=g.id
union all
select 'task',t.task_key,t.parent_task_id::text,t.task_name,t.status,t.priority,t.blocker,t.verification_status,
 coalesce(t.claimed_by_agent_id,t.agent_id),tr.readiness,t.target->>'type',t.target->>'id','tasks',t.updated_at,
 jsonb_build_object('goal_id',t.goal_id,'current_step',t.current_step,'attempt_count',t.attempt_count,
 'max_attempts',t.max_attempts,'task_type',t.task_type,'required_capabilities',t.required_capabilities)
from public.tasks t join task_readiness tr on tr.id=t.id
union all
select 'obstacle',o.id::text,null::text,o.title,o.status,o.severity,o.problem,null::text,null::text,
 case when o.status='active' then 'blocked' else 'terminal' end,null::text,null::text,'obstacles',o.updated_at,
 jsonb_build_object('occurrence_count',o.occurrence_count,'confidence',o.confidence,
 'root_cause',o.root_cause,'solution',o.solution)
from public.obstacles o;

comment on view public.skill_routing_matrix is 'Deterministic routing health matrix.';
comment on view public.agent_state_matrix is 'Unified project-state matrix for remaining work and blockers.';
