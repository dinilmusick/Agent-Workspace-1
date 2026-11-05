---
name: "Private Repository CI Workspace Runner"
slug: private-repo-ci-workspace-runner
version: 1.0.1
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
4. Validate target workflow definitions and the requested ref.
5. Before execution, inspect newly added or modified tests and verify imports against actual target exports; run narrow tests locally when possible.
6. Execute the selected workflow(s) with the pinned act release.
7. Capture run status, logs, test/typecheck/build output and artifacts.
8. Independently verify the result.
9. Always remove the clone and credentialed remote.

## Failure classification

Distinguish workflow infrastructure failure, clone/ref/token failure, dependency/toolchain failure, implementation failure, test-wiring/import failure, and environment-dependent runtime failure.

Known incident: Luth CI run 42039453905 cloned dinilmusick/Luth@main, validated workflows, installed dependencies, and passed typecheck, but failed because tests/canonical-auth-contract.test.ts imported getSystemDatabaseUrl from the wrong module. The canonical resolver lived in src/backend/types.ts. The error was TypeError: getSystemDatabaseUrl is not a function. The test was corrected and rerun successfully in Agent-Workspace run 42042564939. Inspect exports before triggering CI.

## Security

- PRIVATE_REPO_TOKEN is read-only and is the normal clone/verification credential.
- clone-only is preferred unless a trusted target workflow genuinely needs GITHUB_TOKEN.
- Never expose CODING_REPO_TOKEN or DEPLOYMENT_TOKEN to target workflow code.
- Never commit credentials or private source into this public repository.
- Running all target workflows is allowed only for trusted repositories whose workflows are safe for verification.

## Evidence

A successful result requires a real Agent-Workspace Actions run, target verification evidence, independent verification where applicable, and confirmed clone cleanup.

## Pattern

request → clone → validate-ref → inspect-test-wiring → act → classify → verify → evidence → cleanup
