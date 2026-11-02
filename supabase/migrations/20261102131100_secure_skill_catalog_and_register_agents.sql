-- Security boundary and authenticated agent registration for the Skills Database.
begin;

revoke all privileges on all tables in schema public from anon, authenticated;
revoke all privileges on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

grant select on table
  public.skills, public.skill_categories, public.skill_sources, public.skill_tools,
  public.skill_capabilities, public.skill_versions, public.skill_capability_links,
  public.skill_dependencies, public.skill_tool_links, public.skill_resources,
  public.skill_triggers
to anon, authenticated;

drop policy if exists skills_public_read on public.skills;
create policy skills_public_read on public.skills
  for select to anon, authenticated using (status = 'active');

drop policy if exists skill_versions_public_read on public.skill_versions;
create policy skill_versions_public_read on public.skill_versions
  for select to anon, authenticated using (is_published = true);

drop policy if exists skill_categories_public_read on public.skill_categories;
create policy skill_categories_public_read on public.skill_categories
  for select to anon, authenticated using (true);
drop policy if exists skill_sources_public_read on public.skill_sources;
create policy skill_sources_public_read on public.skill_sources
  for select to anon, authenticated using (true);
drop policy if exists skill_tools_public_read on public.skill_tools;
create policy skill_tools_public_read on public.skill_tools
  for select to anon, authenticated using (true);
drop policy if exists skill_capabilities_public_read on public.skill_capabilities;
create policy skill_capabilities_public_read on public.skill_capabilities
  for select to anon, authenticated using (true);
drop policy if exists skill_capability_links_public_read on public.skill_capability_links;
create policy skill_capability_links_public_read on public.skill_capability_links
  for select to anon, authenticated using (true);
drop policy if exists skill_dependencies_public_read on public.skill_dependencies;
create policy skill_dependencies_public_read on public.skill_dependencies
  for select to anon, authenticated using (true);
drop policy if exists skill_tool_links_public_read on public.skill_tool_links;
create policy skill_tool_links_public_read on public.skill_tool_links
  for select to anon, authenticated using (true);
drop policy if exists skill_resources_public_read on public.skill_resources;
create policy skill_resources_public_read on public.skill_resources
  for select to anon, authenticated using (true);
drop policy if exists skill_triggers_public_read on public.skill_triggers;
create policy skill_triggers_public_read on public.skill_triggers
  for select to anon, authenticated using (true);

create table if not exists public.agent_registry (
  user_id uuid primary key references auth.users(id) on delete cascade,
  agent_id text not null unique check (length(btrim(agent_id)) between 1 and 128),
  agent_name text not null check (length(btrim(agent_name)) between 1 and 160),
  agent_type text not null default 'worker',
  capabilities text[] not null default '{}',
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);
alter table public.agent_registry enable row level security;
revoke all privileges on public.agent_registry from anon, authenticated, public;
grant all privileges on public.agent_registry to service_role;

grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema public
  grant all on tables to service_role;
alter default privileges for role postgres in schema public
  grant all on sequences to service_role;
alter default privileges for role postgres in schema public
  grant execute on functions to service_role;
commit;
