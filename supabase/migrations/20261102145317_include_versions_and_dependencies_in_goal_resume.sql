create or replace function public.goal_ledger_resume(name_in text) returns jsonb language plpgsql stable set search_path to 'public' as $f$
declare goal_out public.goals; summary_out jsonb; tasks_out jsonb; events_out jsonb; versions_out jsonb; dependencies_out jsonb;
begin
 if nullif(btrim(name_in),'') is null then raise exception 'goal name is required'; end if;
 select * into goal_out from public.goals where lower(name)=lower(btrim(name_in));
 if not found then raise exception 'goal not found: %',name_in; end if;
 summary_out:=public.goal_ledger_summary(goal_out.id);
 select coalesce(jsonb_agg(to_jsonb(t)||jsonb_build_object('iterations',coalesce((select jsonb_agg(to_jsonb(i) order by i.iteration_no) from public.task_iterations i where i.task_id=t.id),'[]'::jsonb)) order by t.priority,t.started_at),'[]'::jsonb) into tasks_out from public.tasks t where t.goal_id=goal_out.id;
 select coalesce(jsonb_agg(to_jsonb(e) order by e.occurred_at),'[]'::jsonb) into events_out from public.goal_events e where e.goal_id=goal_out.id;
 select coalesce(jsonb_agg(to_jsonb(v) order by v.version desc),'[]'::jsonb) into versions_out from public.goal_versions v where v.goal_id=goal_out.id;
 select coalesce(jsonb_agg(to_jsonb(d) order by d.created_at),'[]'::jsonb) into dependencies_out from public.task_dependencies d where exists(select 1 from public.tasks t where t.id=d.task_id and t.goal_id=goal_out.id) or exists(select 1 from public.tasks t where t.id=d.depends_on_task_id and t.goal_id=goal_out.id);
 return jsonb_build_object('goal',to_jsonb(goal_out),'summary',summary_out,'tasks',tasks_out,'dependencies',dependencies_out,'versions',versions_out,'latest_version',versions_out->0,'events',events_out);
end; $f$;