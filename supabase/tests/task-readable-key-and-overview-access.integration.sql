-- Rollback-only integration coverage for readable task keys and overview access.
begin;
do $$
declare generated_key text;
begin
  insert into public.tasks(agent_id, agent_name, task_name, description, status)
  values ('readable-key-test','Readable Key Test','Add Slack task proposal integration','Temporary readable-ID fixture.','queued')
  returning task_key into generated_key;
  if generated_key !~ '^task-add-slack-task-proposal-integration-[0-9a-f]{8}$' then
    raise exception 'Unexpected task key format: %', generated_key;
  end if;
  if has_function_privilege('anon','public.goal_ledger_overview(text[])','EXECUTE') then
    raise exception 'anon must not execute the global goal overview';
  end if;
  if has_function_privilege('authenticated','public.goal_ledger_overview(text[])','EXECUTE') then
    raise exception 'authenticated must not execute the global goal overview';
  end if;
  if not has_function_privilege('service_role','public.goal_ledger_overview(text[])','EXECUTE') then
    raise exception 'service_role must execute the global goal overview';
  end if;
end;
$$;
rollback;
