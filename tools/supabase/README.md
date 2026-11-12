# Supabase tools

Agent Workspace keeps two Supabase capabilities separate under this folder:

- management/ — grouping for the existing connector-less client at tools/supabase-agent-client/.
- substrate/ — reproducible setup, migration, seed, verification, backup and restore tooling.

The repository-level supabase/ directory is the canonical source of truth for migrations, seed data, tests and Supabase configuration.

Credentials are runtime-only and must never be committed.

The management client uses SUPABASE_SECRET_KEY (preferred) or legacy SUPABASE_SERVICE_ROLE_KEY together with SUPABASE_URL. Hosted substrate migration commands use SUPABASE_ACCESS_TOKEN, SUPABASE_DB_PASSWORD and SUPABASE_PROJECT_ID.