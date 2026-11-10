# Skill System Reconciliation

## Purpose

Make the skill substrate deterministic and auditable. This skill reconciles the declarative skill graph, router reachability, tool bindings, workflow selection, ledger propagation, verification, evidence, and terminal cleanup.

## Canonical flow

request → semantic intent → resource resolution → domain router → workflow selector → Vision/Target/Goal → Task Ledger → execution → evidence → independent verification → reconciliation → terminal cleanup

## Deterministic routing

For coding work, classify exactly one primary workflow before implementation:

- newRepo: a repository/application does not yet exist.
- existingFeature: a defined feature is being added or changed in an existing repository.
- implementationPush: a fresh implementation pass is requested to discover and complete unfinished work.
- repositoryReconciliation: existing PRs/branches/state must be reconciled into a coherent repository state.
- discussion: architecture/design exploration with no authorized implementation yet.

Do not infer a workflow from a single keyword. Resolve intent from the requested outcome, repository state, and explicit constraints.

## Skill-system matrix

Every actionable workflow must be evaluable across these dimensions:

1. trigger/reachability
2. required dependencies
3. required tools
4. required capabilities/resources
5. input contract
6. output contract
7. persistence contract
8. verification contract
9. terminal-state contract
10. evidence contract

A workflow is ready only when all mandatory dimensions are satisfied.

## Routing invariants

- Every actionable coding request reaches exactly one primary coding workflow.
- Every selected workflow resolves its target before creating child tasks.
- Every child task has an immutable parent target and 1–4 executable actions.
- Every implementation task has explicit acceptance criteria.
- Every state-changing action produces evidence.
- Verification is independent of the implementation action where practical.
- A task cannot become terminal merely because a command returned successfully.
- A goal cannot become complete while required child tasks, verification, or reconciliation remain unresolved.
- Cleanup closes/archives terminal work while retaining evidence.
- "what remains?" is a synthesized state query, never a raw task-table dump.

## “What remains?” synthesis

Resolve:

active goals + non-terminal tasks + blocked/dependency state + open PRs + unverified work + known obstacles + missing acceptance criteria + stale/superseded records.

Then collapse duplicate/superseded work, identify blockers and dependency chains, exclude terminal work, rank by dependency impact and user intent, and report remaining work as goals → tasks → blockers → evidence gaps.

## Reconciliation output

The reconciliation result must contain matrix status per workflow, unreachable or ambiguous routes, missing/incorrect dependencies, missing tool/capability bindings, persistence/evidence gaps, verification gaps, stale state, concrete implementation tasks, and terminal cleanup requirements.

Do not mark the system complete while any mandatory matrix dimension is unresolved.

## Supabase boundary

Database migrations, skill records, evaluations, triggers, dependencies, and canonical state changes belong to the separate Supabase PR.
