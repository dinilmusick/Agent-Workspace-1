# Coding and verification tool catalogue

Tools are grouped by capability. Prefer project-local, version-pinned dependencies. The actual toolchain manifests live under `tools/`.

## Agent loop runtimes

| Tool | Role | Upstream | License |
|---|---|---|---|
| Agent Loops | Orchestrator → worker → reviewer; step/time budgets, transcripts and resume | https://github.com/andromarces/agent-loops | MIT |
| AutoHelix | Isolated worktree iterations, file-scope controls, test/metric gates and budgets | https://github.com/awslabs/AutoHelix | Apache-2.0 |

Agent Loops requires Node.js 22.18+, Git and an authenticated coding-agent CLI. AutoHelix requires Python 3.11+ and an authenticated Claude Code, Codex or OpenCode CLI. Both are optional runtime engines, not requirements of the base workspace.

Use Looper for deterministic loop input/output/evidence state across any domain; Agent Loops for coding tasks requiring separate agent roles; AutoHelix for isolated constraint-gated improvement. Supabase Task Ledger remains the shared multi-agent task source of truth.

## Coding-agent backends

- OpenCode — https://github.com/anomalyco/opencode
- Codex CLI — https://github.com/openai/codex
- Gemini CLI — https://github.com/google-gemini/gemini-cli
- OpenHands / Agent Canvas — https://github.com/OpenHands/OpenHands
- Goose — https://github.com/aaif-goose/goose
- Aider — https://github.com/Aider-AI/aider
- Cline — https://github.com/cline/cline

These backends are optional because each requires separate model access and authentication. They are not installed automatically in public CI.

## TypeScript / React quality and browser tools

- TypeScript — static type checking
- ESLint + typescript-eslint — config-driven linting
- Prettier — format verification
- Biome — fast formatter and linter
- Vitest — unit/component tests
- Playwright — rendered browser, DOM, screenshots, traces, console and network diagnostics
- axe-core — accessibility audit
- Knip — unused files, exports and dependencies
- dependency-cruiser — dependency graph, cycles and architectural boundary checks

The pinned toolchain is in `tools/react-typescript-fullstack/package.json`. The quality runner executes tools only when the target repository has the corresponding configuration.

## Safety

Target code is untrusted. The public workflow uses read-only repository permissions, disables persisted checkout credentials, passes no secrets to target code, and uploads execution evidence separately. Never place model credentials in this public repository. Pin tool versions and inspect upstream licenses before vendoring source.

## Platform development adapters

- `runner/platform_adapters.py`: shared local-only adapter runner.
- `@cloudflare/vitest-plugin@1.4.12`, `vitest@5.0.5`, `vite@7.3.6`, `wrangler@4.156.1`: local Cloudflare Worker tests with bindings; only pinned esbuild/workerd install scripts are allowed.
- `vercel@65.9.0`: preview-environment local builds and read-only deployment diagnostics.
- `supabase@3.0.0`: local Postgres migrations and pgTAP tests only.
