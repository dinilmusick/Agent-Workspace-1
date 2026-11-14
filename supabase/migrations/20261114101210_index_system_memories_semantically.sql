create or replace function public.sync_system_memory_semantic_index()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform public.semantic_resource_upsert(
    'system_memory',
    new.id::text,
    new.title,
    new.title || E'\n' || new.content,
    array_append(coalesce((new.metadata->'tags')::text[], '{}'), new.memory_type),
    jsonb_build_object(
      'system_id', new.system_id,
      'memory_type', new.memory_type,
      'importance', new.importance,
      'status', new.status
    ),
    null
  );
  return new;
end;
$$;

drop trigger if exists system_memories_semantic_index on public.system_memories;
create trigger system_memories_semantic_index
after insert or update of title, content, memory_type, importance, status, metadata
on public.system_memories
for each row execute function public.sync_system_memory_semantic_index();