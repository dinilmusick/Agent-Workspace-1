# Disposable database integration environment

The repository's database tests run against a fresh local Supabase stack, never against a linked hosted project.

## Reproduce locally

Requirements: Docker-compatible container runtime, Supabase CLI 3.0.0, PostgreSQL 17 image access.

```bash
supabase --version
supabase start
supabase db reset
for test in supabase/tests/*.integration.sql; do
  psql 'postgresql://postgres:postgres@127.0.0.1:54322/postgres' -X -v ON_ERROR_STOP=1 -f "$test"
done
supabase db diff --schema public
supabase gen types --lang typescript --local --schema public
supabase stop --no-backup
```

The committed `supabase/config.toml` contains no linked project reference. The seed fixture creates one synthetic, non-login-capable Auth identity using the reserved `.invalid` domain. It exists only to exercise local JWT/RLS context and must never be replaced with production user data.

## CI safety

`.github/workflows/database-integration.yml` pins the Supabase CLI and runs on GitHub-hosted ephemeral runners. Before starting, it fails if a linked project reference or remote Supabase credentials are present. Database reset, migration replay, SQL tests, schema diff and type generation all target the local stack. No project linking, `--remote`, deployment, or remote database secret is used.

The workflow uploads the schema diff and generated TypeScript types as evidence, and always stops the stack with `--no-backup`.

## What is verified

- All committed migrations replay from an empty PostgreSQL 17 database.
- Synthetic local Auth identity resolves through `auth.uid()` under the authenticated role.
- SQL integration scripts exercise goal/task RPCs, claims, loops, result verification and recovery.
- Public-schema drift is reported as a CI failure.
- TypeScript types can be generated from the resulting local schema.

To add fixtures, use synthetic deterministic values and keep them isolated to `supabase/seed.sql`. Tests that mutate data should run inside a transaction and roll back, or explicitly clean up their own rows.
