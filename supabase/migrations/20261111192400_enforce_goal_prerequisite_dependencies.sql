-- Goal-level prerequisite edges. Blocking edges gate claims and completion; advisory edges are informational.
create table if not exists public.goal_dependencies (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.goals(id) on delete cascade,
  depends_on_goal_id uuid not null references public.goals(id) on delete cascade,
  dependency_type text not null default 'blocking' check (dependency_type in ('blocking','advisory')),
  created_at timestamptz not null default now(),
  constraint goal_dependencies_no_self check (goal_id <> depends_on_goal_id),
  constraint goal_dependencies_unique unique (goal_id, depends_on_goal_id)
);
create index if not exists goal_dependencies_prerequisite_idx on public.goal_dependencies(depends_on_goal_id);
alter table public.goal_dependencies enable row level security;
revoke all on public.goal_dependencies from anon, authenticated;
grant all on public.goal_dependencies to service_role;

create or replace function public.validate_goal_dependency() returns trigger language plpgsql set search_path=public as $fn$
declare dependent_vision uuid; prerequisite_vision uuid;
begin
  if new.dependency_type='blocking' and exists (with recursive prerequisites(id) as (
    select new.depends_on_goal_id union all
    select d.depends_on_goal_id from public.goal_dependencies d join prerequisites p on d.goal_id=p.id
    where d.dependency_type='blocking' and (tg_op='INSERT' or d.id<>new.id)
  ) select 1 from prerequisites where id=new.goal_id) then
    raise exception 'goal dependency would create a blocking cycle';
  end if;
  select vt.vision_id into dependent_vision from public.vision_target_goals vtg join public.vision_targets vt on vt.id=vtg.vision_target_id where vtg.goal_id=new.goal_id limit 1;
  select vt.vision_id into prerequisite_vision from public.vision_target_goals vtg join public.vision_targets vt on vt.id=vtg.vision_target_id where vtg.goal_id=new.depends_on_goal_id limit 1;
  if dependent_vision is distinct from prerequisite_vision and (dependent_vision is not null or prerequisite_vision is not null) then
    raise exception 'goal dependencies must connect goals within the same Vision';
  end if;
  return new;
end; $fn$;
drop trigger if exists goal_dependencies_validate on public.goal_dependencies;
create trigger goal_dependencies_validate before insert or update on public.goal_dependencies for each row execute function public.validate_goal_dependency();

create or replace function public.goal_has_unverified_descendant_tasks(goal_id_in uuid) returns boolean language sql stable set search_path=public as $fn$
  with recursive descendants(id) as (
    select t.id from public.tasks t where t.goal_id=goal_id_in
    union all
    select child.id from public.tasks child join descendants parent on child.parent_task_id=parent.id
  )
  select exists (select 1 from descendants d join public.tasks t on t.id=d.id where not (t.status='completed' and t.verification_status in ('verified','not_required')));
$fn$;

create or replace function public.enforce_goal_prerequisites_on_claim() returns trigger language plpgsql set search_path=public as $fn$
begin
  if new.status='running' and new.goal_id is not null then
    if exists (select 1 from public.goal_dependencies d join public.goals prerequisite on prerequisite.id=d.depends_on_goal_id where d.goal_id=new.goal_id and d.dependency_type='blocking' and (prerequisite.status<>'completed' or public.goal_has_unverified_descendant_tasks(prerequisite.id))) then
      raise exception 'task claim denied: one or more blocking prerequisite goals are not completed and verified';
    end if;
  end if;
  return new;
end; $fn$;
drop trigger if exists tasks_enforce_goal_prerequisites on public.tasks;
create trigger tasks_enforce_goal_prerequisites before insert or update of status on public.tasks for each row execute function public.enforce_goal_prerequisites_on_claim();

create or replace function public.enforce_goal_dependency_completion() returns trigger language plpgsql set search_path=public as $fn$
begin
  if new.status='completed' and old.status is distinct from 'completed' and exists (
    select 1 from public.goal_dependencies d join public.goals prerequisite on prerequisite.id=d.depends_on_goal_id
    where d.goal_id=new.id and d.dependency_type='blocking'
      and (prerequisite.status<>'completed' or public.goal_has_unverified_descendant_tasks(prerequisite.id))
  ) then raise exception 'goal cannot complete until all blocking prerequisite goals are completed and verified'; end if;
  return new;
end; $fn$;
drop trigger if exists goals_enforce_prerequisite_completion on public.goals;
create trigger goals_enforce_prerequisite_completion before update of status on public.goals for each row execute function public.enforce_goal_dependency_completion();