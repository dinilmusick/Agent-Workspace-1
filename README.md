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
- [Template portfolio coverage and acquisition manifest](docs/template-portfolio-catalog.md) — existing starters, missing product categories, exact upstream commits and private-research acquisition mode.
- [Commercial repository acquisition policy](docs/commercial-acquisition-policy.md) — private research mirrors are separate from approval for commercial reuse.
- [Goal and task ledger integration](docs/task-ledger-integration.md)
- [Chat-driven goal and worker protocol](docs/chat-agent-workflow.md)
- [Compute request contract](docs/compute-request.md)
- [Security model](docs/security.md)
- [Workspace layout](docs/workspace-layout.md)

## Model and agent tools

- [Model/agent tools](tools/models/README.md): disposable external model/agent launchers; current Argon/Carbon wrapper and the contract for future providers.

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

- `.github/workflows/create-skipo-app.yml` — create a repository and immediately scaffold canonical Skipo.
- `.github/workflows/github-dev-workspace.yml` — edit/build/lint/test a target repository on GitHub-hosted compute.
- `.github/workflows/github-public-compute-matrix.yml` — verify across standard Linux, Windows and macOS public runners.
- `.github/workflows/private-repo-ci.yml` — execute private-repository workflows through Agent Workspace when native private CI is unavailable.
- `skills/github-development-workspace/SKILL.md` — reusable agent instructions.
- `tools/github/` — repository creation and Skipo scaffolding tools.
- `.github/workflows/independent-commercial-acquisition.yml` — owner-triggered private, non-fork source mirror or reference-only acquisition.
- `docs/commercial-acquisition-policy.md` — mandatory separation of private research acquisition and commercial-use clearance.

GitHub Actions standard runners for public repositories are currently free and unlimited. Standard runner labels include Linux `ubuntu-latest`, Windows `windows-latest`, and macOS `macos-latest`; concurrency and runner-specific limits still apply.

Supabase remains the coordination/state substrate when available, but it is not required for source development. An agent with GitHub access can perform repository creation, Skipo scaffolding, coding, verification and commits using GitHub alone.


<!-- import-forge trigger marker -->


## Hardened worker model

Agent Workspace is designed for fragile, ephemeral agents. Workers reconstruct context from Supabase and GitHub Issues rather than chat history. Active tasks heartbeat/checkpoint about every 2 minutes and independently check ownership about every 5 minutes; tasks without a heartbeat for at least 5 minutes can be atomically recovered. Claim tokens fence stale workers. Loop contracts are authored by one worker and executed by a different worker, so success parameters cannot be self-authored and self-certified. Every worker persists progress, blockers, evidence and resume state before disappearing, and terminal completion requires independent verification.

For the complete protocol, start with `AGENTS.md`, `skills/task-ledger/SKILL.md`, `skills/universal-task-router/SKILL.md`, `skills/coding-task-lifecycle/SKILL.md`, and `skills/persistent-multi-agent-execution/SKILL.md`.


## Checkpoint blocker / notoriety model

Bounded-v2 checkpoints persist a `blockers` array. Unresolved blockers are normalized and deduplicated globally, with one occurrence recorded per agent/task/checkpoint/attempt. The resulting **notoriety** score measures repeated failure: scores above 5 are surfaced as notorious blockers and become first-class user-attention items.

User-defined goal priority is a separate normalized 0..1 signal. Claim ordering is database-enforced as goal priority → blocker notoriety → task priority. Workers inspect the blocker overview before execution, attempt the highest-notoriety active blocker first, and persist unresolved blockers through the checkpoint blocker RPCs.
