-- The goal overview includes project-wide task and agent state. It is intended
-- for trusted orchestration connectors, not anonymous Data API callers.
revoke execute on function public.goal_ledger_overview(text[]) from public;
revoke execute on function public.goal_ledger_overview(text[]) from anon;
revoke execute on function public.goal_ledger_overview(text[]) from authenticated;
grant execute on function public.goal_ledger_overview(text[]) to service_role;
