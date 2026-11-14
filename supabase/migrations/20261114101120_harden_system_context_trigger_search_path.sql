create or replace function public.set_system_context_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  new.context_version = old.context_version + 1;
  return new;
end;
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.set_system_context_version()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  new.context_version = old.context_version + 1;
  return new;
end;
$$;