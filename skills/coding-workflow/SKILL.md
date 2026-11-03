---
name: "Coding Workflow"
slug: coding-workflow
version: 1.0.0
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
7. Add or update tests at the narrowest useful level, then run relevant tests, type checks, lint, and build. Expand verification to integration or browser-level checks when behavior crosses boundaries.
8. Inspect the actual runtime result when UI, deployment, networking, or integration behavior is involved. Source correctness is not proof of rendered/runtime correctness.
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
