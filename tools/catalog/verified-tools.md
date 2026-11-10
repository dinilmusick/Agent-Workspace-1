# Verified agent and coding tools

## Loop runtimes

- **Agent Loops** — MIT; orchestrator/worker/reviewer, bounded steps, timeouts, transcript and resume. Node.js 22.18+, Git and authenticated coding-agent CLI. https://github.com/andromarces/agent-loops
- **AutoHelix** — Apache-2.0; isolated Git worktrees, editable-file scope, test/type-check gates, metrics, persistent notes and iteration/time/cost budgets. Python 3.11+ and authenticated Claude Code, Codex or OpenCode. https://github.com/awslabs/AutoHelix

Use Looper for deterministic goal/input/output/evidence state. Use Agent Loops for multi-agent coding handoffs. Use AutoHelix for constraint-gated improvement loops. Supabase Task Ledger remains the shared cross-agent task source of truth.

## Coding-agent backends

| Agent | Role | License | Repository |
|---|---|---|---|
| OpenCode | Provider-agnostic terminal coding agent | MIT | https://github.com/anomalyco/opencode |
| Codex CLI | Local coding agent | Apache-2.0 | https://github.com/openai/codex |
| Gemini CLI | Google coding agent | Apache-2.0 | https://github.com/google-gemini/gemini-cli |
| OpenHands / Agent Canvas | Self-hosted developer control center | MIT | https://github.com/OpenHands/OpenHands |
| Goose | Extensible desktop, CLI and API agent | Apache-2.0 | https://github.com/aaif-goose/goose |
| Aider | Git-aware terminal pair programmer | Apache-2.0 | https://github.com/Aider-AI/aider |
| Cline | IDE/CLI coding agent | Apache-2.0 | https://github.com/cline/cline |

These backends are optional and require separate model authentication. They are not installed automatically in the public GitHub Actions runner.

## React / TypeScript toolchain

The pinned package manifest is `tools/react-typescript-fullstack/package.json`.

- TypeScript — static type checking
- ESLint + typescript-eslint — config-driven linting
- Prettier — format verification
- Biome — fast formatter and linter
- Vitest — unit/component tests
- Playwright — rendered browser, DOM, screenshots, traces, console and network diagnostics
- axe-core — accessibility audit
- Knip — unused files, exports and dependencies
- dependency-cruiser — dependency graph, cycles and architectural boundary checks

The quality runner executes a check only when the target repository has its corresponding configuration. It does not impose a foreign lint policy on unconfigured projects.

## Safety

Target code is untrusted. The public workflow uses read-only repository permissions, disables persisted checkout credentials, passes no secrets to target code, and uploads execution evidence separately. Never put model credentials in this public repository. Pin versions and inspect upstream licenses before vendoring source.

- **Supabase Agent Client** — dependency-free PostgREST/RPC client for connector-less agent runtimes; exposes canonical AgentGPT ledger RPCs and skill registry access from `tools/supabase-agent-client/supabase_client.py`.
