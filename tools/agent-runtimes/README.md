# Optional coding-agent runtimes

These are installable engines, not required dependencies of the core Agent Workspace runner.

## Included loop engines

- **Agent Loops** (`@andromarces/agent-loops` 0.8.0, MIT): orchestrator → worker → reviewer; Node.js 22.18+, Git, and at least one authenticated coding-agent CLI. It supports bounded steps, per-call timeouts, transcripts and resume.
- **AutoHelix** (`autohelix` 0.1.1, Apache-2.0): verified improvement loop with a fresh Git worktree per iteration, editable-file scope, test/type-check constraints, metrics, persistent notes and iteration/time/cost budgets. Requires Python 3.11+ and an installed/authenticated agent CLI.

Install these only when a task selects one of them. They are not required for Looper's basic input/output state management.

## Coding-agent backends

The runtime catalogue includes Codex CLI, OpenCode, Gemini CLI, OpenHands, Goose, Aider and Cline. They are not installed automatically because each needs separate model access and authentication. Do not store their credentials in this public repository or pass them to untrusted target code.

## Runtime selection

- Use **Looper** for deterministic input/output tracking, criterion evidence, bounded continuation and stop decisions across any domain.
- Use **Agent Loops** when a coding task benefits from explicit orchestrator, worker and independent reviewer roles.
- Use **AutoHelix** when each code iteration must be isolated and accepted only after deterministic constraints/metrics pass.
- Keep GitHub Actions as the execution host; Task Ledger in Supabase remains the shared multi-agent task record. Do not treat a local runtime's session memory as the cross-agent source of truth.

No runtime is auto-started. A task must select one explicitly, and the agent must confirm that the selected CLI is installed and authenticated before dispatch.
