begin;

select plan(12);
select has_column('public','goals','goal_type','goals have a type');
select has_column('public','goals','target','goals have one target');
select has_column('public','goals','behavior_inputs','goals have target inputs');
select has_column('public','goals','expected_outputs','goals have expected outputs');
select has_column('public','tasks','task_type','tasks have a type');
select has_column('public','tasks','target','tasks have one target');
select has_table('public','visions','visions persist target decomposition');
select has_table('public','vision_targets','visions persist component targets');
select has_table('public','vision_target_goals','component targets link goals');
select has_table('public','vision_canvas_pages','tldraw pages are persisted');
select ok(public.validate_omni_target('{"type":"repository","id":"example/repo"}'::jsonb),'valid repository target');
select throws_ok($$select public.validate_omni_target('{"type":"repository"}'::jsonb)$$,'P0001','target requires exactly one typed identity: type + id','invalid target rejected');
select * from finish();
rollback;
