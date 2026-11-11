-- pgTAP integration regression for goal-level prerequisite gates.
-- The whole fixture is transactional and is rolled back after assertions.
begin;
select plan(6);

create temporary table goal_dependency_test_fixtures (
  dependent_goal_id uuid,
  prerequisite_goal_id uuid,
  advisory_goal_id uuid,
  advisory_dependent_goal_id uuid,
  task_id uuid,
  cross_vision_goal_id uuid,
  cross_vision_prerequisite_id uuid
) on commit drop;

do $setup$
declare
  dependent_goal public.goals;
  prerequisite_goal public.goals;
  advisory_goal public.goals;
  advisory_dependent_goal public.goals;
  vision_a public.visions;
  vision_b public.visions;
  target_a public.vision_targets;
  target_b public.vision_targets;
  cross_goal_a public.goals;
  cross_goal_b public.goals;
  test_task_id uuid;
begin
  insert into public.goals(name, created_by_agent_id)
    values ('__goal_dependency_test_dependent__', 'ledger-regression-test')
    returning * into dependent_goal;
  insert into public.goals(name, created_by_agent_id)
    values ('__goal_dependency_test_prerequisite__', 'ledger-regression-test')
    returning * into prerequisite_goal;
  insert into public.goals(name, created_by_agent_id)
    values ('__goal_dependency_test_advisory__', 'ledger-regression-test')
    returning * into advisory_goal;
  insert into public.goals(name, created_by_agent_id)
    values ('__goal_dependency_test_advisory_dependent__', 'ledger-regression-test')
    returning * into advisory_dependent;

  perform public.goal_ledger_add_dependency(
    dependent_goal.goal_key, prerequisite_goal.goal_key, 'blocking', 'ledger-regression-test'
  );
  perform public.goal_ledger_add_dependency(
    dependent_goal.goal_key, advisory_goal.goal_key, 'advisory', 'ledger-regression-test'
  );
  perform public.goal_ledger_add_dependency(
    advisory_dependent.goal_key, advisory_goal.goal_key, 'advisory', 'ledger-regression-test'
  );

  insert into public.tasks(agent_id, agent_name, task_name, goal_id)
    values ('ledger-regression-test', 'ledger-regression-test', 'blocked task', dependent_goal.id)
    returning id into test_task_id;

  vision_a := public.vision_ledger_create(
    '__goal_dependency_vision_a__', '',
    '{"type":"application","id":"goal-dependency-vision-a"}',
    'ledger-regression-test'
  );
  target_a := public.vision_ledger_add_target(
    vision_a.id, null, 'phase A',
    '{"type":"application","id":"goal-dependency-vision-a"}'
  );
  vision_b := public.vision_ledger_create(
    '__goal_dependency_vision_b__', '',
    '{"type":"application","id":"goal-dependency-vision-b"}',
    'ledger-regression-test'
  );
  target_b := public.vision_ledger_add_target(
    vision_b.id, null, 'phase B',
    '{"type":"application","id":"goal-dependency-vision-b"}'
  );
  insert into public.goals(name, created_by_agent_id, target)
    values ('__goal_dependency_vision_goal_a__', 'ledger-regression-test',
      '{"type":"application","id":"goal-dependency-vision-a"}')
    returning * into cross_goal_a;
  insert into public.goals(name, created_by_agent_id, target)
    values ('__goal_dependency_vision_goal_b__', 'ledger-regression-test',
      '{"type":"application","id":"goal-dependency-vision-b"}')
    returning * into cross_goal_b;
  perform public.vision_ledger_link_goal(target_a.id, cross_goal_a.id);
  perform public.vision_ledger_link_goal(target_b.id, cross_goal_b.id);

  insert into goal_dependency_test_fixtures values (
    dependent_goal.id, prerequisite_goal.id, advisory_goal.id,
    advisory_dependent.id, test_task_id, cross_goal_b.id, cross_goal_a.id
  );
end;
$setup$;

select throws_ok(
  format('update public.goals set status = ''active'' where id = %L',
    (select dependent_goal_id from goal_dependency_test_fixtures)),
  'P0001',
  'goal is locked: all blocking prerequisite goals must be completed and verified before activation or completion',
  'blocking prerequisite prevents goal activation'
);

select throws_ok(
  format('update public.goals set status = ''completed'' where id = %L',
    (select dependent_goal_id from goal_dependency_test_fixtures)),
  'P0001',
  'goal is locked: all blocking prerequisite goals must be completed and verified before activation or completion',
  'blocking prerequisite prevents goal completion'
);

select throws_ok(
  format('update public.tasks set status = ''running'' where id = %L',
    (select task_id from goal_dependency_test_fixtures)),
  'P0001',
  'task claim denied: one or more blocking prerequisite goals are not completed and verified',
  'blocking prerequisite prevents task claim'
);

select throws_ok(
  format(
    'insert into public.goal_dependencies(goal_id, depends_on_goal_id, dependency_type) values (%L, %L, ''blocking'')',
    (select prerequisite_goal_id from goal_dependency_test_fixtures),
    (select dependent_goal_id from goal_dependency_test_fixtures)
  ),
  'P0001',
  'goal dependency would create a blocking cycle',
  'blocking cycle is rejected'
);

select lives_ok(
  format('update public.goals set status = ''active'' where id = %L',
    (select advisory_dependent_goal_id from goal_dependency_test_fixtures)),
  'advisory dependency does not block activation'
);

select throws_ok(
  format(
    'insert into public.goal_dependencies(goal_id, depends_on_goal_id, dependency_type) values (%L, %L, ''blocking'')',
    (select cross_vision_goal_id from goal_dependency_test_fixtures),
    (select cross_vision_prerequisite_id from goal_dependency_test_fixtures)
  ),
  'P0001',
  'goal dependencies must connect goals within the same Vision',
  'cross-Vision dependency is rejected'
);

select * from finish();
rollback;
