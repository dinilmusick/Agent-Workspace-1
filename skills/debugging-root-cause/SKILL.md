---
name: "Debugging and Root-Cause Analysis"
slug: debugging-root-cause
version: 1.0.0
source: Supabase Skills Database
sourceId: 18
status: active
---

# Debugging and Root-Cause Analysis

Reproduce failures, collect evidence, isolate causes, implement fixes, and verify that the original failure is eliminated.

## Linked tools

- No tool links currently registered.

## Instructions

# Debugging and Root-Cause Analysis

1. Capture the exact failure: command/request, environment, timestamp, full error, stack, logs, and expected versus actual behavior.
2. Reproduce before editing. If reproduction is intermittent, identify the triggering conditions and collect repeated observations.
3. Trace the failing execution path from entrypoint to failure. Inspect the actual source, configuration, dependency versions, generated output, and runtime environment.
4. Form ranked hypotheses. Change one variable at a time and use targeted probes to eliminate hypotheses.
5. Find the earliest incorrect state or violated invariant; do not patch only the final symptom.
6. Implement the smallest root-cause fix. Preserve useful error context and add observability where diagnosis was unnecessarily difficult.
7. Add a regression test that fails before the fix and passes after it.
8. Re-run the original reproduction plus relevant unit, integration, build, and runtime checks.
9. Confirm no new regressions. Report root cause, evidence, exact fix, verification, and any unresolved uncertainty.

Do not silence errors, broadly catch exceptions, weaken types, skip tests, or add fallback values merely to obtain a green build.

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
