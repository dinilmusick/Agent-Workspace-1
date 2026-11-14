create table public.universes (
  id uuid primary key default gen_random_uuid(),
  universe_key text not null unique,
  owner_user_id uuid,
  name text not null,
  description text,
  parameters jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'active' check (status in ('planned','active','paused','archived','retired')),
  context_version integer not null default 1 check (context_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.systems add column universe_id uuid;
insert into public.universes (universe_key,name,description)
values ('legacy','Legacy Universe','Automatically created while introducing first-class universes');
update public.systems set universe_id=(select id from public.universes where universe_key='legacy') where universe_id is null;
alter table public.systems alter column universe_id set not null;
alter table public.systems add constraint systems_universe_fk foreign key (universe_id) references public.universes(id) on delete restrict;
create unique index uq_systems_universe_id on public.systems(universe_id,id);
create index idx_systems_universe on public.systems(universe_id);
create index idx_systems_universe_parent on public.systems(universe_id,parent_system_id);
alter table public.systems add constraint systems_parent_same_universe_fk foreign key (universe_id,parent_system_id) references public.systems(universe_id,id) on delete restrict;
alter table public.systems drop constraint if exists systems_parent_system_id_fkey;

alter table public.system_function_subsystems rename to system_function_systems;
alter table public.system_function_systems rename column subsystem_id to system_id;
alter table public.system_function_systems rename constraint system_function_subsystems_subsystem_id_fkey to system_function_systems_system_id_fkey;

create table public.system_wormholes (
  id uuid primary key default gen_random_uuid(),
  source_system_id uuid not null references public.systems(id) on delete cascade,
  target_system_id uuid not null references public.systems(id) on delete cascade,
  status text not null default 'active' check (status in ('pending','active','paused','closed')),
  sync_mode text not null default 'bidirectional' check (sync_mode in ('bidirectional','source_to_target','target_to_source')),
  sync_scope jsonb not null default '{"identity":true,"parameters":true,"metadata":true,"memories":true,"functions":true,"relationships":true}'::jsonb,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint system_wormholes_no_self check (source_system_id <> target_system_id)
);

create or replace function public.validate_system_wormhole_universe()
returns trigger language plpgsql set search_path=public as $$
declare su uuid; tu uuid;
begin
  select universe_id into su from public.systems where id=new.source_system_id;
  select universe_id into tu from public.systems where id=new.target_system_id;
  if su is null or tu is null or su=tu then
    raise exception 'A wormhole must connect systems in different universes';
  end if;
  return new;
end $$;

create trigger trg_validate_system_wormhole_universe
before insert or update on public.system_wormholes
for each row execute function public.validate_system_wormhole_universe();

create unique index uq_system_wormholes_pair on public.system_wormholes(least(source_system_id,target_system_id),greatest(source_system_id,target_system_id));
create index idx_system_wormholes_source on public.system_wormholes(source_system_id);
create index idx_system_wormholes_target on public.system_wormholes(target_system_id);

alter table public.universes enable row level security;
alter table public.system_wormholes enable row level security;

create policy universes_owner_select on public.universes for select to authenticated using ((select auth.uid())=owner_user_id);
create policy universes_owner_insert on public.universes for insert to authenticated with check ((select auth.uid())=owner_user_id);
create policy universes_owner_update on public.universes for update to authenticated using ((select auth.uid())=owner_user_id) with check ((select auth.uid())=owner_user_id);
create policy universes_owner_delete on public.universes for delete to authenticated using ((select auth.uid())=owner_user_id);

create policy system_wormholes_owner_select on public.system_wormholes for select to authenticated using (
  exists(select 1 from public.systems s where s.id=source_system_id and s.owner_user_id=(select auth.uid()))
  and exists(select 1 from public.systems s where s.id=target_system_id and s.owner_user_id=(select auth.uid()))
);
create policy system_wormholes_owner_insert on public.system_wormholes for insert to authenticated with check (
  exists(select 1 from public.systems s where s.id=source_system_id and s.owner_user_id=(select auth.uid()))
  and exists(select 1 from public.systems s where s.id=target_system_id and s.owner_user_id=(select auth.uid()))
);
create policy system_wormholes_owner_update on public.system_wormholes for update to authenticated using (
  exists(select 1 from public.systems s where s.id=source_system_id and s.owner_user_id=(select auth.uid()))
  and exists(select 1 from public.systems s where s.id=target_system_id and s.owner_user_id=(select auth.uid()))
) with check (
  exists(select 1 from public.systems s where s.id=source_system_id and s.owner_user_id=(select auth.uid()))
  and exists(select 1 from public.systems s where s.id=target_system_id and s.owner_user_id=(select auth.uid()))
);
create policy system_wormholes_owner_delete on public.system_wormholes for delete to authenticated using (
  exists(select 1 from public.systems s where s.id=source_system_id and s.owner_user_id=(select auth.uid()))
  and exists(select 1 from public.systems s where s.id=target_system_id and s.owner_user_id=(select auth.uid()))
);