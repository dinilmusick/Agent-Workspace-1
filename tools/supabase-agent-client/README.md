# Supabase Agent Client

A dependency-free, agent-facing Supabase client for runtimes that do not have a native Supabase connector.

## Contract

The executable is `supabase_client.py`. It reads credentials only from environment variables:

- `SUPABASE_URL` — project URL.
- `SUPABASE_SERVICE_ROLE_KEY` — preferred for trusted Agent Workspace runtimes.
- `SUPABASE_ANON_KEY` — supported for RLS-scoped runtimes.

The tool never prints credentials.

### Database access

The client exposes:

- generic PostgREST table operations: select, insert, update, delete;
- RPC invocation;
- canonical AgentGPT ledger RPCs;
- semantic skill registry access for `skills`, `skill_versions`, `skill_tools`, and `skill_tool_links`.

The generic REST/RPC surface is intentionally the lower-level escape hatch. Agents should prefer the semantic ledger and skill operations so the Supabase schema remains an implementation detail.

## CLI

Examples:

```bash
python tools/supabase-agent-client/supabase_client.py overview
python tools/supabase-agent-client/supabase_client.py unfinished
python tools/supabase-agent-client/supabase_client.py resume --goal-key GOAL_KEY
python tools/supabase-agent-client/supabase_client.py claim-task --task-key TASK_KEY --agent-id AGENT_ID
python tools/supabase-agent-client/supabase_client.py rpc --name goal_ledger_overview --args '{}'
python tools/supabase-agent-client/supabase_client.py skills --search coding
python tools/supabase-agent-client/supabase_client.py table --table skills --select '*'
```

Every successful command emits JSON. Errors are emitted as structured JSON on stderr and return a non-zero exit code.

## Agent embedding

Import `SupabaseAgentClient` directly from another Python tool:

```python
from supabase_client import SupabaseAgentClient

db = SupabaseAgentClient.from_environment()
overview = db.ledger("goal_ledger_overview", {})
skills = db.skills.search("coding")
```

The client does not assume a specific model, agent framework, or connector implementation, so it can be embedded by other Agent Workspace tools and external agents.

## Security

This repository is public. Never put a URL containing credentials, keys, or tokens into source, tests, fixtures, logs, or documentation. The service-role key grants broad database authority; use it only inside a trusted Agent Workspace runtime and rely on database RPC/RLS policy as the final authorization boundary.
