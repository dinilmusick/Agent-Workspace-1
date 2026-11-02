# Architecture

## System of record

Supabase PostgreSQL is the only persistent coordination layer. It stores goals, hierarchical tasks, claims, leases, loop iterations, parameters, dependencies, evidence, verification and guarded finalization. Database RPCs enforce atomic transitions and completion invariants.

## Reasoning and orchestration

ChatGPT conversations are the agents. The user manually opens the orchestrator and worker conversations. Each chat loads the current goal/task state directly through connected Supabase tools, claims work using database RPCs, records iterations and submits evidence. A separate chat performs independent verification.

## Finite compute

GitHub Actions provides the only general-purpose execution environment. `.github/workflows/agent-compute.yml` checks out the requested repository revision on an ephemeral hosted runner, validates the request, executes the selected source file and uploads result artifacts.

## Execution sequence

```text
User
 |
 v
ChatGPT orchestrator / worker conversations
 |                         |
 | direct PostgreSQL RPCs  | request finite computation
 v                         v
Supabase PostgreSQL      GitHub Actions
 |                         |
 | goals, tasks, leases    +--> ephemeral Ubuntu runner
 | loops, evidence         +--> execute selected language
 | verification            +--> upload artifact
 |                         |
 +<---- result/evidence ---+
 |
 v
Independent chat verification
 |
 v
Database-guarded finalization
```

## Boundaries

- Supabase is the system of record and atomic coordination provider.
- ChatGPT is the reasoning, planning, implementation and verification layer.
- GitHub Actions is a disposable compute provider only.
- PostgreSQL RPCs are the sole goal/task mutation interface used by ChatGPT chats.
- Supabase Edge Functions are not part of the architecture.
- GitHub Actions does not create or run ChatGPT conversations and is not a persistent worker service.

## Compute request entry points

Agent Compute supports `workflow_dispatch` and an issue route restricted to repository owners, members and collaborators. Both routes resolve to the same validated request contract and runner. See [compute request contract](compute-request.md).

## Security boundary

The runner has read-only repository permissions, checkout credentials are not persisted, application secrets are not passed to executed code, and execution is time-bounded. It is ephemeral compute, not a hardened hostile multi-tenant sandbox. See [security](security.md).
