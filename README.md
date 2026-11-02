# Agent Workspace

Agent Workspace provides three distinct capabilities:

1. **Goal and task coordination — Supabase PostgreSQL.** Goals, task trees, leases, loop iterations, parameters, evidence, verification and finalization are persisted and enforced by database RPCs.
2. **Reasoning and orchestration — ChatGPT conversations.** The user opens the orchestrator and worker chats. Chats load and update shared state directly through the connected Supabase tools.
3. **Finite compute — GitHub Actions.** The Agent Compute Workspace runs source files from a selected repository revision on an ephemeral GitHub-hosted runner and returns an artifact.

## Resume or create work

For an unfinished goal, ask a new chat to **“Start finishing an unfinished goal.”** The Universal Task Router loads the unfinished-goal list and resumes by readable goal key.

For a new objective, describe the outcome normally. The orchestrator creates a titled, tagged goal with its own loop and direct child tasks. Every task has its own loop, acceptance criteria, optional parameter contract and independent verification.

## Run code

Use [Agent Compute Workspace](.github/workflows/agent-compute.yml). It supports Python, Node.js, TypeScript, Bash, Go, Rust, Java, C, C++, C#, Ruby, PHP, Perl, R and PowerShell.

- Dispatch the workflow with a source file, runtime, arguments and timeout; or
- Create an issue titled `[agent-compute] <goal-key> <runtime>` with a JSON body containing `ref`, `runtime`, `source_file`, `arguments` (string array) and `timeout_seconds`. The issue route accepts repository owners, members and collaborators.

The runner is ephemeral, has read-only repository permissions, does not persist checkout credentials and receives no application secrets. Retrieve the completed run's artifact for outputs and evidence.

## Architecture

- [Architecture](docs/architecture.md)
- [Goal and task ledger integration](docs/task-ledger-integration.md)
- [Chat-driven goal and worker protocol](docs/chat-agent-workflow.md)
- [Compute request contract](docs/compute-request.md)
- [Security model](docs/security.md)
- [Workspace layout](docs/workspace-layout.md)

## Agent tools and skills

- [Looper](tools/looper/README.md): bounded loop-state controller for agent iterations.
- [Backend/API diagnostics](tools/backend-api-diagnostics/README.md): real local endpoint checks, contracts, auth/failure scenarios and correlated server-log artifacts.
- [Multi-service runtime](docs/multi-service-runtime.md): concurrent app services, health checks, ports, restart policies, logs and teardown.
- [Tools catalogue](tools/catalog/README.md): curated coding, testing and browser tools.
- [Skills catalogue](skills/catalog.json): versioned skill snapshot backed by the Skills Database.

## Repository safety

This is a public repository. Never commit credentials, private source or personal data. GitHub-hosted compute is not a hardened hostile multi-tenant sandbox; do not use it to execute unknown users' code or process secrets.
