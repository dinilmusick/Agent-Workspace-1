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
    array[new.memory_type],
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