-- Core skill records referenced by the persisted migration graph.
-- The original skills catalog was provisioned manually; seed only the two stable
-- records required by the dependency edge in 20261102151840. Existing rows are
-- never overwritten. Full skill definitions remain in the repository skill files.

insert into public.skills(
  id,name,instructions,slug,description,category_id,status,metadata
)
values
(
  4,'Loop Generator',
  'Local database fixture. Canonical skill instructions: skills/loop-generator/SKILL.md',
  'loop-generator',
  'Persistent evidence-driven execution loops for goals and tasks.',
  (select id from public.skill_categories where slug='ai-engineering'),
  'active',
  jsonb_build_object('seed_source','repository','canonical_path','skills/loop-generator/SKILL.md')
),
(
  7,'Task Ledger',
  'Local database fixture. Canonical skill instructions: skills/task-ledger/SKILL.md',
  'task-ledger',
  'Persistent goals, tasks, atomic claims, iterations, evidence and independent verification.',
  (select id from public.skill_categories where slug='software-engineering'),
  'active',
  jsonb_build_object('seed_source','repository','canonical_path','skills/task-ledger/SKILL.md')
)
on conflict (id) do nothing;

insert into public.skill_versions(
  skill_id,version,instructions,manifest,changelog,is_published,published_at
)
values
(
  4,'1.2.1',
  'Local database fixture. Canonical skill instructions: skills/loop-generator/SKILL.md',
  jsonb_build_object('id','loop-generator','name','Loop Generator','version','1.2.1'),
  'Bootstrap version required for reproducible local migration replay.',
  true,now()
),
(
  7,'1.7.4',
  'Local database fixture. Canonical skill instructions: skills/task-ledger/SKILL.md',
  jsonb_build_object('id','task-ledger','name','Task Ledger','version','1.7.4'),
  'Bootstrap version required for reproducible local migration replay.',
  true,now()
)
on conflict (skill_id,version) do nothing;

update public.skills s
set current_version_id=v.id
from public.skill_versions v
where v.skill_id=s.id
  and ((s.id=4 and v.version='1.2.1') or (s.id=7 and v.version='1.7.4'))
  and s.current_version_id is null;

select setval(
  pg_get_serial_sequence('public.skills','id'),
  greatest((select coalesce(max(id),1) from public.skills),1),
  true
);
