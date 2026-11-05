# Private Repository CI Workspace Runner

Purpose:
- native private-repository GitHub Actions unavailable/exhausted
- clone target into Agent-Workspace-1's dedicated `clones/` directory
- execute the target repository's own `.github/workflows/*` definitions with `act`
- collect logs/artifacts in the public Agent-Workspace-1 Actions run
- delete the clone unconditionally

Flow:

```text
private repo
  -> clone-private-repo.sh
  -> clones/<owner>__<repo>
  -> run-workflows.sh
  -> public Agent-Workspace-1 GitHub Actions runner
  -> evidence
  -> cleanup-clone.sh
  -> clones/*
```

Security invariants:
- The private-repository access token is used only for cloning.
- The token-bearing Git remote is replaced immediately after clone.
- The private token is NOT passed to `act` workflows.
- Target workflows execute as untrusted code; do not expose unrelated secrets.
- Cleanup is mandatory and runs through the workflow's exit trap.

Requirements:
- Git
- Docker
- `act`
- `PRIVATE_REPO_TOKEN` secret on Agent-Workspace-1 for GitHub Actions execution

Local agents may invoke the scripts directly. Public Agent-Workspace-1 CI uses the same scripts.

The runner intentionally executes the cloned workflow definitions rather than copying them into the workspace repository's workflow directory. This preserves the target workflow logic while using the public repository's runner for compute.
