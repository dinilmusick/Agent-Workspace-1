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
