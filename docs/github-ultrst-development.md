# ULTRST GitHub-Native Development

GitHub is the executable development substrate for ULTRST applications.

## No-Supabase path

An agent needs only GitHub access plus the Agent-Workspace workflows:

```text
GitHub
  │
  ├─ create repository
  │
  ├─ create-skipo-app
  │    └─ canonical Skipo scaffold
  │
  ├─ github-dev-workspace
  │    ├─ edit
  │    ├─ install
  │    ├─ lint
  │    ├─ typecheck
  │    ├─ test
  │    └─ build
  │
  ├─ public-compute-matrix
  │    └─ Linux / Windows / macOS verification
  │
  └─ GitHub Actions
       └─ logs + artifacts + status
```

Supabase can remain the durable goal/task/ownership/evidence ledger, but repository development must never depend on it being available.

## Full ULTRST application loop

```text
Vision
  -> create/select repository
  -> scaffold Skipo
  -> configure SYSTEM_DATABASE_URL in hosting secret stores
  -> implement application-specific UI/services
  -> use GutTS/KrnlTS/FrnlTS/Kloks/Floks canonical packages
  -> verify Luth/Srkl/Loky integration
  -> lint/typecheck/test/build
  -> browser/runtime verification
  -> commit/push
  -> GitHub Actions CI
  -> deploy/promotion
```

## Repository roles

GitHub remains the source of truth for source, branches, commits, workflows and CI evidence.

Supabase remains the coordination plane when available:

```text
GitHub = source + execution + CI
Supabase = goals + tasks + leases + evidence coordination
```

The two planes are intentionally decoupled.

## Private repository CI

If native private CI is unavailable or exhausted, route to `private-repo-ci-workspace-runner`. Agent-Workspace-1 clones the target into its dedicated clone area and executes the target workflows through `act`.

## Coding security

- `CODING_REPO_TOKEN` is for repository coding and creation.
- `PRIVATE_REPO_TOKEN` is read-only CI fallback access.
- `DEPLOYMENT_TOKEN` is never injected into arbitrary coding commands.
- Never commit credentials or private source into Agent-Workspace-1.
- Only run arbitrary commands against repositories the agent is authorized to modify.
