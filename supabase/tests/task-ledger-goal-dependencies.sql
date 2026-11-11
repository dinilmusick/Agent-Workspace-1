-- Rollback-only integration regression for goal-level dependency gates.
-- Run through the trusted Supabase service-role SQL connector.
begin;
do $test$
declare
  dependent_goal public.goals;
  prerequisite_goal public.goals;
  advisory_goal public.goals;
  advisory_dependent public.goals;
  blocked_activation boolean := false;
  blocked_claim boolean := false;
  cycle_rejected boolean := false;
  task_id uuid;
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

  begin
    update public.goals set status = 'active' where id = dependent_goal.id;
  exception when others then
    if sqlerrm like 'goal is locked:%' then blocked_activation := true;
    else raise;
    end if;
  end;
  if not blocked_activation then
    raise exception 'FAIL: blocking prerequisite did not prevent goal activation';
  end if;

  insert into public.tasks(agent_id, agent_name, task_name, goal_id)
    values ('ledger-regression-test', 'ledger-regression-test', 'blocked task', dependent_goal.id)
    returning id into task_id;
  begin
    update public.tasks set status = 'running' where id = task_id;
  exception when others then
    if sqlerrm like 'task claim denied:%' then blocked_claim := true;
    else raise;
    end if;
  end;
  if not blocked_claim then
    raise exception 'FAIL: blocking prerequisite did not prevent task claim';
  end if;

  begin
    insert into public.goal_dependencies(goal_id, depends_on_goal_id, dependency_type)
      values (prerequisite_goal.id, dependent_goal.id, 'blocking');
  exception when others then
    if sqlerrm = 'goal dependency would create a blocking cycle' then cycle_rejected := true;
    else raise;
    end if;
  end;
  if not cycle_rejected then
    raise exception 'FAIL: blocking dependency cycle was accepted';
  end if;

  update public.goals set status = 'active' where id = advisory_dependent.id;
  if (select status from public.goals where id = advisory_dependent.id) <> 'active' then
    raise exception 'FAIL: advisory dependency incorrectly blocked activation';
  end if;
  raise notice 'PASS: blocking activation gate; blocking task-claim gate; cycle rejection; advisory non-blocking behavior';
end;
$test$;
rollback;


-- Cross-Vision edges are invalid; fixtures are rolled back.
begin;
do $vision_scope_test$
declare
  vision_a public.visions; vision_b public.visions;
  target_a public.vision_targets; target_b public.vision_targets;
  goal_a public.goals; goal_b public.goals;
  rejected boolean := false;
begin
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
    returning * into goal_a;
  insert into public.goals(name, created_by_agent_id, target)
    values ('__goal_dependency_vision_goal_b__', 'ledger-regression-test',
      '{"type":"application","id":"goal-dependency-vision-b"}')
    returning * into goal_b;
  perform public.vision_ledger_link_goal(target_a.id, goal_a.id);
  perform public.vision_ledger_link_goal(target_b.id, goal_b.id);
  begin
    insert into public.goal_dependencies(goal_id, depends_on_goal_id, dependency_type)
      values (goal_b.id, goal_a.id, 'blocking');
  exception when others then
    if sqlerrm = 'goal dependencies must connect goals within the same Vision' then
      rejected := true;
    else
      raise;
    end if;
  end;
  if not rejected then raise exception 'FAIL: cross-Vision dependency was accepted'; end if;
  raise notice 'PASS: cross-Vision dependency rejected';
end;
$vision_scope_test$;
rollback;
