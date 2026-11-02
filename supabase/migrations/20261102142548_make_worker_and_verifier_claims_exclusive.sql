-- Atomic, lease-based claims for execution workers and independent verifiers.
alter table public.tasks
  add column if not exists verification_claimed_by_agent_id text,
  add column if not exists verification_claim_token uuid,
  add column if not exists verification_claim_expires_at timestamptz;
create index if not exists tasks_verification_claim_idx
  on public.tasks(verification_status,verification_claim_expires_at)
  where verification_status='pending';
create or replace function public.task_ledger_claim_next(
 agent_id_in text,agent_name_in text,agent_type_in text default 'worker',
 capabilities_in text[] default '{}'::text[],lease_seconds_in integer default 900
) returns setof public.tasks language plpgsql set search_path=public as $f$
declare candidate_id uuid; task_out public.tasks; lease_value integer:=greatest(30,least(coalesce(lease_seconds_in,900),86400));
begin
 if nullif(btrim(agent_id_in),'') is null or nullif(btrim(agent_name_in),'') is null then raise exception 'agent identity is required'; end if;
 select t.id into candidate_id from public.tasks t where t.status in ('queued','running')
 and t.attempt_count<t.max_attempts and (t.claim_expires_at is null or t.claim_expires_at<now())
 and t.required_capabilities<@coalesce(capabilities_in,'{}'::text[])
 and not exists(select 1 from public.tasks child where child.parent_task_id=t.id)
 and (t.parent_task_id is null or not exists(select 1 from public.tasks p where p.id=t.parent_task_id and p.status in ('failed','cancelled','abandoned')))
 and not exists(select 1 from public.task_dependencies d join public.tasks dep on dep.id=d.depends_on_task_id
  where d.task_id=t.id and d.dependency_type='blocking' and (dep.status<>'completed' or dep.verification_status<>'verified'))
 order by t.priority asc,t.started_at asc for update skip locked limit 1;
 if candidate_id is null then return; end if;
 update public.tasks set status='running',claimed_by_agent_id=agent_id_in,claimed_by_agent_name=agent_name_in,
 claim_token=gen_random_uuid(),claimed_at=now(),claim_expires_at=now()+make_interval(secs=>lease_value),
 attempt_count=attempt_count+1,heartbeat_at=now(),updated_at=now(),current_step='Claimed by worker agent'
 where id=candidate_id returning * into task_out;
 insert into public.task_events(task_id,event_type,agent_id,message,payload)
 values(task_out.id,'claimed',agent_id_in,'Task claimed by worker',jsonb_build_object('lease_expires_at',task_out.claim_expires_at,'attempt_count',task_out.attempt_count));
 return next task_out;
end; $f$;
create or replace function public.task_ledger_claim_verification(verifier_agent_id_in text,lease_seconds_in integer default 900)
returns setof public.tasks language plpgsql set search_path=public as $f$
declare candidate_id uuid; task_out public.tasks; lease_value integer:=greatest(30,least(coalesce(lease_seconds_in,900),86400));
begin
 if nullif(btrim(verifier_agent_id_in),'') is null then raise exception 'verifier identity is required'; end if;
 select t.id into candidate_id from public.tasks t where t.verification_status='pending' and t.result_submitted_at is not null
 and (t.verification_claim_expires_at is null or t.verification_claim_expires_at<now())
 and not exists(select 1 from public.tasks child where child.parent_task_id=t.id)
 order by t.result_submitted_at asc for update skip locked limit 1;
 if candidate_id is null then return; end if;
 update public.tasks set verification_claimed_by_agent_id=verifier_agent_id_in,
 verification_claim_token=gen_random_uuid(),verification_claim_expires_at=now()+make_interval(secs=>lease_value),updated_at=now()
 where id=candidate_id returning * into task_out;
 return next task_out;
end; $f$;
create or replace function public.task_ledger_verify_result_claimed(
 task_id_in uuid,verifier_agent_id_in text,verification_claim_token_in uuid,verified_in boolean,verification_report_in jsonb
) returns public.tasks language plpgsql set search_path=public as $f$
declare task_out public.tasks;
begin
 update public.tasks set verification_claimed_by_agent_id=null,verification_claim_token=null,verification_claim_expires_at=null
 where id=task_id_in and verification_status='pending' and verification_claimed_by_agent_id=verifier_agent_id_in
 and verification_claim_token=verification_claim_token_in and verification_claim_expires_at>now();
 if not found then raise exception 'verification claim missing, expired, or owned by another verifier'; end if;
 return public.task_ledger_verify_result(task_id_in,verifier_agent_id_in,verified_in,coalesce(verification_report_in,'{}'::jsonb));
end; $f$;
revoke all on function public.task_ledger_claim_verification(text,integer) from public,anon,authenticated;
revoke all on function public.task_ledger_verify_result_claimed(uuid,text,uuid,boolean,jsonb) from public,anon,authenticated;
grant execute on function public.task_ledger_claim_verification(text,integer) to service_role;
grant execute on function public.task_ledger_verify_result_claimed(uuid,text,uuid,boolean,jsonb) to service_role;
