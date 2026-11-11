-- Dependency-free integration assertions for the Omni Loop/Vision schema.
-- Keep this suite runnable in the minimal disposable Supabase stack (no pgTAP required).
begin;
do $test$
begin
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='goals' and column_name='goal_type') then raise exception 'FAIL: goals.goal_type missing'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='goals' and column_name='target') then raise exception 'FAIL: goals.target missing'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='goals' and column_name='behavior_inputs') then raise exception 'FAIL: goals.behavior_inputs missing'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='goals' and column_name='expected_outputs') then raise exception 'FAIL: goals.expected_outputs missing'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='tasks' and column_name='task_type') then raise exception 'FAIL: tasks.task_type missing'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='tasks' and column_name='target') then raise exception 'FAIL: tasks.target missing'; end if;
  if to_regclass('public.visions') is null then raise exception 'FAIL: public.visions missing'; end if;
  if to_regclass('public.vision_targets') is null then raise exception 'FAIL: public.vision_targets missing'; end if;
  if to_regclass('public.vision_target_goals') is null then raise exception 'FAIL: public.vision_target_goals missing'; end if;
  if to_regclass('public.vision_canvas_pages') is null then raise exception 'FAIL: public.vision_canvas_pages missing'; end if;
  if not public.validate_omni_target('{"type":"repository","id":"example/repo"}'::jsonb) then raise exception 'FAIL: valid repository target rejected'; end if;
  begin
    perform public.validate_omni_target('{"type":"repository"}'::jsonb);
    raise exception 'FAIL: invalid target accepted';
  exception when others then
    if sqlerrm <> 'target requires exactly one typed identity: type + id' then raise; end if;
  end;
  raise notice 'PASS: Omni Loop goal/task target contracts and Vision persistence schema';
end;
$test$;
rollback;
