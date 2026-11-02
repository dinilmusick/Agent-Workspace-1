-- Synthetic, non-login-capable identity for local RLS/JWT integration tests only.
-- Never copy production users or credentials into this file.
insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values (
  'f4a1c1d0-7f00-4a00-9000-000000000017',
  'authenticated',
  'authenticated',
  'agent-workspace-ci@example.invalid',
  '',
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"fixture":true}'::jsonb,
  now(),
  now()
)
on conflict (id) do nothing;
