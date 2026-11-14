create table if not exists public.systems (
  id uuid primary key default gen_random_uuid(),
  system_key text not null unique default ('system_' || replace(gen_random_uuid()::text, '-', '')),
  parent_system_id uuid references public.systems(id) on delete restrict,
  owner_user_id uuid,
  name text not null,
  system_type text not null default 'general',
  description text not null default '',
  status text not null default 'active' check (status in ('planned','active','paused','archived','retired')),
  parameters jsonb not null default '{}'::jsonb check (jsonb_typeof(parameters) = 'object'),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  context_version integer not null default 1 check (context_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists systems_parent_system_id_idx on public.systems(parent_system_id);
create index if not exists systems_owner_user_id_idx on public.systems(owner_user_id);
create index if not exists systems_type_status_idx on public.systems(system_type, status);

create table if not exists public.system_memories (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  memory_key text not null,
  title text not null,
  content text not null,
  memory_type text not null default 'general' check (memory_type in ('general','decision','constraint','observation','change','fact','warning','milestone')),
  importance smallint not null default 3 check (importance between 1 and 5),
  status text not null default 'active' check (status in ('active','superseded','archived')),
  occurred_at timestamptz not null default now(),
  source_type text,
  source_id text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(system_id, memory_key)
);
create index if not exists system_memories_system_id_idx on public.system_memories(system_id);
create index if not exists system_memories_active_idx on public.system_memories(system_id, status, importance desc);

create table if not exists public.system_functions (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.systems(id) on delete cascade,
  function_key text not null,
  name text not null,
  description text not null default '',
  input_contract jsonb not null default '{}'::jsonb check (jsonb_typeof(input_contract) = 'object'),
  output_contract jsonb not null default '{}'::jsonb check (jsonb_typeof(output_contract) = 'object'),
  transformation text not null default '',
  improvement_target jsonb not null default '{}'::jsonb check (jsonb_typeof(improvement_target) = 'object'),
  acceptance_criteria jsonb not null default '[]'::jsonb check (jsonb_typeof(acceptance_criteria) = 'array'),
  status text not null default 'active' check (status in ('planned','active','paused','retired')),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(system_id, function_key)
);
create index if not exists system_functions_system_id_idx on public.system_functions(system_id);

create table if not exists public.system_function_subsystems (
  function_id uuid not null references public.system_functions(id) on delete cascade,
  subsystem_id uuid not null references public.systems(id) on delete cascade,
  contribution text not null default '',
  ordinal integer not null default 0 check (ordinal >= 0),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  primary key (function_id, subsystem_id)
);
create index if not exists system_function_subsystems_subsystem_id_idx on public.system_function_subsystems(subsystem_id);

create table if not exists public.system_relationships (
  id uuid primary key default gen_random_uuid(),
  source_system_id uuid not null references public.systems(id) on delete cascade,
  target_system_id uuid not null references public.systems(id) on delete cascade,
  relation_type text not null check (relation_type in ('depends_on','integrates_with','interacts_with','hosts','deployed_on','derived_from','related_to')),
  description text not null default '',
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  unique(source_system_id, target_system_id, relation_type),
  check (source_system_id <> target_system_id)
);
create index if not exists system_relationships_target_idx on public.system_relationships(target_system_id);

alter table public.goals add column if not exists system_id uuid references public.systems(id) on delete set null;
alter table public.tasks add column if not exists system_id uuid references public.systems(id) on delete set null;
alter table public.obstacles add column if not exists system_id uuid references public.systems(id) on delete set null;
create index if not exists goals_system_id_idx on public.goals(system_id);
create index if not exists tasks_system_id_idx on public.tasks(system_id);
create index if not exists obstacles_system_id_idx on public.obstacles(system_id);

create or replace function public.set_system_context_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  new.context_version = old.context_version + 1;
  return new;
end;
$$;

drop trigger if exists systems_updated_at on public.systems;
create trigger systems_updated_at before update on public.systems for each row execute function public.set_system_context_updated_at();

alter table public.systems enable row level security;
alter table public.system_memories enable row level security;
alter table public.system_functions enable row level security;
alter table public.system_function_subsystems enable row level security;
alter table public.system_relationships enable row level security;

drop policy if exists systems_owner_access on public.systems;
create policy systems_owner_access on public.systems for all to authenticated
using (owner_user_id = (select auth.uid()))
with check (owner_user_id = (select auth.uid()));

drop policy if exists system_memories_owner_access on public.system_memories;
create policy system_memories_owner_access on public.system_memories for all to authenticated
using (exists (select 1 from public.systems s where s.id = system_memories.system_id and s.owner_user_id = (select auth.uid())))
with check (exists (select 1 from public.systems s where s.id = system_memories.system_id and s.owner_user_id = (select auth.uid())));

drop policy if exists system_functions_owner_access on public.system_functions;
create policy system_functions_owner_access on public.system_functions for all to authenticated
using (exists (select 1 from public.systems s where s.id = system_functions.system_id and s.owner_user_id = (select auth.uid())))
with check (exists (select 1 from public.systems s where s.id = system_functions.system_id and s.owner_user_id = (select auth.uid())));

drop policy if exists system_function_subsystems_owner_access on public.system_function_subsystems;
create policy system_function_subsystems_owner_access on public.system_function_subsystems for all to authenticated
using (
  exists (select 1 from public.system_functions f join public.systems s on s.id=f.system_id
          where f.id=system_function_subsystems.function_id and s.owner_user_id=(select auth.uid()))
)
with check (
  exists (select 1 from public.system_functions f join public.systems s on s.id=f.system_id
          where f.id=system_function_subsystems.function_id and s.owner_user_id=(select auth.uid()))
  and exists (select 1 from public.systems s
              where s.id=system_function_subsystems.subsystem_id and s.owner_user_id=(select auth.uid()))
);

drop policy if exists system_relationships_owner_access on public.system_relationships;
create policy system_relationships_owner_access on public.system_relationships for all to authenticated
using (exists (select 1 from public.systems s where s.id=system_relationships.source_system_id and s.owner_user_id=(select auth.uid())))
with check (
  exists (select 1 from public.systems s where s.id=system_relationships.source_system_id and s.owner_user_id=(select auth.uid()))
  and exists (select 1 from public.systems s where s.id=system_relationships.target_system_id and s.owner_user_id=(select auth.uid()))
);
