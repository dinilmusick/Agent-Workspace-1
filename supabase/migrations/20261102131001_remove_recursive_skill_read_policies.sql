-- Re-establish non-recursive published catalogue policies.
drop policy if exists skills_public_read on public.skills;
create policy skills_public_read on public.skills for select to anon, authenticated using (status='active');
drop policy if exists skill_versions_public_read on public.skill_versions;
create policy skill_versions_public_read on public.skill_versions for select to anon, authenticated using (is_published=true);
