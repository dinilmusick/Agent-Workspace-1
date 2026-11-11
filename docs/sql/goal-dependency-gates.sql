-- Canonical source for the live migration
-- 20261111142116_harden_goal_dependency_vision_scope.
-- The base goal/task/vision tables and goal verification helpers are created by
-- earlier workspace migrations. This migration is safe on the already-updated
-- Skills Database and on a fresh database after those prerequisite migrations.

create table if not exists public.goal_dependencies (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.goals(id) on delete cascade,
  depends_on_goal_id uuid not null references public.goals(id) on delete cascade,
  dependency_type text not null default 'blocking'
    check (dependency_type in ('blocking','advisory')),
  created_at timestamptz not null default now(),
  constraint goal_dependencies_no_self check (goal_id <> depends_on_goal_id),
  constraint goal_dependencies_unique unique (goal_id, depends_on_goal_id)
);

create index if not exists goal_dependencies_prerequisite_idx
  on public.goal_dependencies(depends_on_goal_id);
alter table public.goal_dependencies enable row level security;
grant all on public.goal_dependencies to service_role;

create or replace function public.goal_has_unverified_descendant_tasks(goal_id_in uuid)
returns boolean
language sql
stable
set search_path = public
as $function$
  with recursive descendants(id) as (
    select t.id from public.tasks t where t.goal_id=goal_id_in
    union all
    select child.id from public.tasks child
    join descendants parent on child.parent_task_id=parent.id
  )
  select exists (
    select 1 from descendants d
    join public.tasks t on t.id=d.id
    where not (t.status='completed' and t.verification_status in ('verified','not_required'))
  );
$function$;

create or replace function public.validate_goal_dependency()
returns trigger
language plpgsql
set search_path = public
as $function$
declare dependent_visions uuid[]; prerequisite_visions uuid[];
begin
  perform pg_advisory_xact_lock(hashtext('public.goal_dependencies.graph'));
  if new.dependency_type='blocking' and exists (
    with recursive prerequisites(id) as (
      select new.depends_on_goal_id
      union
      select d.depends_on_goal_id from public.goal_dependencies d
      join prerequisites p on d.goal_id=p.id
      where d.dependency_type='blocking' and (tg_op='INSERT' or d.id<>new.id)
    )
    select 1 from prerequisites where id=new.goal_id
  ) then raise exception 'goal dependency would create a blocking cycle'; end if;

  select array_agg(distinct vt.vision_id order by vt.vision_id)
    into dependent_visions
  from public.vision_target_goals vtg
  join public.vision_targets vt on vt.id=vtg.vision_target_id
  where vtg.goal_id=new.goal_id;
  select array_agg(distinct vt.vision_id order by vt.vision_id)
    into prerequisite_visions
  from public.vision_target_goals vtg
  join public.vision_targets vt on vt.id=vtg.vision_target_id
  where vtg.goal_id=new.depends_on_goal_id;

  if coalesce(cardinality(dependent_visions),0)>1
     or coalesce(cardinality(prerequisite_visions),0)>1 then
    raise exception 'a goal may only be linked to targets within one Vision';
  end if;
  if dependent_visions is distinct from prerequisite_visions
     and (dependent_visions is not null or prerequisite_visions is not null) then
    raise exception 'goal dependencies must connect goals within the same Vision';
  end if;
  return new;
end;
$function$;

drop trigger if exists goal_dependencies_validate on public.goal_dependencies;
create trigger goal_dependencies_validate
before insert or update on public.goal_dependencies
for each row execute function public.validate_goal_dependency();

create or replace function public.enforce_goal_dependency_completion()
returns trigger
language plpgsql
set search_path = public
as $function$
begin
  if new.status in ('active','completed')
     and old.status is distinct from new.status
     and exists (
       select 1 from public.goal_dependencies d
       join public.goals prerequisite on prerequisite.id=d.depends_on_goal_id
       where d.goal_id=new.id and d.dependency_type='blocking'
         and (prerequisite.status<>'completed'
           or public.goal_has_unverified_descendant_tasks(prerequisite.id))
     ) then
    raise exception 'goal is locked: all blocking prerequisite goals must be completed and verified before activation or completion';
  end if;
  return new;
end;
$function$;

drop trigger if exists goals_enforce_prerequisite_completion on public.goals;
create trigger goals_enforce_prerequisite_completion
before update of status on public.goals
for each row execute function public.enforce_goal_dependency_completion();

create or replace function public.enforce_goal_prerequisites_on_claim()
returns trigger
language plpgsql
set search_path = public
as $function$
begin
  if new.status='running' and new.goal_id is not null and exists (
    select 1 from public.goal_dependencies d
    join public.goals prerequisite on prerequisite.id=d.depends_on_goal_id
    where d.goal_id=new.goal_id and d.dependency_type='blocking'
      and (prerequisite.status<>'completed'
        or public.goal_has_unverified_descendant_tasks(prerequisite.id))
  ) then
    raise exception 'task claim denied: one or more blocking prerequisite goals are not completed and verified';
  end if;
  return new;
end;
$function$;

drop trigger if exists tasks_enforce_goal_prerequisites on public.tasks;
create trigger tasks_enforce_goal_prerequisites
before insert or update of status on public.tasks
for each row execute function public.enforce_goal_prerequisites_on_claim();

create or replace function public.goal_ledger_add_dependency(
  goal_key_in text,
  depends_on_goal_key_in text,
  dependency_type_in text default 'blocking',
  created_by_agent_id_in text default 'orchestrator'
)
returns public.goal_dependencies
language plpgsql
security invoker
set search_path = public
as $function$
declare dependent public.goals; prerequisite public.goals; edge public.goal_dependencies;
begin
  if dependency_type_in not in ('blocking','advisory') then
    raise exception 'dependency_type must be blocking or advisory';
  end if;
  if nullif(btrim(created_by_agent_id_in),'') is null then
    raise exception 'created_by_agent_id is required';
  end if;

  select * into dependent from public.goals
  where goal_key=btrim(goal_key_in)
    and (auth.uid() is null or owner_user_id=auth.uid()) for update;
  if not found then raise exception 'dependent goal not found or access denied'; end if;

  select * into prerequisite from public.goals
  where goal_key=btrim(depends_on_goal_key_in)
    and (auth.uid() is null or owner_user_id=auth.uid()) for update;
  if not found then raise exception 'prerequisite goal not found or access denied'; end if;

  insert into public.goal_dependencies(goal_id,depends_on_goal_id,dependency_type)
  values(dependent.id,prerequisite.id,dependency_type_in) returning * into edge;

  insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
  values(dependent.id,'note',created_by_agent_id_in,'Goal prerequisite dependency added',
    jsonb_build_object('goal_key',dependent.goal_key,
      'depends_on_goal_key',prerequisite.goal_key,'dependency_type',dependency_type_in));
  return edge;
end;
$function$;

revoke all on function public.goal_ledger_add_dependency(text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.goal_ledger_add_dependency(text,text,text,text)
  to service_role;
