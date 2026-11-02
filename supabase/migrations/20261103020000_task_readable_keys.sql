-- New task keys are human-readable while remaining globally unique.
-- Historical task keys are deliberately left unchanged.
create or replace function public.task_ledger_assign_readable_key()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  slug text;
  suffix text;
begin
  if new.task_name is null or btrim(new.task_name) = '' then
    raise exception 'task_name is required to generate a readable task key';
  end if;
  slug := lower(btrim(new.task_name));
  slug := regexp_replace(slug, '[^a-z0-9]+', '-', 'g');
  slug := trim(both '-' from slug);
  slug := left(slug, 56);
  slug := trim(both '-' from slug);
  if slug = '' then slug := 'work-item'; end if;
  suffix := left(replace(new.id::text, '-', ''), 8);
  new.task_key := 'task-' || slug || '-' || suffix;
  return new;
end;
$$;
drop trigger if exists tasks_assign_readable_key on public.tasks;
create trigger tasks_assign_readable_key before insert on public.tasks
for each row execute function public.task_ledger_assign_readable_key();
comment on function public.task_ledger_assign_readable_key() is
'Assigns new tasks a readable, globally unique task key derived from task_name; historical keys are not rewritten.';
