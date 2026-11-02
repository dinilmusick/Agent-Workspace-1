---
name: "Refactoring"
slug: refactoring
version: 1.0.0
source: Supabase Skills Database
sourceId: 12
status: active
---

# Refactoring

Improve internal structure while preserving externally observable behavior and compatibility.

## Linked tools

- No tool links currently registered.

## Instructions

# Refactoring

Use when the goal is structural improvement without changing intended behavior.

1. Define the behavior and public contracts that must remain invariant.
2. Inspect callers, imports, tests, runtime paths, and downstream packages before moving code.
3. Establish a baseline with relevant tests, type checks, builds, and runtime observations.
4. Select one cohesive refactoring seam. Avoid mixing feature changes and unrelated cleanup.
5. Refactor in small steps that keep the repository buildable. Preserve exports, serialization, event semantics, and persisted data contracts unless migration is explicitly required.
6. Remove duplication only when the abstraction represents a stable shared concept. Avoid speculative generalization.
7. Add characterization tests for poorly covered legacy behavior before changing it.
8. Re-run baseline checks after each meaningful step and inspect the final diff for accidental behavior changes.
9. Document any unavoidable compatibility break and migration path.

Success means the same externally observable behavior with a clearer internal structure, demonstrated by tests or runtime evidence.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "mattpocock/skills"
}
```
