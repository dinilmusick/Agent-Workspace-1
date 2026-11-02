create or replace function public.goal_ledger_finalize(
 goal_name_in text, finalized_by_agent_id_in text, verification_report_in jsonb default '{}'::jsonb
) returns public.goals language plpgsql set search_path to 'public' as $function$
declare goal_out public.goals; changed integer;
begin
 select * into goal_out from public.goals where lower(name)=lower(btrim(goal_name_in)) for update;
 if not found then raise exception 'goal not found'; end if;
 if goal_out.created_by_agent_id<>finalized_by_agent_id_in and not exists(
  select 1 from public.agent_registry a where a.agent_id=finalized_by_agent_id_in and a.enabled
   and a.agent_type in ('orchestrator','verifier','supervisor')
 ) then raise exception 'goal finalization requires its orchestrator or an enabled verifier'; end if;
 loop
  update public.tasks p set status='completed',verification_status='verified',
   verification_report=coalesce(verification_report_in,'{}'::jsonb),
   verified_by_agent_id=finalized_by_agent_id_in,verified_at=now(),completed_at=now(),
   outcome=coalesce(p.outcome,'All child tasks independently verified'),updated_at=now()
  where p.goal_id=goal_out.id
   and exists(select 1 from public.tasks c where c.parent_task_id=p.id)
   and not (p.status='completed' and p.verification_status='verified')
   and not exists(select 1 from public.tasks c where c.parent_task_id=p.id
    and not (c.status='completed' and c.verification_status='verified'));
  get diagnostics changed=row_count;
  exit when changed=0;
 end loop;
 if exists(select 1 from public.tasks t where t.goal_id=goal_out.id
   and not (t.status='completed' and t.verification_status in ('verified','not_required'))) then
  raise exception 'goal cannot complete: one or more tasks are unfinished or unverified';
 end if;
 update public.goals set status='completed',completed_at=now(),updated_at=now()
 where id=goal_out.id returning * into goal_out;
 insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
 values(goal_out.id,'completed',finalized_by_agent_id_in,'All goal tasks completed and verified',
  jsonb_build_object('verification_report',coalesce(verification_report_in,'{}'::jsonb)));
 return goal_out;
end; $function$;

create or replace function public.enforce_goal_completion()
returns trigger language plpgsql set search_path to 'public' as $function$
begin
 if new.status='completed' and old.status is distinct from 'completed'
  and exists(select 1 from public.tasks t where t.goal_id=new.id
   and not (t.status='completed' and t.verification_status in ('verified','not_required'))) then
  raise exception 'goal cannot be completed until every task is completed and verified';
 end if;
 return new;
end; $function$;
drop trigger if exists goals_require_verified_tasks on public.goals;
create trigger goals_require_verified_tasks before update of status on public.goals
for each row execute function public.enforce_goal_completion();
revoke all on function public.goal_ledger_finalize(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.goal_ledger_finalize(text,text,jsonb) to service_role;
