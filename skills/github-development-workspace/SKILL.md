---
name: GitHub Development Workspace
slug: github-development-workspace
version: 1.0.0
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
