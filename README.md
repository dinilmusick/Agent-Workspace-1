# Agent Workspace

Agent Workspace provides three distinct capabilities:

1. **Goal and task coordination — Supabase PostgreSQL.** Goals, parent tasks, dependencies, leases, loop iterations, parameters, evidence, verification and finalization are persisted and enforced by database RPCs.
2. **Coding execution — GitHub Issues and PRs.** Each independent coding task gets one Issue as its durable execution state and one dedicated PR as its implementation artifact. Workers persist blockers and resume points in Issues; the orchestrator polls Issues/PRs/CI and writes decisions back to Issues.
3. **Reasoning and orchestration — ChatGPT conversations.** The user opens the orchestrator and worker chats. Chats load and update shared state directly through the connected Supabase tools.
4. **Finite compute — GitHub Actions.** The Agent Compute Workspace runs source files from a selected repository revision on an ephemeral GitHub-hosted runner and returns an artifact.

## Resume or create work

For an unfinished goal, ask a new chat to **“Start finishing an unfinished goal.”** The Universal Task Router loads the unfinished-goal list and resumes by readable goal key.

For a new objective, describe the outcome normally. The orchestrator creates a titled, tagged goal with its own loop and direct child tasks. Every task has its own loop, acceptance criteria, optional parameter contract and independent verification.

## Run code

Use [GitHub Development Workspace](docs/github-development-workspace.md) to execute commands against an authorized repository through either a `[github-dev]` issue or workflow dispatch. It can run checks, push a new branch, and open a PR. Use [Agent Compute Workspace](.github/workflows/agent-compute.yml) for finite source-file execution. It supports Python, Node.js, TypeScript, Bash, Go, Rust, Java, C, C++, C#, Ruby, PHP, Perl, R and PowerShell.

- Dispatch the workflow with a source file, runtime, arguments and timeout; or
- Create an issue titled `[agent-compute] <goal-key> <runtime>` with a JSON body containing `ref`, `runtime`, `source_file`, `arguments` (string array) and `timeout_seconds`. The issue route accepts repository owners, members and collaborators.

The runner is ephemeral, has read-only repository permissions, does not persist checkout credentials and receives no application secrets. Retrieve the completed run's artifact for outputs and evidence.

## Architecture

- [Architecture](docs/architecture.md)
- [Template portfolio candidate audit](docs/template-portfolio-candidates.md) — selected starter per category, source revisions and commercial-license clearance status.
- [Goal and task ledger integration](docs/task-ledger-integration.md)
- [Chat-driven goal and worker protocol](docs/chat-agent-workflow.md)
- [Compute request contract](docs/compute-request.md)
- [Security model](docs/security.md)
- [Workspace layout](docs/workspace-layout.md)

## Agent tools and skills

- [Looper](tools/looper/README.md): bounded loop-state controller for agent iterations.
- [Backend/API diagnostics](tools/backend-api-diagnostics/README.md): real local endpoint checks, contracts, auth/failure scenarios and correlated server-log artifacts.
- [Multi-service runtime](docs/multi-service-runtime.md): concurrent app services, health checks, ports, restart policies, logs and teardown.
- [Disposable database integration](docs/database-integration.md): isolated Supabase migration replay, SQL/RLS/RPC tests, schema drift checks and generated types.
- [Browser test harness](tools/react-typescript-fullstack/README.md): real-preview routes and workflows, responsive checks, traces, DOM/network evidence, axe accessibility and controlled visual baselines.
- [Platform adapters](skills/platform-adapters/SKILL.md): local Cloudflare Worker tests, Vercel preview diagnostics and local Supabase migrations/pgTAP.
- [Implementation Push](skills/implementation-push/SKILL.md): fresh whole-codebase completion passes that find incomplete implementation, rewire systems and verify end to end.
- [Persistent Multi-Agent Execution](skills/persistent-multi-agent-execution/SKILL.md): GitHub-Issue-backed durable worker/orchestrator execution, blocker persistence, polling and safe bulk continuation.
- [Tools catalogue](tools/catalog/README.md): curated coding, testing and browser tools.
- [Skills catalogue](skills/catalog.json): versioned skill snapshot backed by the Skills Database.

## Repository safety

This is a public repository. Never commit credentials, private source or personal data. GitHub-hosted compute is not a hardened hostile multi-tenant sandbox; do not use it to execute unknown users' code or process secrets.

## GitHub-native development

Agent Workspace can operate as a complete GitHub development substrate without Supabase.

### Repository lifecycle

```text
create repository
  -> Skipo scaffold
  -> GitHub-hosted development workspace
  -> edit/install/lint/typecheck/test/build
  -> commit/push
  -> GitHub Actions verification
  -> artifacts/evidence
```

Use:

- `.github/workflows/create-skipo-app.yml` — create a repository and scaffold canonical Skipo.
- `.github/workflows/github-dev-workspace.yml` — edit/build/lint/test a target repository on GitHub-hosted compute.
- `.github/workflows/github-public-compute-matrix.yml` — verify across standard Linux, Windows and macOS public runners.
- `.github/workflows/private-repo-ci.yml` — execute private-repository workflows through Agent Workspace when native private CI is unavailable.
- `skills/github-development-workspace/SKILL.md` — reusable agent instructions.
- `tools/github/` — repository creation and Skipo scaffolding tools.\n- `.github/workflows/independent-commercial-acquisition.yml` — owner-triggered, private, non-fork Git mirror acquisition for license-qualified projects.\n- `docs/commercial-acquisition-policy.md` — mandatory commercial-use, redistribution and dependency clearance gate.

GitHub Actions standard runners for public repositories are currently free and unlimited. Standard runner labels include Linux `ubuntu-latest`, Windows `windows-latest`, and macOS `macos-latest`; concurrency and runner-specific limits still apply.

Supabase remains the coordination/state substrate when available, but it is not required for source development. An agent with GitHub access can perform repository creation, Skipo scaffolding, coding, verification and commits using GitHub alone.


<!-- import-forge trigger marker -->
