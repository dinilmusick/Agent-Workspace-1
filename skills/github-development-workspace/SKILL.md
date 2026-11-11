---
name: GitHub Development Workspace
slug: github-development-workspace
version: 1.1.0
source: Supabase Skills Database
sourceId: 40
status: active
---

# GitHub Development Workspace

Use GitHub itself as the development substrate. This capability does not require Supabase.

## Capabilities

- Create repositories through `tools/github/create-repository.sh`.
- Create a repository and immediately scaffold a canonical Skipo application.
- Clone authorized target repositories into ephemeral GitHub-hosted runners.
- Edit code with normal shell/tooling.
- Install dependencies.
- Run lint, format, typecheck, unit/integration tests, builds and application validators.
- Run the same verification on Linux, Windows and macOS standard public runners.
- Commit and push verified changes when explicitly requested.
- Preserve logs as workflow artifacts.

## Local Runtime First

When a local container, shell, or other code-execution runtime is available, **use it as the primary execution environment**. This is preferred over GitHub Actions because it is faster and exposes direct test/build output.

Before working on a target repository:

1. Clone **Agent-Workspace-1** into the accessible local runtime when it is not already present.
2. Use the Agent-Workspace tools and scripts from that checkout rather than recreating their behavior manually.
3. Attempt to clone the target repository directly into the local runtime.
4. If the target is private and direct cloning fails, use Agent-Workspace-1's GitHub/private-repository workspace tooling to materialize the authorized private repository in the workspace's dedicated `clones/` area. Then use the public Agent-Workspace-1 checkout as the accessible bridge for running the workspace tooling and scripts against that materialized target.
5. Prefer local execution for install, lint, format, typecheck, tests, integration checks, build scripts and application validators whenever the runtime permits.
6. Use GitHub Actions only when the local runtime is unavailable, cannot reproduce the required environment, or the task specifically requires remote-runner evidence.

Never weaken repository access controls to make a private clone work. Never expose repository credentials in source, logs or prompts.

## Mandatory obstacle reflex

Obstacle recording is part of normal repository development, not an optional documentation step.

Before beginning and throughout every material change:

```text
semanticResolve
  -> inspect canonical obstacle memory
  -> execute
  -> on obstacle: normalize + search + record occurrence
  -> resolve
  -> verify
  -> if reusable substrate weakness: update skill/workflow
```

Treat these as obstacles by default: failed tests, CI failures, unexpected type/runtime errors, missing exports, dependency/toolchain failures, environment mismatches, workflow failures, authentication/token problems, ref/branch mistakes, and any workaround that should become a reusable pattern.

## Verification discipline

Before triggering remote CI after adding or changing tests:
1. Inspect the target implementation exports.
2. Verify every test import resolves to the canonical module boundary actually exporting the symbol.
3. Run the narrow affected test locally when the environment permits.
4. Only then trigger Agent-Workspace private-repo CI.
5. If CI fails, classify it before changing source.
6. Immediately search obstacle memory for the failure class.
7. Record the occurrence and evidence before applying the fix.
8. After the fix, independently verify it and update the obstacle resolution.
9. If the failure reveals a reusable weakness in Agent-Workspace, update the relevant skill/workflow and verify that improvement separately.

Known failure pattern: a certification test imported `getSystemDatabaseUrl` from `src/backend/auth/betterAuth` even though the canonical export was `src/backend/types.ts`. Typecheck passed, but CI failed with `TypeError: getSystemDatabaseUrl is not a function`. The fix was to import the canonical resolver from `src/backend/types.ts`. Do not repeat this class of error.

Known substrate failure pattern: a single `curl` request for the pinned `act` release returned HTTP 504, causing private-repo CI to stop before cloning or executing the target workflow. The workflow was hardened with bounded retry, timeout, and preserved SHA256 verification. Treat transient bootstrap failures as infrastructure obstacles and improve the substrate rather than modifying target application code.

## Substrate improvement

When an obstacle is caused by this workspace, its workflows, skills, or reusable tooling:

1. record the obstacle and current-task occurrence;
2. identify the reusable prevention rule;
3. update the smallest relevant skill/workflow/tool;
4. test the substrate change;
5. rerun the originally blocked operation;
6. independently verify the improvement;
7. record evidence linking the obstacle, fix, and verification.

The goal is progressive self-hardening of Agent-Workspace.

## Skipo application flow

```text
create repository
  -> clone canonical Skipo
  -> python3 assistant.py generate scaffold <target> --name <App>
  -> install dependencies
  -> validate
  -> commit/push
  -> continue coding in github-development-workspace
```

## Routing

```text
private repo + native CI unavailable
  -> private-repo-ci-workspace-runner

any authorized repo + code execution/edit/build/test
  -> github-development-workspace

new Skipo application
  -> create-skipo-app workflow
  -> github-development-workspace
```

## Supabase independence

Supabase is the canonical persistence layer for goals, tasks, ownership, leases and evidence when available. It is not required for repository development. An agent with GitHub access and this skill can perform the complete repository lifecycle using GitHub repository state, Actions, artifacts and workflow logs.

## Security

- Use `CODING_REPO_TOKEN` for coding operations.
- Repository creation requires Repository creation: write.
- Never expose deployment credentials to coding commands.
- Never print tokens or commit secrets.
- Only execute arbitrary commands against trusted repositories.

## Deterministic execution bootstrap

For any substantive repository task, establish the execution substrate before editing: use a usable local container/runtime first; clone Agent-Workspace-1 into that runtime; use its tools/scripts; attempt the target repository directly; if a private target cannot be cloned directly, use the Agent-Workspace-1 private-repository tooling and dedicated clones bridge. Discover and run all repository-defined build, test, typecheck, lint and custom build scripts that participate in the real build. Use GitHub Actions only when local execution is unavailable, insufficient for the target environment, or remote evidence is explicitly required. Capture command results as evidence and require independent verification before completion.

The canonical local preflight is `python tools/agent-bootstrap/bootstrap.py plan`; use `prepare` to establish the workspace and target checkout. Never place credentials in source, logs or task metadata.


## Issue-triggered development execution

When workflow-dispatch API access is unavailable, use the issue-triggered route in `.github/workflows/github-dev-workspace.yml`:

1. Create an issue in Agent-Workspace-1 titled `[github-dev] <short task>`.
2. Put a JSON request in the issue body with `repository`, `ref`, and `commands`.
3. For write work, set `push: true`, provide a new `branch`, and optionally set `create_pr: true`.
4. Only owners, members and collaborators can invoke the route.
5. The request resolver validates the issue author, repository/ref, command limits and branch/PR contract.
6. Target commands run without repository or deployment secrets. Credentials are supplied only to checkout and post-execution push/PR steps.
7. Inspect the Actions run and download its development log artifact. Do not claim completion without checking the run result and evidence.

Request schema and examples: `docs/github-development-workspace.md`.

Run resolver tests with:

```bash
python3 -m unittest runner/test_resolve_development_request.py
```
