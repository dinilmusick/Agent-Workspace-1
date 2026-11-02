create or replace function public.task_ledger_validate_completion_parameters()
returns trigger language plpgsql set search_path=public
as $$
begin
  if new.status='completed' and old.status is distinct from 'completed' then
    perform public.task_ledger_validate_parameter_values(
      new.parameter_contract,new.parameter_values
    );
  end if;
  return new;
end;
$$;

drop trigger if exists tasks_validate_completion_parameters on public.tasks;
create trigger tasks_validate_completion_parameters
before update of status on public.tasks
for each row execute function public.task_ledger_validate_completion_parameters();
