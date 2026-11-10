-- Point the lifecycle skill at its published executable version.
update public.skills s
set current_version_id = v.id,
    updated_at = now()
from public.skill_versions v
where s.id = 45
  and v.skill_id = 45
  and v.version = '1.0.0'
  and v.is_published = true;
