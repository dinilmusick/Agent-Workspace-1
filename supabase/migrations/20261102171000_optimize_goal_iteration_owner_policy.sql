drop policy if exists goal_iterations_owner_access on public.goal_iterations;
create policy goal_iterations_owner_access on public.goal_iterations for all to authenticated
  using(exists(select 1 from public.goals g where g.id=goal_iterations.goal_id and (
    ((select auth.uid()) is not null and g.owner_user_id=(select auth.uid()))
    or ((select auth.uid()) is null and g.owner_user_id is null)
  )))
  with check(exists(select 1 from public.goals g where g.id=goal_iterations.goal_id and (
    ((select auth.uid()) is not null and g.owner_user_id=(select auth.uid()))
    or ((select auth.uid()) is null and g.owner_user_id is null)
  )));