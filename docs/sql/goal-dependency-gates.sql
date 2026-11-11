-- Reference copy of the canonical goal dependency migration.
-- Prefer the versioned migration under supabase/migrations for deployments.
create table if not exists public.goal_dependencies (
 id uuid primary key default gen_random_uuid(),
 goal_id uuid not null references public.goals(id) on delete cascade,
 depends_on_goal_id uuid not null references public.goals(id) on delete cascade,
 dependency_type text not null default 'blocking' check (dependency_type in ('blocking','advisory')),
 created_at timestamptz not null default now(),
 constraint goal_dependencies_no_self check (goal_id<>depends_on_goal_id),
 constraint goal_dependencies_unique unique(goal_id,depends_on_goal_id)
);
create index if not exists goal_dependencies_prerequisite_idx on public.goal_dependencies(depends_on_goal_id);
alter table public.goal_dependencies enable row level security;
revoke all on public.goal_dependencies from anon,authenticated;
grant all on public.goal_dependencies to service_role;

create or replace function public.goal_has_unverified_descendant_tasks(goal_id_in uuid) returns boolean language sql stable set search_path=public as $fn$
 with recursive descendants(id) as (select t.id from public.tasks t where t.goal_id=goal_id_in union all select child.id from public.tasks child join descendants parent on child.parent_task_id=parent.id)
 select exists(select 1 from descendants d join public.tasks t on t.id=d.id where not (t.status='completed' and t.verification_status in ('verified','not_required')));
$fn$;

create or replace function public.validate_goal_dependency() returns trigger language plpgsql set search_path=public as $fn$
declare dependent_visions uuid[]; prerequisite_visions uuid[];
begin
 perform pg_advisory_xact_lock(hashtext('public.goal_dependencies.graph'));
 if new.dependency_type='blocking' and exists(with recursive prerequisites(id) as (select new.depends_on_goal_id union select d.depends_on_goal_id from public.goal_dependencies d join prerequisites p on d.goal_id=p.id where d.dependency_type='blocking' and (tg_op='INSERT' or d.id<>new.id)) select 1 from prerequisites where id=new.goal_id) then raise exception 'goal dependency would create a blocking cycle'; end if;
 select array_agg(distinct vt.vision_id order by vt.vision_id) into dependent_visions from public.vision_target_goals vtg join public.vision_targets vt on vt.id=vtg.vision_target_id where vtg.goal_id=new.goal_id;
 select array_agg(distinct vt.vision_id order by vt.vision_id) into prerequisite_visions from public.vision_target_goals vtg join public.vision_targets vt on vt.id=vtg.vision_target_id where vtg.goal_id=new.depends_on_goal_id;
 if coalesce(cardinality(dependent_visions),0)>1 or coalesce(cardinality(prerequisite_visions),0)>1 then raise exception 'a goal may only be linked to targets within one Vision'; end if;
 if dependent_visions is distinct from prerequisite_visions and (dependent_visions is not null or prerequisite_visions is not null) then raise exception 'goal dependencies must connect goals within the same Vision'; end if;
 if new.dependency_type='blocking' and exists(select 1 from public.goals dependent join public.goals prerequisite on prerequisite.id=new.depends_on_goal_id where dependent.id=new.goal_id and dependent.status in ('active','completed') and (prerequisite.status<>'completed' or public.goal_has_unverified_descendant_tasks(prerequisite.id))) then raise exception 'cannot add an unsatisfied blocking prerequisite to an active or completed goal'; end if;
 return new;
end; $fn$;
drop trigger if exists goal_dependencies_validate on public.goal_dependencies;
create trigger goal_dependencies_validate before insert or update on public.goal_dependencies for each row execute function public.validate_goal_dependency();

create or replace function public.enforce_goal_prerequisites_on_claim() returns trigger language plpgsql set search_path=public as $fn$
begin
 if new.status='running' and new.goal_id is not null and exists(select 1 from public.goal_dependencies d join public.goals p on p.id=d.depends_on_goal_id where d.goal_id=new.goal_id and d.dependency_type='blocking' and (p.status<>'completed' or public.goal_has_unverified_descendant_tasks(p.id))) then raise exception 'task claim denied: one or more blocking prerequisite goals are not completed and verified'; end if;
 return new;
