-- Enable direct, owner-scoped Supabase connector calls for browser ChatGPT agents.
-- All table writes remain protected by existing owner RLS policies.
grant insert,update,delete on public.goals,public.goal_versions,public.goal_events,
 public.tasks,public.task_iterations,public.task_dependencies,public.task_events to authenticated;
grant usage,select on all sequences in schema public to authenticated;

create or replace function public.goal_ledger_create_with_tasks(
 name_in text,description_in text,context_in jsonb,instructions_in text,acceptance_criteria_in jsonb,
 created_by_agent_id_in text,task_definition_in jsonb,owner_user_id_in uuid default auth.uid(),metadata_in jsonb default '{}'::jsonb
) returns jsonb language plpgsql security invoker set search_path to 'public' as $function$
declare goal_out public.goals; root_task_id uuid; definition jsonb; owner_id uuid;
begin
 perform public.goal_ledger_validate_task_loop(task_definition_in,0);
 owner_id:=coalesce(owner_user_id_in,auth.uid());
 if auth.uid() is not null and owner_id is distinct from auth.uid() then
  raise exception 'goal owner must be the authenticated user';
 end if;
 goal_out:=public.goal_ledger_create(name_in,description_in,context_in,instructions_in,
  acceptance_criteria_in,created_by_agent_id_in,owner_id,metadata_in);
 definition:=jsonb_set(task_definition_in,'{goal_id}',to_jsonb(goal_out.id::text),true);
 root_task_id:=public.task_ledger_create_tree(created_by_agent_id_in,created_by_agent_id_in,definition,null,null,'orchestrator');
 update public.goals set status='ready',updated_at=now() where id=goal_out.id returning * into goal_out;
 insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
 values(goal_out.id,'planned',created_by_agent_id_in,'Goal and loop-backed task tree created',
  jsonb_build_object('root_task_id',root_task_id,'loop_contracts_required',true));
 return jsonb_build_object('goal',to_jsonb(goal_out),'root_task_id',root_task_id);
end; $function$;

create or replace function public.goal_ledger_claim_task(
 goal_name_in text,agent_id_in text,agent_name_in text,agent_type_in text default 'worker',
 capabilities_in text[] default '{}',session_id_in text default null,lease_seconds_in integer default 900
) returns setof public.tasks language plpgsql security invoker set search_path to 'public' as $function$
declare goal_id_value uuid; creator_id text; candidate_id uuid; task_out public.tasks;
 lease_value integer:=greatest(30,least(coalesce(lease_seconds_in,900),86400));
begin
 if nullif(btrim(goal_name_in),'') is null or nullif(btrim(agent_id_in),'') is null
  or nullif(btrim(agent_name_in),'') is null or nullif(btrim(session_id_in),'') is null then
  raise exception 'goal name, agent identity and unique chat session_id are required';
 end if;
 select id,created_by_agent_id into goal_id_value,creator_id from public.goals
  where lower(name)=lower(btrim(goal_name_in))
   and (auth.uid() is null or owner_user_id=auth.uid())
   and status in ('ready','active');
 if goal_id_value is null then raise exception 'goal not found or access denied: %',goal_name_in; end if;
 if agent_id_in=creator_id then raise exception 'worker agent_id must differ from the orchestrator agent_id'; end if;
 select t.id into candidate_id from public.tasks t
 where t.goal_id=goal_id_value and t.status in ('queued','running')
  and t.attempt_count<t.max_attempts and (t.claim_expires_at is null or t.claim_expires_at<now())
  and t.required_capabilities<@coalesce(capabilities_in,'{}'::text[])
  and not exists(select 1 from public.tasks child where child.parent_task_id=t.id)
  and (t.parent_task_id is null or not exists(select 1 from public.tasks p where p.id=t.parent_task_id and p.status in ('failed','cancelled','abandoned')))
  and not exists(select 1 from public.task_dependencies d join public.tasks dep on dep.id=d.depends_on_task_id
    where d.task_id=t.id and d.dependency_type='blocking' and (dep.status<>'completed' or dep.verification_status<>'verified'))
 order by t.priority asc,t.started_at asc for update skip locked limit 1;
 if candidate_id is null then return; end if;
 update public.tasks set status='running',claimed_by_agent_id=agent_id_in,claimed_by_agent_name=agent_name_in,
  claimed_session_id=session_id_in,claim_token=gen_random_uuid(),claimed_at=now(),
  claim_expires_at=now()+make_interval(secs=>lease_value),attempt_count=attempt_count+1,
  heartbeat_at=now(),updated_at=now(),current_step='Claimed by ChatGPT worker'
 where id=candidate_id returning * into task_out;
 update public.goals set status='active',updated_at=now() where id=goal_id_value and status='ready';
 insert into public.task_events(task_id,event_type,agent_id,message,payload)
 values(task_out.id,'claimed',agent_id_in,'Goal-scoped ChatGPT worker claimed task',
  jsonb_build_object('goal_id',goal_id_value,'session_id',session_id_in,'lease_expires_at',task_out.claim_expires_at,'attempt_count',task_out.attempt_count));
 return next task_out;
end; $function$;

revoke all on function public.goal_ledger_validate_task_loop(jsonb,integer) from public,anon;
grant execute on function public.goal_ledger_validate_task_loop(jsonb,integer) to authenticated,service_role;
revoke all on function public.goal_ledger_create_with_tasks(text,text,jsonb,text,jsonb,text,jsonb,uuid,jsonb) from public,anon;
grant execute on function public.goal_ledger_create_with_tasks(text,text,jsonb,text,jsonb,text,jsonb,uuid,jsonb) to authenticated,service_role;
revoke all on function public.goal_ledger_claim_task(text,text,text,text,text[],text,integer) from public,anon;
grant execute on function public.goal_ledger_claim_task(text,text,text,text,text[],text,integer) to authenticated,service_role;
revoke all on function public.task_ledger_record_loop_iteration(uuid,text,uuid,integer,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,text,text) from public,anon;
grant execute on function public.task_ledger_record_loop_iteration(uuid,text,uuid,integer,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,text,text) to authenticated,service_role;
revoke all on function public.goal_ledger_resume(text) from public,anon;
grant execute on function public.goal_ledger_resume(text) to authenticated,service_role;
revoke all on function public.goal_ledger_list(text) from public,anon;
grant execute on function public.goal_ledger_list(text) to authenticated,service_role;
revoke all on function public.goal_ledger_summary(uuid) from public,anon;
grant execute on function public.goal_ledger_summary(uuid) to authenticated,service_role;
revoke all on function public.goal_ledger_finalize(text,text,jsonb) from public,anon;
grant execute on function public.goal_ledger_finalize(text,text,jsonb) to authenticated,service_role;
revoke all on function public.enforce_leaf_task_loop_pass() from public,anon,authenticated;
revoke all on function public.enforce_goal_completion() from public,anon,authenticated;
