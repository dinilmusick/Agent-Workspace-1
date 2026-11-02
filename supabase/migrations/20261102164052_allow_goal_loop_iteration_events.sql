alter table public.goal_events
  drop constraint if exists goal_events_event_type_check;
alter table public.goal_events
  add constraint goal_events_event_type_check check (
    event_type = any(array[
      'created','planned','resumed','context_updated','status_changed',
      'task_tree_created','completed','blocked','note',
      'goal_loop_iteration_recorded'
    ]::text[])
  );