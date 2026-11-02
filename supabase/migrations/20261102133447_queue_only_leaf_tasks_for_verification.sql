-- Verifiers process leaf results first; parent tasks are finalized after all children pass.
create or replace function public.task_ledger_pending_verification()
returns setof public.tasks
language sql
stable
set search_path to 'public'
as $function$
  select t.*
  from public.tasks t
  where t.status = 'completed'
    and t.verification_status = 'pending'
    and not exists (
      select 1 from public.tasks child where child.parent_task_id = t.id
    )
  order by t.result_submitted_at nulls last, t.priority, t.started_at;
$function$;
