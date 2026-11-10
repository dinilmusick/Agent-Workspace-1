# Agent Workspace Supabase client

A dependency-free Supabase client for Agent Workspace runtimes that do not have a native Supabase connector. It is infrastructure for the agent runtime, not a target-application dependency.

## Authentication

Credentials exist only in the Agent Workspace runtime:

- `SUPABASE_URL` — hosted Supabase project URL.
- `SUPABASE_SERVICE_ROLE_KEY` — service-role key.

Never commit, print, or pass the service key to target application code.

The client uses Supabase REST and does not persist credentials.

## Agent-facing API

- `client.ledger.*` — semantic adapters for canonical goal/task RPCs.
- `client.skills.*` — skill catalogue access.
- `client.tables.*` — allowlisted CRUD for AgentGPT ledger/support tables.
- `client.rpc()` — controlled access to a named public RPC when a semantic adapter does not yet exist.

The CLI exposes the same capabilities to agents that can execute workspace tools:

```bash
node tools/supabase-client/cli.mjs ledger overview
node tools/supabase-client/cli.mjs skills search task-ledger
node tools/supabase-client/cli.mjs rpc goal_ledger_resume_by_key '{"goal_key_in":"..."}'
```

## Security boundary

Only explicitly allowlisted AgentGPT tables are exposed through CRUD. Arbitrary SQL is intentionally not exposed. RPC names must be simple identifiers. The service key remains in the runtime environment and is never included in tool output.

Target repositories are untrusted: do not inject these credentials into target builds, tests, browser sessions, or application environment variables.

## Testing

Run `npm test` from this directory. Tests mock `fetch`, verify authentication headers, semantic RPC routing, skill search, table allowlisting, and CRUD routing without contacting a real Supabase project.
