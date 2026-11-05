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

## Secret bootstrap

`configure-private-repo-secret.sh` configures the read-capable GitHub Actions secret required by the fallback CI workflow.

Local agents should run:

```bash
bash tools/private-repo-ci/configure-private-repo-secret.sh
```

By default it uses the token from the authenticated `gh` CLI session:

```bash
gh auth token
  -> PRIVATE_REPO_TOKEN
  -> gh secret set PRIVATE_REPO_TOKEN --repo dinilmusick/Agent-Workspace-1
```

The script never prints the token and never accepts it as a command-line argument. For non-interactive execution, provide `PRIVATE_REPO_TOKEN` through the process environment.

Security rule: the script deliberately refuses to substitute GitHub Actions' built-in `GITHUB_TOKEN`. That token is scoped to Agent-Workspace-1 and cannot be assumed to read the separate private repositories.

The configured secret should have only the minimum read access needed by the target private repositories.

## Runtime security invariants

- The private-repository access token is used only for cloning.
- The token-bearing Git remote is replaced immediately after clone.
- The private token is NOT passed to `act` workflows.
- Target workflows execute as untrusted code; do not expose unrelated secrets.
- Cleanup is mandatory and runs through the workflow's exit trap.
- Private source is never committed to Agent-Workspace-1.

## Requirements

- Git
- Docker
- `act`
- GitHub CLI (`gh`) for secret bootstrap
- `PRIVATE_REPO_TOKEN` repository secret on Agent-Workspace-1 for GitHub Actions execution

Local agents may invoke the scripts directly. Public Agent-Workspace-1 CI uses the same scripts.

The runner intentionally executes the cloned workflow definitions rather than copying them into the workspace repository's workflow directory. This preserves the target workflow logic while using the public repository's runner for compute.
