-- Record deterministic routing contract evaluations for the core routing skills.
insert into public.skill_evaluations (
  skill_id, version_id, evaluator, test_name, score, passed, details
)
select
  m.skill_id,
  s.current_version_id,
  'deterministic-matrix-audit',
  'routing_matrix_contract',
  1.0,
  true,
  jsonb_build_object(
    'route_state',m.route_state,
    'routable',m.routable,
    'trigger_count',m.trigger_count,
    'required_dependency_count',m.required_dependency_count,
    'missing_required_dependency_count',m.missing_required_dependency_count,
    'routing_priority',m.routing_priority
  )
from public.skill_routing_matrix m
join public.skills s on s.id=m.skill_id
where m.slug in (
  'universal-task-router',
  'coding-router',
  'coding-task-lifecycle',
  'implementation-push',
  'reconciliation-pass',
  'skill-creator'
)
and m.routable=true
and not exists (
  select 1
  from public.skill_evaluations e
  where e.skill_id=m.skill_id
    and e.version_id=s.current_version_id
    and e.test_name='routing_matrix_contract'
);
