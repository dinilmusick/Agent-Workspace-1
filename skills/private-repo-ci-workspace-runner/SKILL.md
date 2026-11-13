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


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.