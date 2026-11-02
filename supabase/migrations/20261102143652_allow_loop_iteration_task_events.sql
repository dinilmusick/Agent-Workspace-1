alter table public.task_events drop constraint if exists task_events_event_type_check;
alter table public.task_events add constraint task_events_event_type_check
check (event_type = any (array['registered','started','heartbeat','progress','tagged','blocked','unblocked','completed','failed','cancelled','abandoned','reopened','note','claimed','released','result_submitted','verified','verification_rejected','iteration_recorded','loop_iteration_recorded','dependency_added','tree_created']::text[]));
