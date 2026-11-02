# Supabase Task Ledger integration

The Task Ledger Edge Function is the authenticated boundary between agent runtimes and the Skills Database.

## Components

- `public.agent_registry` binds a Supabase Auth user to one enabled agent identity, type and capability set.
- `task-ledger` verifies the caller JWT, resolves the agent identity server-side, then calls Task Ledger RPCs using the server-only service role.
- `runner/task-ledger.py` is a dependency-free client for agent runtimes.
- The browser/client roles have no task-table grants and cannot execute Task Ledger RPCs directly.
- Skill catalogue reads remain read-only and RLS-filtered; only active skills and published versions are visible.

## Provision an agent

1. Create a dedicated Supabase Auth user for each independently authenticated agent runtime. Do not share a human user's refresh token across agents.
2. In the Supabase SQL editor, register that user's UUID:

```sql
insert into public.agent_registry
  (user_id, agent_id, agent_name, agent_type, capabilities)
values
  ('AUTH_USER_UUID', 'agent-coder-01', 'Coding Worker 01', 'worker',
   array['code','typescript','testing']);
```

Use `orchestrator` for task-tree creation, `worker` for task execution, and `verifier` for independent verification/finalization. Agent types are checked by the Edge Function for verifier-only operations. Disable an agent by setting `enabled = false`.

3. Authenticate the agent with Supabase Auth and supply its access token to the runtime. The token is short-lived; refresh it through the normal Auth flow.

## Configure the client

Set these environment variables in the agent runtime (never in a public repository):

- `SUPABASE_URL`: project URL.
- `SUPABASE_ANON_KEY`: publishable/anon key.
- `SUPABASE_AGENT_JWT`: access token for the dedicated registered agent user.

The service-role key is never needed by or exposed to agents.

## API examples

```bash
python runner/task-ledger.py skills.list
python runner/task-ledger.py task.create --payload-file task-tree.json
python runner/task-ledger.py task.claim --payload '{"lease_seconds":900}'
python runner/task-ledger.py task.heartbeat --payload '{"task_id":"...","claim_token":"...","current_step":"running tests"}'
python runner/task-ledger.py task.iteration --payload-file iteration.json
python runner/task-ledger.py task.submit --payload-file result.json
python runner/task-ledger.py task.verify --payload-file verification.json
python runner/task-ledger.py task.finalize --payload-file finalization.json
```

Every claimed task returns a claim token. Heartbeat, iteration recording and result submission require that token. A completed worker result remains pending until a separate verifier approves it. Parent finalization is a separate verifier/orchestrator action after child verification.

## Operational boundary

This API coordinates tasks; it does not magically provision LLMs or make optional CLI runtimes authenticated. Each agent runtime must have its own Supabase Auth identity and a real model/tool configuration. The GitHub-hosted execution workflow remains a separate disposable execution facility. Do not pass secrets or private source to the public task runner. The current GitHub runner is not a hardened hostile multi-tenant sandbox.
