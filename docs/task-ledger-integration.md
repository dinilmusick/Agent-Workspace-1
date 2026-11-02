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

The service-role key is never needed by or exposed to agents. For a long-running worker, also configure `SUPABASE_AGENT_REFRESH_TOKEN`, or seed `SUPABASE_AGENT_SESSION_FILE` with `{ "access_token": "...", "refresh_token": "..." }`. The worker refreshes expired access tokens and persists rotated session tokens to that file with owner-only permissions. Keep the session file outside the repository and back it up securely.

## Run an agent worker

An agent worker polls the queue, claims tasks with a lease, invokes a configured runtime adapter, records an iteration, and submits its result. The runtime adapter is an executable argv array that reads one JSON task object from stdin and writes one JSON result object to stdout. Its result must include a status (`completed`, `failed`, `blocked`, or `waiting`) and may include `result`, `result_summary`, `tools_used`, `evidence`, and `observation`.

Configure `AGENT_RUNTIME_COMMAND_JSON` as a JSON argv array, for example `["node","adapters/codex-adapter.mjs"]`. Configure `AGENT_RUNTIME_ENV_ALLOWLIST` as a comma-separated list of model/tool environment variable names the adapter needs. The worker intentionally strips all `SUPABASE_*`, `GITHUB_*`, `ACTIONS_*`, `INPUT_*`, and `RUNNER_*` variables before starting the runtime. For a trusted orchestrator adapter only, set `AGENT_RUNTIME_ENABLE_LEDGER_TOOLS=true`; the worker then passes the current agent-scoped access token and publishable key under `AGENT_TASK_LEDGER_*` names so the adapter can invoke `runner/task-ledger.mjs` to create subtasks. It never passes a service-role key or refresh token. Keep this disabled for ordinary workers unless they need Task Ledger tool access.

Run continuously with `node runner/agent-worker.mjs`; use `node runner/agent-worker.mjs --once` to process at most one task. The worker never performs final verification. A separately registered verifier/orchestrator must accept the result and finalize the parent task. Run `node runner/verifier-worker.mjs` for a continuous independent-verification queue, or add `--once` to process at most one pending result. The verifier runtime receives the task result and iteration evidence, returns `{ "verified": true|false, "verification_report": { ... } }`, and the worker finalizes ancestor tasks only after every child is verified.

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
