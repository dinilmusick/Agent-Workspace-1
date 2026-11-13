begin;

select plan(15);

select has_table('public','completion_predicates','completion predicate registry exists');
select has_table('public','predicate_executions','predicate execution audit exists');
select has_column('public','tasks','completion_predicate_version','tasks carry predicate version');
select ok(
  exists(select 1 from pg_proc where proname='record_checkpoint_predicate_result'),
  'predicate execution is the authoritative checkpoint completion function'
);
select ok(
  exists(select 1 from pg_trigger where tgname='tasks_require_predicate_backed_checkpoint_success'),
  'successful checkpoints require predicate execution'
);
select ok(
  exists(select 1 from pg_trigger where tgname='tasks_validate_bounded_checkpoint_predicates'),
  'bounded checkpoints require registered predicates'
);
select ok(
  exists(select 1 from pg_trigger where tgname='tasks_prepare_bounded_checkpoint_predicates'),
  'checkpoint predicates are bound before validation'
);
select ok(
  exists(select 1 from pg_trigger where tgname='completion_predicates_immutable'),
  'predicate definitions are immutable'
);
select ok(
  exists(select 1 from pg_trigger where tgname='goals_require_bounded_task_completion'),
  'goal completion is gated by direct task completion'
);
select ok(
  exists(select 1 from public.completion_predicates
         where predicate_key='builtin.evidence_present' and version=1),
  'infrastructure fallback predicate is registered'
);
select ok(
  (select relrowsecurity from pg_class where oid='public.completion_predicates'::regclass),
  'completion predicate registry has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid='public.predicate_executions'::regclass),
  'predicate execution audit has RLS enabled'
);

select * from finish();
rollback;

select ok(exists(select 1 from pg_trigger where tgname='completion_predicates_immutable_delete'),'predicate definitions cannot be deleted');

-- The validator must be callable by bounded task creation without variable/column ambiguity.
select lives_ok($$select public.task_ledger_create_tree('predicate-regression','predicate-regression','{"name":"predicate-regression","description":"temporary","general_pattern":"bounded verification","actions":[{"description":"verify"}],"completion_parameters":[{"id":"verify","description":"evidence exists"}]}'::jsonb)$$,'bounded task creation binds a machine predicate');
select lives_ok($$select public.record_checkpoint_predicate_result((select id from public.tasks where task_key is not null order by updated_at desc limit 1),0,'builtin.evidence_present',1,'{"evidence":["test"]}'::jsonb,'true'::jsonb,true,'["test://predicate"]'::jsonb,'predicate-test','test-fence')$$,'predicate result RPC is callable');

rollback;
