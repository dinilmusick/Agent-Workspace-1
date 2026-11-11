create or replace function public.enforce_goal_completion() returns trigger language plpgsql set search_path=public as $fn$
begin
  if new.status='completed' and old.status is distinct from 'completed' and public.goal_has_unverified_descendant_tasks(new.id) then
    raise exception 'goal cannot be completed until every descendant task is completed and verified';
  end if;
  return new;
end; $fn$;
create or replace function public.goals_require_goal_loop_pass() returns trigger language plpgsql set search_path=public as $fn$
declare latest public.goal_iterations;
begin
  if new.status='completed' and old.status is distinct from 'completed' and new.goal_loop_definition->>'enabled'='true' then
    select * into latest from public.goal_iterations where goal_id=new.id order by iteration_no desc limit 1;
    if latest.id is null or latest.verdict<>'pass' or jsonb_array_length(latest.evidence)=0
       or exists(select 1 from jsonb_array_elements(latest.criterion_results) c where c->>'status'<>'satisfied') then
      raise exception 'goal cannot complete before its own goal loop passes with evidence';
    end if;
    if public.goal_has_unverified_descendant_tasks(new.id) then
      raise exception 'goal cannot complete before every descendant task is independently verified';
    end if;
  end if;
  return new;
end; $fn$;