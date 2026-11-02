
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon,authenticated;

REVOKE ALL ON TABLE public.tasks,public.task_events,public.task_dependencies,public.task_iterations,
  public.active_tasks,public.task_hierarchy FROM PUBLIC,anon,authenticated;

REVOKE EXECUTE ON FUNCTION public.task_ledger_create_tree(text,text,jsonb,uuid,text,text) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_add_dependency(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_claim_next(text,text,text,text[],integer) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_heartbeat_claim(uuid,text,uuid,text,integer) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_submit_result(uuid,text,uuid,jsonb,text,jsonb,jsonb,text) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_verify_result(uuid,text,boolean,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_children_summary(uuid) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_finalize_parent(uuid,text,text,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_record_iteration(uuid,text,uuid,integer,jsonb,jsonb,jsonb,text,jsonb,jsonb,text) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_register(text,text,text,text,text[],text,text,smallint,text,jsonb,uuid) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_heartbeat(uuid,text,text,text,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.task_ledger_update(uuid,text,text,text,text,text,text,text[],text,jsonb) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION public.task_ledger_create_tree(text,text,jsonb,uuid,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_add_dependency(uuid,uuid,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_claim_next(text,text,text,text[],integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_heartbeat_claim(uuid,text,uuid,text,integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_submit_result(uuid,text,uuid,jsonb,text,jsonb,jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_verify_result(uuid,text,boolean,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_children_summary(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_finalize_parent(uuid,text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_record_iteration(uuid,text,uuid,integer,jsonb,jsonb,jsonb,text,jsonb,jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_register(text,text,text,text,text[],text,text,smallint,text,jsonb,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_heartbeat(uuid,text,text,text,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.task_ledger_update(uuid,text,text,text,text,text,text,text[],text,jsonb) TO service_role;
