-- Enable owner-scoped access to persistent goal records and their audit history.
create policy goals_owner_access on public.goals
  for all to authenticated
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

create policy goal_versions_owner_access on public.goal_versions
  for all to authenticated
  using (exists (select 1 from public.goals g where g.id=goal_id and g.owner_user_id=auth.uid()))
  with check (exists (select 1 from public.goals g where g.id=goal_id and g.owner_user_id=auth.uid()));

create policy goal_events_owner_access on public.goal_events
  for all to authenticated
  using (exists (select 1 from public.goals g where g.id=goal_id and g.owner_user_id=auth.uid()))
  with check (exists (select 1 from public.goals g where g.id=goal_id and g.owner_user_id=auth.uid()));

grant select on public.goal_versions, public.goal_events to authenticated;
