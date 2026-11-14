create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.set_system_context_version()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  new.context_version = old.context_version + 1;
  return new;
end;
$$;

drop trigger if exists systems_updated_at on public.systems;
create trigger systems_updated_at before update on public.systems
for each row execute function public.set_system_context_version();

drop trigger if exists system_memories_updated_at on public.system_memories;
create trigger system_memories_updated_at before update on public.system_memories
for each row execute function public.set_updated_at();

drop trigger if exists system_functions_updated_at on public.system_functions;
create trigger system_functions_updated_at before update on public.system_functions
for each row execute function public.set_updated_at();
