---
name: "Implementation Push"
slug: implementation-push
version: 2.0.1
source: Supabase Skills Database
sourceId: 42
status: active
---

# Implementation Push

A deliberate fresh-perspective completion pass over an existing implementation. Use this when the user explicitly asks for an **implementation push**, **implementation pass**, or equivalent request to make an existing codebase more complete.

## Purpose

AI implementation passes frequently leave partial systems behind: stubs, placeholder branches, TODOs, disconnected interfaces, dead paths, incorrect assumptions, missing error handling, incomplete persistence, broken contracts, or features that work only in isolation. An implementation push exists specifically to catch and finish those leftovers.

This is **not** a narrow bug-fix, code-review, or test-only pass. It is a whole-codebase re-analysis followed by implementation and verification.

## Procedure

1. **Re-establish the whole system**
   - Inspect the repository from a fresh perspective rather than assuming previous agents finished correctly.
   - Identify the architecture, entrypoints, packages/modules, services, data stores, configuration, runtime boundaries, public interfaces, event flows, and deployment/runtime topology.
   - Trace important execution paths end to end.
   - Inspect recent work, existing tests, open TODOs and known limitations, but do not restrict the pass to recent diffs.

2. **Find incompleteness**
   Search systematically for:
   - stubs and placeholder implementations;
   - TODO/FIXME/HACK and TODO-like incomplete branches;
   - empty handlers, no-op functions, unreachable paths and silent fallbacks;
   - fake/mock behavior accidentally left in production paths;
   - interfaces with missing callers or implementations;
   - implementations that are wired in one layer but not propagated through the rest of the system;
   - broken or inconsistent contracts between frontend/backend/services/storage/events;
   - missing error handling, validation, authorization or persistence;
   - configuration/runtime mismatches;
   - tests that compile but do not exercise the real behavior;
   - features that are locally implemented but not reachable through the actual product flow.

3. **Diagnose before editing**
   - Reproduce concrete failures where possible.
   - Determine root causes rather than patching symptoms.
   - Preserve the repository's intended architecture and existing user work.
   - Reuse existing abstractions; do not create parallel infrastructure merely to close a finding.

4. **Complete the implementation**
   - Implement genuine missing behavior.
   - Wire disconnected systems across their real boundaries.
   - Replace accidental placeholders/fakes with production behavior.
   - Fix root-cause bugs discovered during the pass.
   - Add or repair regression coverage for important findings.
   - Do not stop after producing an analysis report when the missing work is implementable.

5. **Verify in widening layers**
   - Run focused checks immediately after each coherent change.
   - Run unit/component tests for local behavior.
   - Run integration tests for boundaries, persistence, APIs and services.
   - Exercise real runtime behavior where possible.
   - Run browser/API/platform/end-to-end workflows when the system crosses those boundaries.
   - Inspect logs, network behavior, persisted state and rendered output where relevant.
   - Use Agent-Workspace-1 for broader repository/CI/ecosystem verification when needed.

6. **Repeat**
   Treat the pass as an iterative loop:

   `re-analyze → find → reproduce → diagnose → implement/fix → focused verify → broader verify → independent verify → re-analyze`

   Continue until the implementation is demonstrably complete or every remaining gap has a concrete external blocker or is explicitly outside scope.

## Fresh-perspective rules

- Never assume a previous implementation pass was complete.
- Do not equate green tests with complete implementation.
- Do not equate a successful build with correct wiring.
- Do not equate source-level presence with runtime reachability.
- Re-check areas that previous agents claimed were finished.
- Look for omissions between layers, not only obvious syntax errors.
- Prefer evidence from actual execution over assumptions or documentation.

## Completion standard

An implementation push is complete only when:
- the whole codebase has been re-analyzed;
- known bugs found during the pass have been fixed or externally blocked;
- meaningful stubs/placeholders/incomplete systems have been completed or explicitly blocked;
- affected systems are correctly wired together;
- relevant tests and runtime/E2E checks have been executed;
- failures have been diagnosed and repaired or documented as genuine blockers;
- independent verification has been performed where available;
- evidence records what was inspected, changed, tested, and verified.

