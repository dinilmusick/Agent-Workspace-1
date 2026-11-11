create table if not exists public.obstacles (
 id uuid primary key default gen_random_uuid(),
 title text not null, problem text not null, symptoms text[] not null default '{}',
 root_cause text, solution text,
 status text not null default 'active' check (status in ('active','resolved','superseded','archived')),
 severity smallint not null default 3 check (severity between 1 and 5),
 tags text[] not null default '{}', occurrence_count integer not null default 0 check (occurrence_count>=0),
 confidence numeric not null default 0.5 check (confidence between 0 and 1),
 first_encountered_at timestamptz not null default now(), last_encountered_at timestamptz not null default now(),
 metadata jsonb not null default '{}', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists obstacles_status_severity_idx on public.obstacles(status,severity);
create index if not exists obstacles_tags_idx on public.obstacles using gin(tags);
alter table public.obstacles enable row level security;
revoke all on public.obstacles from anon,authenticated;
grant all on public.obstacles to service_role;