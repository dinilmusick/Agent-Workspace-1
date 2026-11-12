# Supabase Agent Substrate

This tool provisions and maintains the Agent Workspace Supabase substrate from the versioned assets in the repository root: supabase/config.toml, supabase/migrations/, supabase/seed.sql, and supabase/tests/.

Commands:

python tools/supabase/substrate/bootstrap.py doctor
python tools/supabase/substrate/bootstrap.py plan
python tools/supabase/substrate/bootstrap.py push --project-ref PROJECT_REF
python tools/supabase/substrate/bootstrap.py status --project-ref PROJECT_REF
python tools/supabase/substrate/bootstrap.py test
python tools/supabase/substrate/bootstrap.py dump --project-ref PROJECT_REF --output PATH

Hosted migration operations use the Supabase CLI. They require a scoped SUPABASE_ACCESS_TOKEN and the target project's SUPABASE_DB_PASSWORD; the project ref can be supplied as SUPABASE_PROJECT_ID. A Supabase API/service key is not sufficient for DDL migrations.

Recovery:
1. Clone Agent Workspace.
2. Install the Supabase CLI and a local container runtime for local verification.
3. Add runtime secrets.
4. Run doctor, then plan.
5. Run push against a new or empty project.
6. Run status and test.
7. Use dump periodically when you need a data backup in addition to the versioned schema.

The tool never writes secrets into repository files and never prints secret values.