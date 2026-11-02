-- Verifies the global goal overview returns enough context for a new agent to brief all work.
begin;
do $test$
declare
  goal_key_value text := 'overview-fixture-' || replace(gen_random_uuid()::text,'-','');
  created jsonb;
  goal_id_value uuid;
  overview jsonb;
  goal_row jsonb;
  task_row jsonb;
begin
  created := public.goal_ledger_create_with_tasks(
    goal_key_value,
    'Goal Overview Fixture',
    jsonb_build_object('repository','Agent-Workspace-1','purpose','overview integration test'),
    'Inspect all goal and task context before claiming work.',
    jsonb_build_array('Goal context is visible','Task acceptance criteria are visible'),
    'overview-test-agent',
    jsonb_build_object(
      'name','Overview fixture task',
      'acceptance_criteria',jsonb_build_array('Task criterion is visible'),
      'verification_plan',jsonb_build_object('method','independent SQL assertion'),
      'loop',jsonb_build_object(
        'enabled',true,
        'objective','Verify full overview output',
        'input_contract',jsonb_build_object('type','input'),
        'output_contract',jsonb_build_object('type','result'),
        'transformation','Create a goal fixture, read the overview, and verify every required field.',
        'observation',jsonb_build_object('required',jsonb_build_array('test_results','runtime_observations','known_gaps')),
        'evaluation',jsonb_build_object('criteria','overview contains full task contract'),
        'revision_policy',jsonb_build_object('on_failure','Diagnose and retry failed assertions','max_revisions',2),
        'initial_input',jsonb_build_object('phase','inspect'),
        'tools',jsonb_build_array('Supabase PostgreSQL','SQL integration test'),
        'iteration_policy',jsonb_build_object('mode','persistent','heartbeat_required',true,'continue_on_partial_success',true,'record_observation_each_iteration',true),
        'stop_conditions',jsonb_build_array('all fields present'),
        'max_iterations',2
      )
    ),
    null,
    jsonb_build_object('fixture',true)
  );
  goal_id_value := (created->'goal'->>'id')::uuid;
  if goal_id_value is null then raise exception 'Fixture goal was not created'; end if;

  overview := public.goal_ledger_overview(null);
  select item into goal_row
  from jsonb_array_elements(overview->'goals') item
  where item->>'id'=goal_id_value::text;
  if goal_row is null then raise exception 'Overview omitted a visible goal'; end if;
  if goal_row->'context'->>'purpose'<>'overview integration test' then
    raise exception 'Overview omitted goal context';
  end if;
  if goal_row->'goal_loop_definition' is null or goal_row->'goal_loop_state' is null then
    raise exception 'Overview omitted goal loop contract/state';
  end if;
  select item into task_row from jsonb_array_elements(goal_row->'tasks') item
  where item->>'task_name'='Overview fixture task';
  if task_row is null then raise exception 'Overview omitted the task tree'; end if;
  if task_row->'acceptance_criteria' is null or task_row->'loop_definition' is null then
    raise exception 'Overview omitted task acceptance criteria or loop definition';
  end if;
  if jsonb_typeof(task_row->'dependencies')<>'array' or jsonb_typeof(task_row->'recent_events')<>'array' then
    raise exception 'Overview omitted dependencies or recent events';
  end if;
  if (overview->'summary'->>'total_goals')::int<1 then
    raise exception 'Overview summary omitted goal counts';
  end if;
  raise notice 'PASS: new agent can inspect full goal context, loop state, task criteria, dependencies and recent events';
end;
$test$;
rollback;
