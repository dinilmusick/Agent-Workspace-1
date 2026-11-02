# Coding and verification tool catalogue

Tools are grouped by capability. Prefer installing project-local, lockfile-pinned dependencies over global mutable installs. This catalogue records upstream sources; it does not copy unreviewed binaries or grant agents credentials.

## AI coding agents / harnesses

| Tool | Role | Upstream | License / install model |
|---|---|---|---|
| AgentLoop | Fresh-context worker/critic cycles, bounded task retries, dashboard and MCP bridge | https://github.com/aiedwardyi/AgentLoop | MIT; standalone Node daemon; review platform assumptions before adoption |
| Loopy | Reusable loop catalogue and installable loop-design skill | https://github.com/Forward-Future/loopy | MIT; skill/catalogue, not a runtime executor |
| OpenCode | Provider-agnostic terminal coding agent | https://github.com/anomalyco/opencode | MIT; install via official instructions |
| Codex CLI | Terminal coding agent | https://github.com/openai/codex | Apache-2.0; install via official instructions |
| Gemini CLI | Terminal coding agent | https://github.com/google-gemini/gemini-cli | Apache-2.0; install via official instructions |
| Goose | Extensible local agent and CLI | https://github.com/block/goose | Apache-2.0; install via official instructions |
| Aider | Git-aware pair-programming CLI | https://github.com/Aider-AI/aider | Apache-2.0; Python package |
| OpenHands | Agent SDK and self-hosted coding environment | https://github.com/All-Hands-AI/OpenHands | MIT; containerized/self-hosted |

## TypeScript / React quality and browser tools

- TypeScript: https://github.com/microsoft/TypeScript
- ESLint: https://github.com/eslint/eslint
- typescript-eslint: https://github.com/typescript-eslint/typescript-eslint
- Prettier: https://github.com/prettier/prettier
- Biome: https://github.com/biomejs/biome
- Vitest: https://github.com/vitest-dev/vitest
- Playwright: https://github.com/microsoft/playwright
- Storybook: https://github.com/storybookjs/storybook
- axe-core: https://github.com/dequelabs/axe-core
- Knip: https://github.com/webpro-nl/knip
- dependency-cruiser: https://github.com/sverweij/dependency-cruiser

## Policy

Do not download every agent repository into the execution image. Many are large, need model credentials, execute arbitrary code, or overlap in purpose. Select adapters per task, pin versions and verify upstream licenses/releases. AI agent CLIs are optional worker engines; Looper remains the deterministic lifecycle controller.
