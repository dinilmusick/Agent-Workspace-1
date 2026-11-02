create or replace function public.task_ledger_sync_parameter_fields()
returns trigger language plpgsql set search_path=public
as $$
begin
  new.parameters:=coalesce(new.task_definition->'parameters',new.parameters,'{}'::jsonb);
  new.parameter_contract:=coalesce(new.task_definition->'parameter_contract',new.parameter_contract,'{}'::jsonb);
  new.parameter_values:=coalesce(new.task_definition->'parameter_values',new.parameter_values,'{}'::jsonb);
  perform public.task_ledger_validate_parameter_values(
    jsonb_set(new.parameter_contract,'{required}','[]'::jsonb,true),
    new.parameter_values
  );
  return new;
end;
$$;