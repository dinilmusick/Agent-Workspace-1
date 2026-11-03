-- Harden Vision foreign-key indexes and make the service-role-only RLS boundary explicit.
create index if not exists visions_owner_user_id_idx on public.visions(owner_user_id);
create index if not exists vision_targets_parent_target_idx on public.vision_targets(parent_target_id);
create index if not exists vision_canvas_pages_target_idx on public.vision_canvas_pages(vision_target_id);

drop policy if exists visions_service_role_access on public.visions;
create policy visions_service_role_access on public.visions for all to service_role using (true) with check (true);
drop policy if exists vision_targets_service_role_access on public.vision_targets;
create policy vision_targets_service_role_access on public.vision_targets for all to service_role using (true) with check (true);
drop policy if exists vision_target_goals_service_role_access on public.vision_target_goals;
create policy vision_target_goals_service_role_access on public.vision_target_goals for all to service_role using (true) with check (true);
drop policy if exists vision_canvas_pages_service_role_access on public.vision_canvas_pages;
create policy vision_canvas_pages_service_role_access on public.vision_canvas_pages for all to service_role using (true) with check (true);
