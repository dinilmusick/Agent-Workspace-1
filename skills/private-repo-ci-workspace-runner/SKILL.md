---
name: "Private Repository CI Workspace Runner"
slug: private-repo-ci-workspace-runner
version: 1.1.0
source: Supabase Skills Database
sourceId: 39
status: active
---

# Private Repository CI Workspace Runner

Reusable fallback for executing and verifying GitHub Actions for private repositories through Agent-Workspace-1.

## When to use

Use extensively whenever a private repository needs CI/build/test evidence and native private GitHub CI is unavailable, exhausted, blocked, or otherwise unsuitable. Do not let private CI availability become a dead end.

## Mandatory obstacle reflex

Every failed or degraded CI step is an obstacle candidate.

```text
run
  -> observe failure
  -> classify
  -> semantic-search obstacle memory
  -> record occurrence + evidence
  -> apply verified solution / repair
  -> rerun
  -> independently verify
  -> update obstacle resolution
```

Do not jump directly from a red CI result to editing application code.

## Execution

**Local runtime is preferred.** This workflow is the fallback when a local container/runtime is unavailable or cannot execute the target reliably.

1. If a local container/runtime is available, first clone Agent-Workspace-1 into it and attempt direct target-repository cloning there.
2. If the private target cannot be cloned directly, use Agent-Workspace-1's GitHub/private-repository tooling to materialize the authorized target under its dedicated `clones/` area, then operate through the public Agent-Workspace-1 checkout and its scripts/tools.
3. Run the target's native install, lint, format, typecheck, test, integration and **custom build scripts** locally whenever possible.
4. Only when the local runtime is unavailable or insufficient, build a request in `.agent/ci-request.json`:
   repository, ref, event, workflow, token_mode, request_id.
5. Trigger `.github/workflows/private-repo-ci.yml`.
6. The public Agent-Workspace runner clones the target into its dedicated `clones/` directory.
7. Validate target workflow definitions and the requested ref.
8. Before execution, inspect newly added or modified tests and verify imports against actual target exports; run narrow tests locally when possible.
9. Execute the selected workflow(s) with the pinned `act` release.
7. Capture run status, logs, test/typecheck/build output and artifacts.
8. If any step fails:
   - classify the failure;
   - search obstacle memory;
   - record the occurrence before changing code;
   - fix the smallest correct layer;
   - rerun.
9. Independently verify the result.
10. Always remove the clone and credentialed remote.
11. Update the obstacle resolution with final evidence when an obstacle occurred.

## Failure classification

Distinguish:
- workflow infrastructure failure;
- clone/ref/token failure;
- dependency/toolchain failure;
- implementation failure;
- test-wiring/import failure;
- environment-dependent runtime failure;
- Agent-Workspace substrate defect.

The last category is important: when the runner itself caused the failure, improve the runner/skill/workflow rather than teaching the target repository to work around the defect.

## Known incidents

### Luth test-import drift

Agent Workspace run `42039453905` cloned `dinilmusick/Luth@main`, validated workflows, installed dependencies, and passed typecheck, but failed because `tests/canonical-auth-contract.test.ts` imported `getSystemDatabaseUrl` from the wrong module. The canonical resolver lived in `src/backend/types.ts`. The error was `TypeError: getSystemDatabaseUrl is not a function`. The test was corrected and rerun successfully in Agent-Workspace run `42042564939`.

### Agent-Workspace act bootstrap transient failure

Agent Workspace run `42043556266` failed while installing `act` because a single GitHub release download returned HTTP 504. Clone and target workflow execution were skipped. The substrate was hardened with bounded curl retries/timeouts while retaining SHA256 verification. Subsequent run `42043746694` reached successful act installation, clone, workflow validation, and target-workflow execution.

## Evidence

A successful result requires:
- a real Agent-Workspace Actions run;
- target verification evidence;
- independent verification where applicable;
- confirmed clone cleanup;
- obstacle records for material failures encountered during the run.

## Pattern

```text
request
 -> clone
 -> validate-ref
 -> inspect-test-wiring
 -> act
 -> classify
 -> obstacle-search
 -> obstacle-record
 -> repair
 -> rerun
 -> independent-verify
 -> evidence
 -> cleanup
 -> obstacle-resolution-update
```