end; $fn$;
drop trigger if exists tasks_enforce_goal_prerequisites on public.tasks;
create trigger tasks_enforce_goal_prerequisites before insert or update of status on public.tasks for each row execute function public.enforce_goal_prerequisites_on_claim();

create or replace function public.enforce_goal_dependency_completion() returns trigger language plpgsql set search_path=public as $fn$
begin
 if new.status in ('active','completed') and (tg_op='INSERT' or old.status is distinct from new.status) and exists(select 1 from public.goal_dependencies d join public.goals p on p.id=d.depends_on_goal_id where d.goal_id=new.id and d.dependency_type='blocking' and (p.status<>'completed' or public.goal_has_unverified_descendant_tasks(p.id))) then raise exception 'goal is locked: all blocking prerequisite goals must be completed and verified before activation or completion'; end if;
 return new;
end; $fn$;
drop trigger if exists goals_enforce_prerequisite_completion on public.goals;
create trigger goals_enforce_prerequisite_completion before insert or update of status on public.goals for each row execute function public.enforce_goal_dependency_completion();

create or replace function public.enforce_goal_completion() returns trigger language plpgsql set search_path=public as $fn$
begin
 if new.status='completed' and old.status is distinct from 'completed' and public.goal_has_unverified_descendant_tasks(new.id) then raise exception 'goal cannot be completed until every descendant task is completed and verified'; end if;
 return new;
end; $fn$;
create or replace function public.goals_require_goal_loop_pass() returns trigger language plpgsql set search_path=public as $fn$
declare latest public.goal_iterations;
begin
 if new.status='completed' and old.status is distinct from 'completed' and new.goal_loop_definition->>'enabled'='true' then
  select * into latest from public.goal_iterations where goal_id=new.id order by iteration_no desc limit 1;
  if latest.id is null or latest.verdict<>'pass' or jsonb_array_length(latest.evidence)=0 or exists(select 1 from jsonb_array_elements(latest.criterion_results) c where c->>'status'<>'satisfied') then raise exception 'goal cannot complete before its own goal loop passes with evidence'; end if;
  if public.goal_has_unverified_descendant_tasks(new.id) then raise exception 'goal cannot complete before every descendant task is independently verified'; end if;
 end if;
 return new;
end; $fn$;

create or replace function public.goal_ledger_add_dependency(goal_key_in text,depends_on_goal_key_in text,dependency_type_in text default 'blocking',created_by_agent_id_in text default 'orchestrator') returns public.goal_dependencies language plpgsql security invoker set search_path=public as $fn$
declare dependent public.goals; prerequisite public.goals; edge public.goal_dependencies;
begin
 if dependency_type_in not in ('blocking','advisory') then raise exception 'dependency_type must be blocking or advisory'; end if;
 if nullif(btrim(created_by_agent_id_in),'') is null then raise exception 'created_by_agent_id is required'; end if;
 select * into dependent from public.goals where goal_key=btrim(goal_key_in) and (auth.uid() is null or owner_user_id=auth.uid()) for update;
 if not found then raise exception 'dependent goal not found or access denied'; end if;
 select * into prerequisite from public.goals where goal_key=btrim(depends_on_goal_key_in) and (auth.uid() is null or owner_user_id=auth.uid()) for update;
 if not found then raise exception 'prerequisite goal not found or access denied'; end if;
 insert into public.goal_dependencies(goal_id,depends_on_goal_id,dependency_type) values(dependent.id,prerequisite.id,dependency_type_in) returning * into edge;
 insert into public.goal_events(goal_id,event_type,agent_id,message,payload) values(dependent.id,'note',created_by_agent_id_in,'Goal prerequisite dependency added',jsonb_build_object('goal_key',dependent.goal_key,'depends_on_goal_key',prerequisite.goal_key,'dependency_type',dependency_type_in));
 return edge;
end; $fn$;
revoke all on function public.goal_ledger_add_dependency(text,text,text,text) from public,anon,authenticated;
grant execute on function public.goal_ledger_add_dependency(text,text,text,text) to service_role;