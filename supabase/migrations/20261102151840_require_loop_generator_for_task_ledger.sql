insert into public.skill_dependencies(skill_id,depends_on_skill_id,dependency_type,version_constraint)
values(7,4,'required','>=1.1.0')
on conflict(skill_id,depends_on_skill_id) do update
set dependency_type=excluded.dependency_type,version_constraint=excluded.version_constraint;