begin;

select plan(2);

select has_table('public', 'platform_items', 'migration creates the platform_items table');
select is((select count(*)::integer from public.platform_items), 0, 'new table starts empty');

select * from finish();

rollback;
