-- Rollback-only integration coverage for goal prerequisites. Run with the trusted database test role.
begin;
do $test$
declare a uuid; b uuid; c uuid; claim_denied boolean:=false; cycle_denied boolean:=false; unlock_succeeded boolean:=false;
begin
  insert into public.goals(name,created_by_agent_id,status) values ('__ledger_gate_a','ledger-test','ready') returning id into a;
  insert into public.goals(name,created_by_agent_id,status) values ('__ledger_gate_b','ledger-test','ready') returning id into b;
  insert into public.goals(name,created_by_agent_id,status) values ('__ledger_gate_c','ledger-test','ready') returning id into c;
  insert into public.goal_dependencies(goal_id,depends_on_goal_id,dependency_type) values (a,b,'blocking');
  insert into public.goal_dependencies(goal_id,depends_on_goal_id,dependency_type) values (c,b,'advisory');
  begin
    insert into public.tasks(agent_id,agent_name,task_name,status,goal_id) values ('ledger-test','ledger-test','__blocked_claim','running',a);
  exception when others then if sqlerrm like 'task claim denied:%' then claim_denied:=true; else raise; end if; end;
  begin
    insert into public.goal_dependencies(goal_id,depends_on_goal_id,dependency_type) values (b,a,'blocking');
  exception when others then if sqlerrm like 'goal dependency would create a blocking cycle%' then cycle_denied:=true; else raise; end if; end;
  if not claim_denied then raise exception 'TEST FAILED: blocking prerequisite did not deny task claim'; end if;
  if not cycle_denied then raise exception 'TEST FAILED: blocking cycle was not rejected'; end if;
  update public.goals set status='completed' where id=b;
  begin
    insert into public.tasks(agent_id,agent_name,task_name,status,goal_id) values ('ledger-test','ledger-test','__unblocked_claim','running',a);
    unlock_succeeded:=true;
  exception when others then raise exception 'TEST FAILED: prerequisite completion did not unlock task: %',sqlerrm; end;
  if not unlock_succeeded then raise exception 'TEST FAILED: prerequisite completion did not unlock task'; end if;
  raise notice 'PASS: blocking claim gate; cycle rejection; advisory edge accepted; verified prerequisite completion unlocks dependent goal';
end $test$;
rollback;