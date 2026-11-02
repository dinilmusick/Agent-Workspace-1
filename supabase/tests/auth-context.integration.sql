-- Verifies the local seeded identity resolves through Supabase auth.uid().
-- Runs in a transaction and leaves no state behind.
begin;
select set_config('request.jwt.claim.sub','f4a1c1d0-7f00-4a00-9000-000000000017',true);
set local role authenticated;
do $test$
begin
  if auth.uid() is distinct from 'f4a1c1d0-7f00-4a00-9000-000000000017'::uuid then
    raise exception 'auth.uid() did not resolve the seeded local test identity';
  end if;
end;
$test$;
rollback;
