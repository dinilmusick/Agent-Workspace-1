# Agent Workspace Bootstrap

The bootstrap tool is the deterministic local-runtime entry point for AgentGPT-compatible agents.

## Contract

local container/runtime -> Agent-Workspace-1 bridge -> GitHub Actions fallback

- plan: inspect the runtime and target without executing target code.
- prepare: ensure the public Agent-Workspace-1 checkout exists, attempt the target clone, and discover repository-defined build/quality scripts.
- If a private target cannot be cloned directly, use Agent-Workspace-1's authorized private-repository tooling.
- Run every discovered build, test, typecheck, lint and custom build command that participates in the real build.
- Use GitHub Actions only when no usable local runtime exists or local execution cannot reproduce the required environment.
