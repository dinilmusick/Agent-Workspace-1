-- Scope published skill metadata and make all non-catalog tables explicitly deny client roles.
drop policy if exists skills_public_read on public.skills;
create policy skills_public_read on public.skills for select to anon, authenticated
using (status='active' and exists (select 1 from public.skill_versions v where v.id=current_version_id and v.is_published=true));

drop policy if exists skill_capability_links_public_read on public.skill_capability_links;
create policy skill_capability_links_public_read on public.skill_capability_links for select to anon, authenticated
using (exists (select 1 from public.skills s where s.id=skill_id and s.status='active'));
drop policy if exists skill_dependencies_public_read on public.skill_dependencies;
create policy skill_dependencies_public_read on public.skill_dependencies for select to anon, authenticated
using (exists (select 1 from public.skills s where s.id=skill_id and s.status='active'));
drop policy if exists skill_tool_links_public_read on public.skill_tool_links;
create policy skill_tool_links_public_read on public.skill_tool_links for select to anon, authenticated
using (exists (select 1 from public.skills s where s.id=skill_id and s.status='active'));
drop policy if exists skill_resources_public_read on public.skill_resources;
create policy skill_resources_public_read on public.skill_resources for select to anon, authenticated
using (exists (select 1 from public.skills s where s.id=skill_id and s.status='active'));
drop policy if exists skill_triggers_public_read on public.skill_triggers;
create policy skill_triggers_public_read on public.skill_triggers for select to anon, authenticated
using (exists (select 1 from public.skills s where s.id=skill_id and s.status='active'));

drop policy if exists agent_registry_deny_clients on public.agent_registry;
create policy agent_registry_deny_clients on public.agent_registry for all to anon, authenticated using (false) with check (false);
drop policy if exists skill_evaluations_deny_clients on public.skill_evaluations;
create policy skill_evaluations_deny_clients on public.skill_evaluations for all to anon, authenticated using (false) with check (false);
drop policy if exists task_dependencies_deny_clients on public.task_dependencies;
create policy task_dependencies_deny_clients on public.task_dependencies for all to anon, authenticated using (false) with check (false);
drop policy if exists task_events_deny_clients on public.task_events;
create policy task_events_deny_clients on public.task_events for all to anon, authenticated using (false) with check (false);
drop policy if exists task_iterations_deny_clients on public.task_iterations;
create policy task_iterations_deny_clients on public.task_iterations for all to anon, authenticated using (false) with check (false);
drop policy if exists tasks_deny_clients on public.tasks;
create policy tasks_deny_clients on public.tasks for all to anon, authenticated using (false) with check (false);
