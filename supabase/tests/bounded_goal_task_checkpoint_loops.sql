begin;

select plan(10);

select has_column('public','goals','completion_parameters','goals expose bounded completion parameters');
select has_column('public','tasks','execution_model','tasks expose execution model');
select has_column('public','tasks','completion_parameters','tasks expose completion parameters');
select has_column('public','tasks','checkpoints','tasks expose checkpoints');
select has_column('public','tasks','current_checkpoint_index','tasks expose checkpoint pointer');

select ok(
  (select count(*) <= 4 from public.tasks where parent_task_id is null group by goal_id order by count(*) desc limit 1),
  'no existing goal exceeds four direct tasks'
);

select ok(
  exists(select 1 from pg_trigger where tgname='tasks_enforce_goal_direct_task_cap'),
  'database trigger enforces four-task goal cap'
);

select ok(
  exists(select 1 from pg_trigger where tgname='tasks_validate_bounded_model'),
  'database trigger validates bounded task checkpoints'
);

select ok(
  exists(select 1 from pg_trigger where tgname='tasks_require_all_bounded_checkpoints'),
  'database trigger gates bounded task completion on checkpoints'
);

select ok(
  exists(select 1 from pg_proc where proname='goal_ledger_create_hierarchical'),
  'hierarchical goal creator is present'
);

select * from finish();
rollback;
