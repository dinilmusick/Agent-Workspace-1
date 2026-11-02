
create index if not exists skill_categories_parent_idx on public.skill_categories(parent_id);
create index if not exists skills_current_version_idx on public.skills(current_version_id);
create index if not exists skill_capability_links_capability_idx on public.skill_capability_links(capability_id);
create index if not exists skill_tool_links_tool_idx on public.skill_tool_links(tool_id);
create index if not exists skill_evaluations_skill_idx on public.skill_evaluations(skill_id);
create index if not exists skill_evaluations_version_idx on public.skill_evaluations(version_id);

update public.skills
set category_id = (select id from public.skill_categories where slug = 'design')
where slug = 'tldraw' and category_id is null;

insert into public.skill_triggers(skill_id, trigger_type, value, weight)
select id, 'exact', 'tldraw', 1.0 from public.skills where slug = 'tldraw'
on conflict (skill_id, trigger_type, value) do nothing;

insert into public.skill_resources(skill_id, resource_type, title, uri, description)
select id, 'documentation', 'tldraw documentation', 'https://tldraw.dev/', 'Official tldraw documentation.'
from public.skills where slug = 'tldraw'
and not exists (select 1 from public.skill_resources r where r.skill_id = public.skills.id and r.uri = 'https://tldraw.dev/');
