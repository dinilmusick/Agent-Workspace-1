---
name: "Codebase Architecture"
slug: codebase-architecture
version: 1.0.0
source: Supabase Skills Database
sourceId: 14
status: active
---

# Codebase Architecture

Understand, model, and improve an existing codebase's architecture, module boundaries, domain model, and dependency direction.

## Linked tools

- No tool links currently registered.

## Instructions

# Codebase Architecture

Use when a task changes system structure, module boundaries, domain concepts, or dependency direction.

## Procedure
1. Map the repository from executable entrypoints and package manifests. Trace runtime paths rather than inferring architecture from folder names.
2. Identify bounded contexts, domain entities, services, facades, orchestration, state ownership, persistence, events, and external adapters.
3. Build a dependency graph. Record import direction, cycles, package boundaries, public facades, and runtime ownership.
4. Trace one representative use case through every layer. Compare intended architecture with actual imports and execution.
5. Identify architectural friction: duplicated concepts, misplaced responsibilities, hidden coupling, leaky abstractions, excessive indirection, and unstable contracts.
6. Propose the smallest structural change that improves cohesion without broad unrelated rewrites.
7. Define invariants and tests that prevent boundary regressions. Prefer compile-time constraints and automated architecture tests where practical.
8. Implement in migration-safe steps. Preserve public APIs or provide explicit compatibility transitions.
9. Verify dependency graph, package builds, tests, and real execution paths.

## Output
Provide a concise component map, dependency direction, identified violations, proposed target boundary, migration steps, and verification evidence.

Do not redesign from documentation alone. Existing source and observed runtime behavior are authoritative.

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
