
-- Chat-driven task ledger: expose only owner-scoped data and transactional RPCs.
-- No Edge Function or server-side application runtime is required.

drop policy if exists agent_registry_deny_clients on public.agent_registry;
create policy agent_registry_self_read on public.agent_registry
  for select to authenticated using (user_id = auth.uid());

drop policy if exists tasks_deny_clients on public.tasks;
create policy tasks_goal_owner_access on public.tasks
  for all to authenticated
  using (exists (select 1 from public.goals g where g.id = goal_id and g.owner_user_id = auth.uid()))
  with check (exists (select 1 from public.goals g where g.id = goal_id and g.owner_user_id = auth.uid()));

drop policy if exists task_iterations_deny_clients on public.task_iterations;
create policy task_iterations_goal_owner_access on public.task_iterations
  for all to authenticated
  using (exists (select 1 from public.tasks t join public.goals g on g.id=t.goal_id where t.id=task_id and g.owner_user_id=auth.uid()))
  with check (exists (select 1 from public.tasks t join public.goals g on g.id=t.goal_id where t.id=task_id and g.owner_user_id=auth.uid()));

drop policy if exists task_dependencies_deny_clients on public.task_dependencies;
create policy task_dependencies_goal_owner_access on public.task_dependencies
  for all to authenticated
  using (exists (select 1 from public.tasks t join public.goals g on g.id=t.goal_id where t.id=task_id and g.owner_user_id=auth.uid()))
  with check (exists (select 1 from public.tasks t join public.goals g on g.id=t.goal_id where t.id=task_id and g.owner_user_id=auth.uid()));

drop policy if exists task_events_deny_clients on public.task_events;
create policy task_events_goal_owner_access on public.task_events
  for all to authenticated
  using (exists (select 1 from public.tasks t join public.goals g on g.id=t.goal_id where t.id=task_id and g.owner_user_id=auth.uid()))
  with check (exists (select 1 from public.tasks t join public.goals g on g.id=t.goal_id where t.id=task_id and g.owner_user_id=auth.uid()));

create or replace function public.task_ledger_claim_goal_next(
  goal_id_in uuid,
  agent_id_in text,
  agent_name_in text,
  agent_type_in text default 'worker',
  capabilities_in text[] default '{}',
  lease_seconds_in integer default 900
) returns setof public.tasks
language plpgsql
set search_path = public
as $function$
declare
  candidate_id uuid;
  task_out public.tasks;
  lease_value integer := greatest(30, least(coalesce(lease_seconds_in,900),86400));
begin
  if goal_id_in is null or nullif(btrim(agent_id_in),'') is null or nullif(btrim(agent_name_in),'') is null then
    raise exception 'goal and agent identity are required';
  end if;
  if not exists(select 1 from public.goals where id=goal_id_in and owner_user_id=auth.uid()) then
    raise exception 'goal not found or access denied';
  end if;
  select t.id into candidate_id
  from public.tasks t
  where t.goal_id=goal_id_in
    and t.status in ('queued','running')
    and t.attempt_count<t.max_attempts
    and (t.claim_expires_at is null or t.claim_expires_at<now())
    and t.required_capabilities<@coalesce(capabilities_in,'{}'::text[])
    and not exists(select 1 from public.tasks child where child.parent_task_id=t.id)
    and (t.parent_task_id is null or not exists(select 1 from public.tasks p where p.id=t.parent_task_id and p.status in ('failed','cancelled','abandoned')))
    and not exists(
      select 1 from public.task_dependencies d
      join public.tasks dep on dep.id=d.depends_on_task_id
      where d.task_id=t.id and d.dependency_type='blocking'
        and (dep.status<>'completed' or dep.verification_status<>'verified')
    )
  order by t.priority asc,t.started_at asc
  for update skip locked limit 1;
  if candidate_id is null then return; end if;
  update public.tasks
  set status='running', claimed_by_agent_id=agent_id_in, claimed_by_agent_name=agent_name_in,
      claim_token=gen_random_uuid(), claimed_at=now(),
      claim_expires_at=now()+make_interval(secs=>lease_value),
      attempt_count=attempt_count+1, heartbeat_at=now(), updated_at=now(),
      current_step='Claimed by chat worker'
  where id=candidate_id returning * into task_out;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_out.id,'claimed',agent_id_in,'Task claimed by chat worker',
    jsonb_build_object('lease_expires_at',task_out.claim_expires_at,'attempt_count',task_out.attempt_count));
  return next task_out;
end;
$function$;

grant select on public.agent_registry, public.goals, public.tasks, public.task_iterations,
  public.task_dependencies, public.task_events, public.skills, public.skill_versions,
  public.skill_dependencies, public.skill_tool_links, public.skill_capability_links,
  public.skill_resources, public.skill_triggers to authenticated;

grant execute on function public.goal_ledger_create(text,text,jsonb,text,jsonb,text,uuid,jsonb) to authenticated;
grant execute on function public.goal_ledger_get(uuid,text) to authenticated;
grant execute on function public.goal_ledger_summary(uuid) to authenticated;
grant execute on function public.goal_ledger_update(uuid,text,text,jsonb,text,jsonb,text,jsonb,text) to authenticated;
grant execute on function public.task_ledger_claim_goal_next(uuid,text,text,text,text[],integer) to authenticated;
grant execute on function public.task_ledger_claim_next(text,text,text,text[],integer) to authenticated;
grant execute on function public.task_ledger_create_tree(text,text,jsonb,uuid,text,text) to authenticated;
grant execute on function public.task_ledger_heartbeat_claim(uuid,text,uuid,text,integer) to authenticated;
grant execute on function public.task_ledger_record_iteration(uuid,text,uuid,integer,jsonb,jsonb,jsonb,text,jsonb,jsonb,text) to authenticated;
grant execute on function public.task_ledger_submit_result(uuid,text,uuid,jsonb,text,jsonb,jsonb,text) to authenticated;
grant execute on function public.task_ledger_verify_result(uuid,text,boolean,jsonb) to authenticated;
grant execute on function public.task_ledger_finalize_parent(uuid,text,text,jsonb) to authenticated;
grant execute on function public.task_ledger_children_summary(uuid) to authenticated;
grant execute on function public.task_ledger_add_dependency(uuid,uuid,text,text) to authenticated;
grant execute on function public.task_ledger_update(uuid,text,text,text,text,text,text,text[],text,jsonb) to authenticated;
grant execute on function public.task_ledger_pending_verification() to authenticated;

comment on function public.task_ledger_claim_goal_next(uuid,text,text,text,text[],integer)
is 'Atomic goal-scoped task claim for independent ChatGPT worker conversations; database transaction only.';
