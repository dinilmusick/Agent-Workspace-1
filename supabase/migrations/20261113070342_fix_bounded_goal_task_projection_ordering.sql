-- Fix bounded Goal completion-parameter projection ordering for the existing tasks schema.
create or replace function public.sync_goal_completion_parameters()
returns trigger language plpgsql set search_path=public as $$
declare gid uuid; model text;
begin
  gid:=coalesce(new.goal_id,old.goal_id);
  if gid is not null then
    select execution_model into model from public.goals where id=gid;
    if model='bounded-v2' then
      update public.goals g set completion_parameters=coalesce((
        select jsonb_agg(jsonb_build_object('id',t.task_key,'task_id',t.id,'description',coalesce(t.description,t.task_name),'required',true) order by t.started_at,t.id)
        from public.tasks t where t.goal_id=gid and t.parent_task_id is null
      ),'[]'::jsonb),updated_at=now() where g.id=gid;
    end if;
  end if;
  if tg_op='UPDATE' and old.goal_id is distinct from new.goal_id and old.goal_id is not null then
    select execution_model into model from public.goals where id=old.goal_id;
    if model='bounded-v2' then
      update public.goals g set completion_parameters=coalesce((
        select jsonb_agg(jsonb_build_object('id',t.task_key,'task_id',t.id,'description',coalesce(t.description,t.task_name),'required',true) order by t.started_at,t.id)
        from public.tasks t where t.goal_id=old.goal_id and t.parent_task_id is null
      ),'[]'::jsonb),updated_at=now() where g.id=old.goal_id;
    end if;
  end if;
  return coalesce(new,old);
end; $$;
