# Security model

This repository is public and is designed to execute code. Treat every task as untrusted code, even when submitted by an authorized agent.

## Controls implemented

- Workflow permissions are read-only (`contents: read`).
- Third-party workflow actions are pinned to full commit SHAs.
- Execution is manually dispatched; validation workflows never run task commands.
- The task runner uses `subprocess.run(..., shell=False)`.
- Manifest and working-directory paths must resolve inside the checked-out repository.
- Per-task timeout is capped at 30 minutes.
- Captured stdout and stderr are capped at 100,000 characters each.
- The task process does not inherit GitHub Actions, Actions input or runner environment variables.
- No secrets are defined or passed to the execution job.
- Hosted runners are disposable; do not rely on their filesystem surviving a run.

## Operational rules

1. Never commit API keys, tokens, credentials, private source code or personal data.
2. Never pass secrets through task manifest `env` values, command arguments or logs.
3. Do not add privileged deployment or repository-write credentials to this execution workflow.
4. Keep untrusted pull-request code on `pull_request`; do not combine `pull_request_target` with checking out and executing PR code.
5. Treat artifacts and logs as potentially sensitive because task output can contain source code or data.
6. Review every workflow permission change.
7. Pin any newly introduced third-party Action to a verified full-length commit SHA.

## Threat boundary

The runner VM is disposable, but code running inside it can consume available CPU, memory, disk and network access, and can inspect the checked-out public repository. The current design does not claim to provide a hardened multi-tenant sandbox against hostile code. Do not use it to execute code from unknown external users or to process secrets. For that threat model, introduce a stronger isolated execution service with network egress controls, resource quotas and per-task credentials.
