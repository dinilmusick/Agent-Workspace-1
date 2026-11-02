# Development Toolchain Audit

**Audit ref:** `main` at `9bb582aed3d935d5b3beb1a235d63dbedfee4363`  
**Audit branch:** `audit/consolidate-toolchain-entrypoints`  
**Scope:** Agent-Workspace-1 canonical toolchain, workflow entry points, runtime and agent-facing contracts.

## Verified architecture

| Concern | Canonical owner | Entry points / evidence |
|---|---|---|
| Goal/task coordination and durable state | Supabase PostgreSQL | `public.goals`, `public.tasks`, `goal_iterations`, `task_iterations`; claim/heartbeat/iteration/submit/verify RPCs |
| Reasoning and orchestration | ChatGPT conversations | `docs/chat-agent-workflow.md`; workers load and mutate ledger directly |
| Finite code execution | GitHub Actions | `.github/workflows/agent-compute.yml`; `runner/resolve-compute-request.py`; `runner/execute-code.py` |
| Deterministic loop state | Looper | `tools/looper/looper.mjs`; `tools/looper/test/looper.test.mjs` |
| React/TypeScript preparation | Python project runner | `runner/react-project.py` |
| Static quality checks | React toolchain quality runner | `tools/react-typescript-fullstack/scripts/quality-check-flat.mjs` |
| Rendered browser diagnostics | Playwright + axe-core | `tools/react-typescript-fullstack/scripts/inspect-browser.mjs` |
| React app inspection workflow | GitHub Actions | `.github/workflows/inspect-react.yml` |
| Workspace/compute validation | GitHub Actions | `.github/workflows/validate-workspace.yml` |
| Pinned toolchain/Looper validation | GitHub Actions | `.github/workflows/validate-toolchain.yml` |
| Skill and tool routing metadata | Supabase registry, mirrored in repo | `skills/catalog.json`, `skills/tool-bindings.json` |

## Entry-point responsibilities

- `agent-compute.yml` is the sole general-purpose finite compute workflow. It accepts one source file, runtime, argv-style JSON arguments and a bounded timeout. It uses read-only repository permissions, disables persisted checkout credentials and uploads result artifacts.
- `inspect-react.yml` checks out a public target repository, prepares/builds/tests it, runs configured static checks, starts the app, waits for HTTP readiness, captures Playwright/axe evidence and uploads artifacts.
- `validate-workspace.yml` validates Python syntax, the compute runtime and workflow/issue request parsing.
- `validate-toolchain.yml` installs pinned toolchains, syntax-checks scripts, runs Looper tests, compiles Python helpers and retains lockfiles.
- These workflows have distinct jobs; retain them as separate CI entry points rather than collapsing them into a duplicate generic workflow.

## Consolidation performed

The React toolchain package's `inspect` script pointed to `scripts/inspect.mjs`, while the environment manifest, React inspection workflow and current browser evidence contract use `scripts/inspect-browser.mjs`. The former was a second, older browser inspector with a different trace timing and no axe audit. The package command is now aligned to `inspect-browser.mjs`, and the unused duplicate inspector is removed. `inspect-browser.mjs` is the single canonical rendered-page inspector.

The `quality` package command and environment manifest both already point to `quality-check-flat.mjs`; no compatibility wrapper is needed.

## Canonical harness contract

A future unified caller should compose the existing owners rather than introduce another runner:

1. **Target resolution:** repository + immutable ref + project path; reject path traversal and keep target code isolated from secrets.
2. **Preparation:** `react-project.py prepare` selects the repository's lockfile/package manager, installs dependencies, and runs its declared build/test scripts.
3. **Runtime lifecycle:** start all required services, record process/port/log metadata, wait on explicit health checks, and stop all children during teardown. The current React runner starts one app process; multi-service orchestration remains a separate workstream.
4. **Diagnostics:** API/request correlation and structured backend logs belong to the backend diagnostics adapter; browser console, page exceptions, failed requests, HTTP errors, DOM/screenshot, trace and axe results belong to Playwright.
5. **Quality:** invoke configured type/lint/format/dependency checks and the target's declared test script; security, coverage and Lighthouse gates remain explicit CI stages.
6. **Artifacts:** emit one run manifest linking target/ref, service health/logs, test and quality results, browser evidence, CI run and exact commit SHA.
7. **Platform adapters:** Vercel and Cloudflare must implement the same adapter contract and run in the ephemeral development environment; do not make production deployments part of validation.

## Confirmed gaps and ownership boundaries

| Gap | Evidence / location | Boundary |
|---|---|---|
| Multi-service start/health/restart/stop is not implemented by the current React runner | `runner/react-project.py` starts a single app process; no service graph or coordinated teardown | Runtime orchestration task |
| Backend request/exception/log correlation is not present in the React/browser tooling | Current browser inspector reports browser-side signals only | Backend/API diagnostics task |
| Current React inspection workflow is public-repository-only | `runner/checkout-public-repository.py` clones unauthenticated public GitHub URLs | Private-source access requires a separate credential-safe design; do not add tokens to public CI |
| Browser inspection covers the configured base URL, not a user-defined route/workflow matrix | `inspect-browser.mjs` navigates to `TARGET_BASE_URL` | Browser E2E task |
| Supabase disposable database/migration/RLS/RPC integration test harness is not present in the inspected workspace layout | `docs/workspace-layout.md` lists runtime, React, Looper and workflows but no database test adapter | Database integration task |
| Vercel/Cloudflare development adapters are not listed in the current workspace tool layout | `docs/workspace-layout.md`, `skills/tool-bindings.json` | Platform adapter task |
| Security/secret/coverage/Lighthouse gates are not part of the current workspace validation workflows | `validate-workspace.yml` and `validate-toolchain.yml` validate runtime/toolchain only | Quality-gates task |
| Quality runner does not invoke Vitest itself | `quality-check-flat.mjs` checks configured static tools; `react-project.py prepare` runs the target's declared `test` script | Keep unit tests in preparation/CI; coverage enforcement belongs to quality-gates task |

## Verification status

This document is a source audit, not a claim that runtime checks passed. Source files were inspected through GitHub at the audit ref. Commit-specific Actions verification must be recorded against the resulting commit SHA before this task can pass. The current ChatGPT tool session exposes repository read/write and CI status inspection, but no workflow-dispatch or Agent Compute invocation action; if no PR-triggered run is available, CI execution is an explicit blocker rather than assumed success.

## Relevant repository references

- `README.md`
- `docs/architecture.md`
- `docs/workspace-layout.md`
- `docs/compute-request.md`
- `docs/task-ledger-integration.md`
- `tools/looper/README.md`
- `tools/react-typescript-fullstack/environment.json`
- `.github/workflows/agent-compute.yml`
- `.github/workflows/inspect-react.yml`
- `.github/workflows/validate-workspace.yml`
- `.github/workflows/validate-toolchain.yml`
