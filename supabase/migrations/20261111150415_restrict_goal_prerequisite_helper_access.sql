-- Prevent direct public RPC calls from revealing whether arbitrary goal tasks are verified.
revoke all on function public.goal_has_unverified_descendant_tasks(uuid) from public, anon, authenticated;
grant execute on function public.goal_has_unverified_descendant_tasks(uuid) to service_role;