Never report "implementation push complete" merely because the analysis finished.

## Constraints

- Preserve user changes and unrelated working code.
- Do not introduce fake behavior, speculative APIs, or silent fallbacks.
- Do not publish/package/deploy merely to iterate; follow the repository's normal development workflow.
- Do not commit, push, merge, deploy, delete, or alter production data unless authorized.
- Keep secrets out of source, logs, prompts and task metadata.
- If blocked, preserve partial work and record the exact blocker, attempted resolution and next actionable step.

## Task shape

Before execution, persist 1–4 explicit actions and a general pattern. A suitable pattern is:

`discover → diagnose → complete → integrate → verify → re-analyze`

If the work exceeds four actions, split it into additional tasks without losing the implementation-push mode.

## Routing

Explicit phrases such as "implementation push", "do an implementation push", "implementation pass", "completion pass", or "make the implementation more complete" should select this skill as the primary coding specialist. Supporting skills normally include Coding Workflow and Testing Strategy, with Debugging/Root-Cause and Code Review added when findings require them.


## Mandatory PR workflow

Every implementation push is an independent change unit and **MUST use a new dedicated GitHub PR**.

### PR isolation

- Never perform an implementation push directly on `main`.
- Never fold two implementation pushes into the same PR.
- Multiple implementation pushes for the same repository are intentionally allowed to run in parallel; each gets its own branch and PR.
- Keep the push's scope isolated so its findings, fixes, tests and verification can be reviewed independently.
- Resolve/reconcile conflicts only within the normal repository workflow; do not collapse parallel pushes merely because they target the same base.

### Branch and PR naming

Use a deterministic, descriptive name such as:

`implementation-push/<repo-or-scope>/<short-descriptor>`

The PR title should identify the implementation-push scope, for example:

`implementation-push: <repo-or-scope> — <short descriptor>`

### Mandatory PR description

The PR body MUST explicitly enumerate what this particular implementation push found and changed. At minimum record:

1. **Exact stubs/placeholders** completed or removed.
2. **Exact bugs** diagnosed and fixed.
3. **Exact incomplete features** fleshed out.
4. **Exact wiring/integration changes** made.
5. **Exact behavior/configuration/code removed**, if anything was removed.
6. **Tests and end-to-end workflows** executed and their results.
7. **Remaining gaps/blockers**, if any, with the concrete reason.

Do not use vague descriptions such as "fixed various bugs" or "completed implementation." Findings must be concrete enough for a reviewer to understand exactly what changed without reconstructing the entire investigation.

### PR lifecycle

`create dedicated branch → fresh re-analysis → implement/fix → focused verification → integration/E2E verification → write exact PR findings → independent verification → PR ready for review`

The implementation push is not complete merely because the PR exists. The PR is the evidence container for that push and must contain the concrete findings, implementation work and verification evidence.


## Persistent multi-agent execution

When decomposing an implementation push for parallel workers, create one GitHub Issue per independent task and one dedicated PR per worker. The Issue is the worker's durable execution context.

### Worker state contract

The worker MUST maintain a Current Implementation State section containing:
- Status: IN_PROGRESS | BLOCKED | WAITING | COMPLETE | FAILED
- Completed work
- Current work
- Next action
- Blocker
- Question for orchestrator
- Orchestrator response
- Resume point
- Files/tests/evidence

A blocker must be written to the Issue before waiting. The worker then polls the Issue for an orchestrator response. Never make the user reconstruct worker state from chat.

### Orchestrator contract

The main implementation-push agent continuously polls active Issues, linked PRs and CI, resolves worker questions by writing responses into Issues, and keeps polling until the execution reaches a terminal condition. A later continue or proceed prompt is a global resume signal: every worker rereads its Issue and independently decides whether to resume, continue, remain waiting, or do nothing because its task is terminal.

This protocol deliberately makes bulk prompting safe and minimizes user scheduling. Do not create duplicate work when a worker receives a global continuation signal.
