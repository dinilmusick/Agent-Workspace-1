-- Completion predicate definitions and execution history are server-side coordination state.
alter table public.completion_predicates enable row level security;
alter table public.predicate_executions enable row level security;

revoke all on table public.completion_predicates, public.predicate_executions from anon, authenticated;
grant select, insert, update, delete on table public.completion_predicates to service_role;
grant select, insert, update, delete on table public.predicate_executions to service_role;

grant execute on function public.record_checkpoint_predicate_result(
  uuid,smallint,text,integer,jsonb,jsonb,boolean,jsonb,text,text
) to service_role;

-- Do not expose the completion registry through the client Data API.
drop policy if exists completion_predicates_service_role_only on public.completion_predicates;
drop policy if exists predicate_executions_service_role_only on public.predicate_executions;
create policy completion_predicates_service_role_only
  on public.completion_predicates for all to service_role using (true) with check (true);
create policy predicate_executions_service_role_only
  on public.predicate_executions for all to service_role using (true) with check (true);
