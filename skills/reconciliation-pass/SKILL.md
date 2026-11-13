---
name: "Reconciliation Pass"
slug: reconciliation-pass
version: 2.0.1
source: Supabase Skills Database
sourceId: 44
status: active
---

# Reconciliation Pass

A repository-level integration pass that reconciles all currently open pull requests into one verified repository state. Use this when the user explicitly asks for a **reconciliation pass**, **reconcile the repo**, **reconcile all PRs**, or equivalent.

## Purpose

A reconciliation pass is not a PR review and not a simple merge-all operation. It resolves the complete set of open PRs against the current repository state, preserves valuable work from superseded PRs, gives greater weight to newer/more complete implementations, and leaves the repository with no open PRs for the reconciled set.

## Repository resolution

- If a repository is explicitly named, resolve it through GitHub and use that exact repository.
- If no repository is named, search the user's accessible repositories through GitHub.
- If the search produces one unambiguous intended repository, select it.
- If multiple plausible repositories remain, ask the user to select one before mutating anything.
- Never infer a repository from stale chat context when GitHub can resolve it.

## Reconciliation algorithm

`resolveRepo → enumerateOpenPRs → inspectAll → classifyRelations → establishPrecedence → reconcileIntoMain → verify → closeSuperseded → re-enumerate → finalize`

### 1. Enumerate the complete PR set

Search GitHub for **all open PRs** targeting the repository's default/base branch. Record for each PR:

- number, title, author, creation/update time;
- base/head branch and head SHA;
- description and stated scope;
- changed files and patches/diff;
- review submissions, review threads and comments;
- mergeability/current status;
- tests/CI evidence when available.

Do not inspect only the newest PR. The complete open set is the reconciliation input.

### 2. Analyze relationships

For every pair or cluster of PRs determine:

- independent/disjoint;
- overlapping but compatible;
- duplicate;
- superseded;
- partially superseded;
- dependent/sequential;
- conflicting.

Compare actual patches and repository state, not titles alone.

### 3. Establish precedence

When multiple PRs implement the same or overlapping behavior:

- prefer the newer implementation **when it is actually more complete, correct, tested, and architecturally current**;
- do not discard an older PR merely because it is older;
- inspect older/superseded PRs for unique fixes, tests, edge cases, documentation, or other valuable code;
- explicitly preserve valuable portions that are absent from the preferred implementation;
- prefer correctness and completeness over chronology.

The result is a synthesized target state, not necessarily the exact contents of any single PR.

### 4. Merge safely

- Reconcile in dependency/precedence order.
- Merge the preferred foundational or independent PRs first.
- After each merge, re-check remaining PRs against the new base.
- If a PR becomes stale, conflicting, or partially superseded, inspect its remaining delta and preserve any valuable changes before closing it.
- Never blindly merge every PR in chronological order.
- Never lose a useful change solely because its PR is superseded.
- Use the repository's normal merge method and branch protection requirements.

### 5. Verify the synthesized state

After the required merges:

- re-enumerate open PRs;
- verify the final main/default branch contains the intended combined behavior;
- run the strongest available focused, integration, CI, and/or end-to-end verification;
- independently inspect the resulting diff/history against the reconciliation decisions;
- confirm no required change from a superseded PR was lost.

If verification fails, continue the reconciliation loop: diagnose → repair/reconcile → verify.

### 6. Close all reconciled PRs

Every PR in the original reconciliation set must end in a terminal state:

- merged when its useful implementation was incorporated;
- closed without merge when its work was fully superseded, duplicated, invalid, or otherwise intentionally not selected;
- a superseded PR must never remain open merely because a newer PR won.

For a PR closed without merge, record why and what useful content, if any, was preserved elsewhere.

## Completion invariant

`openPRs(repository, reconciliationSet) = 0`

and

`finalState = verified(synthesizedValueOfAllRelevantPRs)`

Completion requires evidence for:

- every PR inspected;
- precedence/supersession decisions;
- valuable code preserved from superseded PRs;
- every merge/close action;
- final verification;
- final open-PR enumeration.

Never report reconciliation complete while any PR from the reconciliation set remains open.

## Task shape

Persist 1–4 explicit actions:

1. resolve repository + enumerate all open PRs;
2. inspect, compare, classify and establish precedence;
3. merge/reconcile and preserve valuable superseded work;
4. verify final state and close/re-enumerate all reconciled PRs.

Use an OmniLoop until the completion invariant is true.

## Routing

Exact/phrase triggers include:
- `reconciliation pass`
- `reconcile the repo`
- `reconcile all PRs`
- `do a reconciliation`
- `reconcile the open PRs`

Supporting skills normally include GitHub Development Workspace, Coding Workflow, Testing Strategy, Code Review, and Debugging/Root-Cause when required.

## Safety

- This skill authorizes repository mutation only when the user explicitly requested the reconciliation pass.
- Do not delete branches or alter unrelated issues/resources unless required by the repository workflow.
- Do not discard code without first checking its patch/diff for unique value.
- Do not claim success from merge responses alone; independently verify the final repository state.


## Issue-aware reconciliation

Reconciliation must inspect every linked coding Issue as well as every PR. Read Current Implementation State, blockers, orchestrator responses, evidence and resume points before classifying PRs. Preserve valuable Issue history when synthesizing work. After merges/reverification, synchronize Issue state and close/supersede Issues consistently. Do not declare reconciliation terminal while a linked coding Issue has unresolved actionable state.


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.