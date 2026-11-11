-- Rollback-only SQL integration tests for goal prerequisite enforcement.
-- Executed by .github/workflows/database-integration.yml with psql -v ON_ERROR_STOP=1.
begin;
do $test$
declare
  a public.goals; b public.goals; c public.goals; d public.goals;
  task_id uuid;
  blocked_activation boolean := false;
  blocked_completion boolean := false;
  blocked_claim boolean := false;
  cycle_rejected boolean := false;
  advisory_allowed boolean := false;
  v1 public.visions; v2 public.visions;
  t1 public.vision_targets; t2 public.vision_targets;
  ga public.goals; gb public.goals;
  cross_vision_rejected boolean := false;
begin
  insert into public.goals(name, created_by_agent_id)
    values ('__goal_dep_test_a__','ledger-test') returning * into a;
  insert into public.goals(name, created_by_agent_id)
    values ('__goal_dep_test_b__','ledger-test') returning * into b;
  insert into public.goals(name, created_by_agent_id)
    values ('__goal_dep_test_c__','ledger-test') returning * into c;
  insert into public.goals(name, created_by_agent_id)
    values ('__goal_dep_test_d__','ledger-test') returning * into d;

  perform public.goal_ledger_add_dependency(a.goal_key,b.goal_key,'blocking','ledger-test');
  perform public.goal_ledger_add_dependency(a.goal_key,c.goal_key,'advisory','ledger-test');
  perform public.goal_ledger_add_dependency(d.goal_key,c.goal_key,'advisory','ledger-test');

  begin
    update public.goals set status='active' where id=a.id;
  exception when others then
    if sqlerrm like 'goal is locked:%' then blocked_activation:=true; else raise; end if;
  end;
  if not blocked_activation then raise exception 'FAIL: blocking prerequisite did not prevent goal activation'; end if;

  begin
    update public.goals set status='completed' where id=a.id;
  exception when others then
    if sqlerrm like 'goal is locked:%' then blocked_completion:=true; else raise; end if;
  end;
  if not blocked_completion then raise exception 'FAIL: blocking prerequisite did not prevent goal completion'; end if;

  insert into public.tasks(agent_id,agent_name,task_name,goal_id)
    values ('ledger-test','ledger-test','blocked task',a.id) returning id into task_id;
  begin
    update public.tasks set status='running' where id=task_id;
  exception when others then
    if sqlerrm like 'task claim denied:%' then blocked_claim:=true; else raise; end if;
  end;
  if not blocked_claim then raise exception 'FAIL: blocking prerequisite did not prevent task claim'; end if;

  begin
    insert into public.goal_dependencies(goal_id,depends_on_goal_id,dependency_type)
      values (b.id,a.id,'blocking');
  exception when others then
    if sqlerrm='goal dependency would create a blocking cycle' then cycle_rejected:=true; else raise; end if;
  end;
  if not cycle_rejected then raise exception 'FAIL: blocking dependency cycle was accepted'; end if;

  update public.goals set status='active' where id=d.id;
  advisory_allowed := (select status='active' from public.goals where id=d.id);
  if not advisory_allowed then raise exception 'FAIL: advisory dependency incorrectly blocked activation'; end if;

  v1:=public.vision_ledger_create('__vision_dep_test_1__','','{"type":"application","id":"vision-a"}','ledger-test');
  t1:=public.vision_ledger_add_target(v1.id,null,'phase a','{"type":"application","id":"vision-a"}');
  v2:=public.vision_ledger_create('__vision_dep_test_2__','','{"type":"application","id":"vision-b"}','ledger-test');
  t2:=public.vision_ledger_add_target(v2.id,null,'phase b','{"type":"application","id":"vision-b"}');
  insert into public.goals(name,created_by_agent_id,target)
    values ('__vision_goal_a__','ledger-test','{"type":"application","id":"vision-a"}') returning * into ga;
  insert into public.goals(name,created_by_agent_id,target)
    values ('__vision_goal_b__','ledger-test','{"type":"application","id":"vision-b"}') returning * into gb;
  perform public.vision_ledger_link_goal(t1.id,ga.id);
  perform public.vision_ledger_link_goal(t2.id,gb.id);
  begin
    insert into public.goal_dependencies(goal_id,depends_on_goal_id,dependency_type)
      values(gb.id,ga.id,'blocking');
  exception when others then
    if sqlerrm='goal dependencies must connect goals within the same Vision' then cross_vision_rejected:=true; else raise; end if;
  end;
  if not cross_vision_rejected then raise exception 'FAIL: cross-Vision dependency was accepted'; end if;

  raise notice 'PASS: activation gate; completion gate; task claim gate; cycle rejection; advisory non-blocking; cross-Vision rejection';
end;
$test$;
rollback;
