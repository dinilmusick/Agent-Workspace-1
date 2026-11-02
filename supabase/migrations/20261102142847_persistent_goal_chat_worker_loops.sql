-- Persistent goal-scoped ChatGPT workers and mandatory evidence-driven loops.
-- Browser conversations are started manually; GitHub Actions never launches ChatGPT chats.
alter table public.tasks
  add column if not exists claimed_session_id text,
  add column if not exists loop_state jsonb not null default '{}'::jsonb,
  add column if not exists loop_iteration integer not null default 0;

create index if not exists tasks_goal_claimable_idx
  on public.tasks (goal_id, status, priority, started_at)
  where goal_id is not null;
