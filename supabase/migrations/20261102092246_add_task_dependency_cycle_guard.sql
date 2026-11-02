
CREATE OR REPLACE FUNCTION public.task_ledger_add_dependency(
  task_id_in uuid,
  depends_on_task_id_in uuid,
  created_by_agent_id_in text,
  dependency_type_in text DEFAULT 'blocking'
) RETURNS public.task_dependencies
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE dependency_out public.task_dependencies;
DECLARE creates_cycle boolean;
BEGIN
  IF task_id_in=depends_on_task_id_in THEN RAISE EXCEPTION 'A task cannot depend on itself'; END IF;
  IF dependency_type_in NOT IN ('blocking','advisory') THEN RAISE EXCEPTION 'Invalid dependency type'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tasks WHERE id=task_id_in)
     OR NOT EXISTS (SELECT 1 FROM public.tasks WHERE id=depends_on_task_id_in) THEN
    RAISE EXCEPTION 'Both task records must exist';
  END IF;
  WITH RECURSIVE dependency_path(id) AS (
    SELECT depends_on_task_id FROM public.task_dependencies WHERE task_id=depends_on_task_id_in
    UNION
    SELECT d.depends_on_task_id FROM public.task_dependencies d
    JOIN dependency_path p ON d.task_id=p.id
  )
  SELECT EXISTS(SELECT 1 FROM dependency_path WHERE id=task_id_in) INTO creates_cycle;
  IF creates_cycle THEN RAISE EXCEPTION 'Dependency would create a cycle'; END IF;

  INSERT INTO public.task_dependencies(task_id,depends_on_task_id,dependency_type,created_by_agent_id)
  VALUES(task_id_in,depends_on_task_id_in,dependency_type_in,created_by_agent_id_in)
  ON CONFLICT (task_id,depends_on_task_id)
  DO UPDATE SET dependency_type=EXCLUDED.dependency_type,created_by_agent_id=EXCLUDED.created_by_agent_id
  RETURNING * INTO dependency_out;

  INSERT INTO public.task_events(task_id,event_type,agent_id,message,payload)
  VALUES(task_id_in,'dependency_added',created_by_agent_id_in,'Task dependency registered',
    jsonb_build_object('depends_on_task_id',depends_on_task_id_in,'dependency_type',dependency_type_in));
  RETURN dependency_out;
END;
$$;
