---
name: "Private Repository CI Workspace Runner"
slug: private-repo-ci-workspace-runner
version: 1.0.0
source: Supabase Skills Database
sourceId: 39
status: active
---

# Private Repository CI Workspace Runner

Reusable fallback for executing and verifying GitHub Actions for private repositories through Agent-Workspace-1.

## When to use

Use extensively whenever a private repository needs CI/build/test evidence and native private GitHub CI is unavailable, exhausted, blocked, or otherwise unsuitable. Do not let private CI availability become a dead end.

## Execution

1. Build a request in .agent/ci-request.json:
   repository, ref, event, workflow, token_mode, request_id.
2. Trigger .github/workflows/private-repo-ci.yml.
3. The public Agent-Workspace runner clones the target into its dedicated clones/ directory.
4. Validate target workflow definitions.
5. Execute the selected workflow(s) with the pinned act release.
6. Capture run status, logs, test/typecheck/build output and artifacts.
7. Independently verify the result.
8. Always remove the clone and credentialed remote.

## Security

- PRIVATE_REPO_TOKEN is read-only and is the normal clone/verification credential.
- clone-only is preferred unless a trusted target workflow genuinely needs GITHUB_TOKEN.
- Never expose CODING_REPO_TOKEN or DEPLOYMENT_TOKEN to target workflow code.
- Never commit credentials or private source into this public repository.
- Running all target workflows is allowed only for trusted repositories whose workflows are safe for verification.

## Evidence

A successful result requires a real Agent-Workspace Actions run, target verification evidence, independent verification where applicable, and confirmed clone cleanup.

## Pattern

request → clone → validate → act → verify → evidence → cleanup
