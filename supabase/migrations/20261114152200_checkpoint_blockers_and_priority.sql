begin;

alter table public.goals
  add column if not exists user_priority numeric(4,3) not null default 0.500
  check (user_priority >= 0 and user_priority <= 1);

create table if not exists public.checkpoint_blockers (
  id uuid primary key default gen_random_uuid(),
  blocker_key text not null unique,
  normalized_text text not null unique,
  text text not null,
  status text not null default 'active' check (status in ('active','resolved','superseded')),
  notoriety integer not null default 0 check (notoriety >= 0),
  first_reported_at timestamptz not null default now(),
  last_reported_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by_agent_id text,
  resolution text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.checkpoint_blocker_occurrences (
  id bigint generated always as identity primary key,
  blocker_id uuid not null references public.checkpoint_blockers(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  checkpoint_index smallint not null check (checkpoint_index between 0 and 3),
  agent_id text not null,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  context jsonb not null default '{}'::jsonb,
  evidence jsonb not null default '[]'::jsonb,
  occurred_at timestamptz not null default now(),
  unique (blocker_id, task_id, checkpoint_index, agent_id, attempt_count)
);

alter table public.tasks
  add column if not exists blocker_notoriety integer not null default 0
  check (blocker_notoriety >= 0);

create index if not exists checkpoint_blockers_notoriety_idx
  on public.checkpoint_blockers(status,notoriety desc,last_reported_at desc);

create or replace function public.normalize_checkpoint_blocker_text(input_text text)
returns text language sql immutable set search_path to public as $$
  select trim(regexp_replace(regexp_replace(lower(coalesce(input_text,'')),'[[:space:]]+',' ','g'),'[[:punct:]]+',' ','g'));
$$;

create or replace function public.report_checkpoint_blocker(
  task_id_in uuid, checkpoint_index_in smallint, blocker_text_in text, agent_id_in text,
  claim_token_in uuid default null, context_in jsonb default '{}'::jsonb, evidence_in jsonb default '[]'::jsonb)
returns jsonb language plpgsql set search_path to public as $$
declare
  t public.tasks; c jsonb; normalized text; blocker public.checkpoint_blockers;
  occurrence_inserted boolean; blocker_entry jsonb; blockers jsonb;
begin
  if checkpoint_index_in not between 0 and 3 then raise exception 'checkpoint index must be between 0 and 3'; end if;
  if nullif(btrim(blocker_text_in),'') is null then raise exception 'blocker text is required'; end if;
  if nullif(btrim(agent_id_in),'') is null then raise exception 'agent_id is required'; end if;
  select * into t from public.tasks where id=task_id_in for update;
  if not found then raise exception 'task not found'; end if;
  if t.execution_model <> 'bounded-v2' then raise exception 'task is not bounded-v2'; end if;
  if checkpoint_index_in >= jsonb_array_length(t.checkpoints) then raise exception 'checkpoint does not exist'; end if;
  if claim_token_in is not null and (t.claimed_by_agent_id is distinct from agent_id_in or t.claim_token is distinct from claim_token_in) then
    raise exception 'claim token does not fence the current task owner';
  end if;
  normalized:=public.normalize_checkpoint_blocker_text(blocker_text_in);
  insert into public.checkpoint_blockers(blocker_key,normalized_text,text,status)
  values('blocker-'||substr(md5(normalized),1,16),normalized,btrim(blocker_text_in),'active')
  on conflict(normalized_text) do update set text=excluded.text,status='active',last_reported_at=now(),updated_at=now(),
    resolved_at=null,resolved_by_agent_id=null,resolution=null
  returning * into blocker;

  insert into public.checkpoint_blocker_occurrences(blocker_id,task_id,checkpoint_index,agent_id,attempt_count,context,evidence)
  values(blocker.id,task_id_in,checkpoint_index_in,agent_id_in,t.attempt_count,coalesce(context_in,'{}'::jsonb),coalesce(evidence_in,'[]'::jsonb))
  on conflict(blocker_id,task_id,checkpoint_index,agent_id,attempt_count) do nothing;
  occurrence_inserted:=found;

  if occurrence_inserted then
    update public.checkpoint_blockers set notoriety=(select count(*)::integer from public.checkpoint_blocker_occurrences where blocker_id=blocker.id),
      last_reported_at=now(),updated_at=now() where id=blocker.id returning * into blocker;
  end if;

  c:=t.checkpoints->checkpoint_index_in; blockers:=coalesce(c->'blockers','[]'::jsonb);
  blocker_entry:=jsonb_build_object('blocker_id',blocker.id,'blocker_key',blocker.blocker_key,'text',blocker.text,
    'notoriety',blocker.notoriety,'status','active','reported_by_agent_id',agent_id_in,'last_reported_at',blocker.last_reported_at,
    'context',coalesce(context_in,'{}'::jsonb),'evidence',coalesce(evidence_in,'[]'::jsonb));
  if exists(select 1 from jsonb_array_elements(blockers) x where x->>'blocker_id'=blocker.id::text) then
    select coalesce(jsonb_agg(case when x->>'blocker_id'=blocker.id::text then blocker_entry else x end),'[]'::jsonb)
    into blockers from jsonb_array_elements(blockers) x;
  else blockers:=blockers||jsonb_build_array(blocker_entry); end if;
  c:=c||jsonb_build_object('blockers',blockers,'blocker_notoriety',blocker.notoriety);

  update public.tasks set checkpoints=jsonb_set(t.checkpoints,array[checkpoint_index_in::text],c,false),blocker=blocker.text,
    blocker_notoriety=greatest(coalesce(blocker_notoriety,0),blocker.notoriety),status='blocked',updated_at=now(),
    heartbeat_context=coalesce(heartbeat_context,'{}'::jsonb)||jsonb_build_object('blocker_id',blocker.id,'blocker_key',blocker.blocker_key,'blocker_notoriety',blocker.notoriety,'blocked_at',now())
  where id=task_id_in;

  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'blocker_reported',agent_id_in,'Checkpoint blocker recorded; task blocked until the blocker is resolved.',
    jsonb_build_object('checkpoint_index',checkpoint_index_in,'blocker_id',blocker.id,'blocker_key',blocker.blocker_key,'notoriety',blocker.notoriety,'occurrence_inserted',occurrence_inserted));
  return jsonb_build_object('task_id',task_id_in,'checkpoint_index',checkpoint_index_in,'blocker_id',blocker.id,'blocker_key',blocker.blocker_key,'notoriety',blocker.notoriety,'notorious',blocker.notoriety>5,'occurrence_inserted',occurrence_inserted);
end;
$$;

create or replace function public.resolve_checkpoint_blocker(
  task_id_in uuid, checkpoint_index_in smallint, blocker_id_in uuid, agent_id_in text,
  resolution_in text, evidence_in jsonb default '[]'::jsonb)
returns jsonb language plpgsql set search_path to public as $$
declare t public.tasks; c jsonb; blockers jsonb; updated jsonb;
begin
  select * into t from public.tasks where id=task_id_in for update;
  if not found then raise exception 'task not found'; end if;
  if checkpoint_index_in<0 or checkpoint_index_in>=jsonb_array_length(t.checkpoints) then raise exception 'checkpoint does not exist'; end if;
  c:=t.checkpoints->checkpoint_index_in; blockers:=coalesce(c->'blockers','[]'::jsonb);
  if not exists(select 1 from jsonb_array_elements(blockers) x where x->>'blocker_id'=blocker_id_in::text) then raise exception 'blocker is not attached to checkpoint'; end if;
  select coalesce(jsonb_agg(case when x->>'blocker_id'=blocker_id_in::text then x||jsonb_build_object('status','resolved','resolution',resolution_in,'resolved_by_agent_id',agent_id_in,'resolved_at',now(),'resolution_evidence',coalesce(evidence_in,'[]'::jsonb)) else x end),'[]'::jsonb)
  into updated from jsonb_array_elements(blockers) x;
  update public.checkpoint_blockers set status='resolved',resolved_at=now(),resolved_by_agent_id=agent_id_in,resolution=resolution_in,updated_at=now() where id=blocker_id_in;
  c:=c||jsonb_build_object('blockers',updated);
  update public.tasks set checkpoints=jsonb_set(t.checkpoints,array[checkpoint_index_in::text],c,false),blocker=null,status='queued',
    claimed_by_agent_id=null,claimed_by_agent_name=null,claimed_session_id=null,claim_token=null,claimed_at=null,claim_expires_at=null,
    heartbeat_at=now(),updated_at=now(),heartbeat_context=jsonb_build_object('activity','blocker_resolved','next_action','Reclaim task and retry the persisted checkpoint.')
  where id=task_id_in;
  insert into public.task_events(task_id,event_type,agent_id,message,payload)
  values(task_id_in,'blocker_resolved',agent_id_in,'Checkpoint blocker resolved and task requeued.',jsonb_build_object('checkpoint_index',checkpoint_index_in,'blocker_id',blocker_id_in));
  return jsonb_build_object('task_id',task_id_in,'checkpoint_index',checkpoint_index_in,'blocker_id',blocker_id_in,'resolved',true);
end;
$$;

create or replace function public.goal_ledger_blocker_overview(goal_key_in text default null)
returns table(goal_key text,goal_name text,user_priority numeric,task_key text,task_name text,checkpoint_index smallint,
  blocker_id uuid,blocker_key text,blocker_text text,notoriety integer,notorious boolean,status text,last_reported_at timestamptz)
language sql set search_path to public as $$
  select g.goal_key,g.name,g.user_priority,t.task_key,t.task_name,x.ordinality::smallint-1,cb.id,cb.blocker_key,cb.text,cb.notoriety,
    (cb.notoriety>5),cb.status,cb.last_reported_at
  from public.goals g join public.tasks t on t.goal_id=g.id
  cross join lateral jsonb_array_elements(t.checkpoints) with ordinality x(c,ordinality)
  join lateral jsonb_array_elements(coalesce(x.c->'blockers','[]'::jsonb)) b on true
  join public.checkpoint_blockers cb on cb.id=nullif(b->>'blocker_id','')::uuid
  where (goal_key_in is null or g.goal_key=goal_key_in) and cb.status='active'
  order by g.user_priority desc,cb.notoriety desc,t.priority asc,cb.last_reported_at desc;
$$;

create or replace function public.goal_ledger_set_priority(goal_key_in text,priority_in numeric,agent_id_in text)
returns public.goals language plpgsql set search_path to public as $$
declare g public.goals;
begin
  if priority_in is null or priority_in<0 or priority_in>1 then raise exception 'priority must be normalized to 0..1'; end if;
  update public.goals set user_priority=priority_in,updated_at=now()
  where goal_key=goal_key_in and (auth.uid() is null or owner_user_id=auth.uid()) returning * into g;
  if not found then raise exception 'goal not found or access denied: %',goal_key_in; end if;
  insert into public.goal_events(goal_id,event_type,agent_id,message,payload)
  values(g.id,'priority_changed',agent_id_in,'User-defined goal priority changed',jsonb_build_object('user_priority',priority_in));
  return g;
end;
$$;

commit;
-- Ensure every newly prepared bounded-v2 checkpoint has a blocker section.
create or replace function public.prepare_bounded_checkpoint_predicates()
returns trigger language plpgsql set search_path to public as $$
declare i integer:=0; c jsonb; p jsonb; pred jsonb;
begin
  if new.execution_model <> 'bounded-v2' then return new; end if;
  for c in select value from jsonb_array_elements(new.checkpoints) loop
    p:=coalesce(new.completion_parameters->i,'{}'::jsonb);
    pred:=coalesce(p->'predicate',new.task_definition->'completion_predicates'->i,jsonb_build_object('key','builtin.evidence_present','version',1));
    c:=c||jsonb_build_object('blockers',coalesce(c->'blockers','[]'::jsonb));
    if nullif(btrim(c->>'predicate_key'),'') is null then
      c:=c||jsonb_build_object('predicate_key',pred->>'key','predicate_version',coalesce((pred->>'version')::integer,1));
    end if;
    new.checkpoints:=jsonb_set(new.checkpoints,array[i::text],c,false); i:=i+1;
  end loop;
  return new;
end;
$$;

-- Claim ordering is: user goal priority -> blocker notoriety -> existing task priority.
-- Apply the same ordering in both goal-scoped and global claim functions. Existing claim
-- logic remains unchanged except for the ORDER BY and blocker-aware heartbeat context.
