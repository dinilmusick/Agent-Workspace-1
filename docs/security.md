# Security model

## Architecture boundary

- Supabase PostgreSQL is the persistent goal/task ledger and atomic coordination layer.
- ChatGPT conversations use the connected Supabase tools directly.
- GitHub Actions Agent Compute is the only general-purpose finite execution environment.
- Supabase Edge Functions and repository-hosted CLI worker daemons are not part of the supported architecture.

## Compute controls

- Workflow permissions are read-only (`contents: read`).
- Third-party workflow actions are pinned to full commit SHAs.
- Issue-based execution is restricted to repository owners, members and collaborators.
- The requested ref, runtime, source path, arguments and timeout are validated before execution.
- Checkout credentials are not persisted.
- Executed code receives no application secrets or GitHub Actions token.
- Execution timeout is capped at 1,200 seconds and output is bounded.
- Hosted runners are disposable; required outputs are uploaded as artifacts.

## Operational rules

1. Never commit API keys, tokens, credentials, private source code or personal data.
2. Never pass secrets through source files, command arguments or logs.
3. Do not add privileged deployment or repository-write credentials to the execution workflow.
4. Do not combine `pull_request_target` with checking out and executing pull-request code.
5. Treat artifacts and logs as potentially sensitive.
6. Review every workflow permission change.
7. Pin newly introduced third-party Actions to verified full-length commit SHAs.

## Threat boundary

The runner VM is disposable, but code running inside it can consume available CPU, memory, disk and network access and inspect the checked-out public repository. This design is not a hardened hostile multi-tenant sandbox. Do not execute code from unknown external users or process secrets. Use a stronger isolated execution service with network egress controls, resource quotas and per-task credentials for that threat model.

## Supabase identity boundary

The connected project currently has no Auth users. Browser chats use unique agent/session IDs within a single-owner project-scoped workspace where `auth.uid()` is null. This is not multi-tenant isolation. Provision Supabase Auth users and enforce owner-scoped JWT/RLS boundaries before sharing the project with multiple human owners.
