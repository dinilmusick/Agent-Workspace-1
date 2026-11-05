---
name: GitHub Development Workspace
slug: github-development-workspace
version: 1.0.1
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

## Verification discipline

Before triggering remote CI after adding or changing tests:
1. Inspect the target implementation exports.
2. Verify every test import resolves to the canonical module boundary actually exporting the symbol.
3. Run the narrow affected test locally when the environment permits.
4. Only then trigger Agent-Workspace private-repo CI.
5. If CI fails in test collection or execution, classify whether the failure is implementation, test wiring, workflow infrastructure, or environment before changing source.

Known failure pattern: a certification test imported getSystemDatabaseUrl from src/backend/auth/betterAuth even though the canonical export was src/backend/types.ts. Typecheck passed, but CI failed with TypeError: getSystemDatabaseUrl is not a function. The fix was to import the canonical resolver from src/backend/types.ts. Do not repeat this class of error.

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
