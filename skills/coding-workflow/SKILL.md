---
name: "Coding Workflow"
slug: coding-workflow
version: 2.0.1
source: Supabase Skills Database
sourceId: 20
status: active
---

# Coding Workflow

A disciplined end-to-end workflow for implementing software changes with explicit requirements, small steps, verification, and completion evidence.

## Linked tools

- No tool links currently registered.

## Instructions

# Coding Workflow

Use for substantive software implementation spanning more than a trivial edit.

## Procedure
1. Establish the task outcome and observable acceptance criteria. Resolve ambiguity only when it blocks safe implementation.
2. Inspect the repository before planning: identify the active branch, working-tree changes, package manager, build/test commands, architecture, and the files that actually implement the behavior. Treat current source as canonical; treat documentation as evidence to verify.
3. Trace the existing execution path end to end. Identify public interfaces, callers, data contracts, persistence, events, and UI effects affected by the change.
4. Search for existing libraries, utilities, patterns, and open-source implementations before inventing replacements. Prefer the repository's established conventions.
5. Produce a short ordered implementation plan internally. Split work into independently verifiable changes; preserve user changes and avoid unrelated cleanup.
6. Implement the smallest coherent change. Keep interfaces explicit, errors observable, and behavior deterministic. Do not introduce placeholders, fake data, or silent fallbacks.
7. Add or update tests at the narrowest useful level. If a local container/runtime is accessible, clone Agent-Workspace-1 into it and use its tools/scripts as the primary execution substrate. Attempt the target repository directly; for private-repository clone failures, use Agent-Workspace-1's private-repository tooling and dedicated `clones/` workspace as the bridge. Run the target's relevant tests, type checks, lint, and **every repository-defined build script/custom build command that participates in the real build** locally before falling back to GitHub Actions.
8. Use GitHub Actions as the fallback when no usable local runtime exists, the local environment cannot reproduce the required platform, or remote-runner evidence is explicitly required. Do not skip verification merely because private CI is unavailable; use the Agent-Workspace private-repo CI fallback.
9. Inspect the actual runtime result when UI, deployment, networking, or integration behavior is involved. Source correctness is not proof of rendered/runtime correctness.
9. Diagnose failures from logs and reproduction. Fix root causes rather than suppressing errors.
10. Report changed files, behavior, commands/tests run, verified outcomes, and remaining limitations. Never claim a check passed unless it ran and passed.

## Constraints
- Do not overwrite unrelated user work.
- Do not commit, push, merge, deploy, delete, or change production data unless the task authorizes that action.
- Keep secrets out of source, logs, prompts, and task metadata.
- If blocked, preserve the partial work and state the exact blocker and next action.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "obra/superpowers"
}
```


## Required task shape
Before implementation, ensure the persisted task has 1–4 explicit `actions`. If more than four actions are needed, stop decomposition at four and create additional tasks rather than expanding the current task.

## General pattern visibility
For substantive coding work, define and report a `general_pattern` before editing. Use a compact conceptual flow such as `input → validate → transform → persist → verify`. Progress reports should state the pattern and which action is currently executing.

## Coding-skill gate
Coding Workflow is reached through Coding Router. The router and selected specialist must be resolved before implementation begins. Verify at the observable layer after implementation.

## Private repository CI fallback

For private repositories, use native CI when it is available and useful. If it is unavailable, exhausted, blocked, or unsuitable, activate private-repo-ci-workspace-runner and execute the target workflow through Agent-Workspace-1.

Required evidence flow:

request → clone → validate workflows → act → tests/typecheck/build → capture evidence → independent verification → cleanup

Do not stop at private CI unavailable. Do not expose CODING_REPO_TOKEN or DEPLOYMENT_TOKEN to target workflow code.

## Implementation Push mode

When the request is explicitly an implementation push or implementation pass, do not treat it as an ordinary feature task or a narrow review. Activate the Implementation Push skill as the primary specialist.

Required execution pattern:

`whole-codebase re-analysis → completeness audit → reproduce/diagnose → implement/fix → rewire → focused verification → integration/runtime/E2E verification → independent verification → fresh re-analysis`

The pass must search for and address bugs, stubs, placeholders, TODO-like incomplete behavior, disconnected interfaces, partial implementations, dead paths, broken contracts, missing error handling, missing persistence, and systems that are present in source but unreachable in the real execution flow. Continue the loop until no known implementable incompleteness remains. A report of findings without implementing the available fixes is not an implementation push completion.

## Deterministic execution bootstrap

For any substantive repository task, establish the execution substrate before editing: use a usable local container/runtime first; clone Agent-Workspace-1 into that runtime; use its tools/scripts; attempt the target repository directly; if a private target cannot be cloned directly, use the Agent-Workspace-1 private-repository tooling and dedicated clones bridge. Discover and run all repository-defined build, test, typecheck, lint and custom build scripts that participate in the real build. Use GitHub Actions only when local execution is unavailable, insufficient for the target environment, or remote evidence is explicitly required. Capture command results as evidence and require independent verification before completion.

The canonical local preflight is `python tools/agent-bootstrap/bootstrap.py plan`; use `prepare` to establish the workspace and target checkout. Never place credentials in source, logs or task metadata.


## GitHub Issue worker protocol

For parallel coding work, the GitHub Issue is the canonical execution record for the coding task. Create exactly one Issue per independent task and link exactly one dedicated PR.

Worker loop: read Issue → execute → update Current Implementation State → verify → update evidence/PR → continue or wait.

If blocked, write the blocker, exact question, attempted resolution and resume point into the Issue, then poll for the orchestrator response. Never report a blocker only in conversation and stop.

Orchestrator loop: poll Issues → inspect PRs/CI → resolve blockers in Issues → continue polling → reconcile.

Global continue/proceed is safe to send to all workers. Each worker must reread its Issue and take action only if its Issue says actionable. Terminal workers perform no unrelated work.
