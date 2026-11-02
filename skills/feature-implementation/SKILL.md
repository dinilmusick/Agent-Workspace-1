---
name: "Feature Implementation"
slug: feature-implementation
version: 1.0.0
source: Supabase Skills Database
sourceId: 19
status: active
---

# Feature Implementation

Translate a feature request into a coherent implementation across existing interfaces, data flows, UI, and tests.

## Linked tools

- No tool links currently registered.

## Instructions

# Feature Implementation

Use for adding or extending a user-visible or system capability.

1. Convert the request into observable outcomes and edge cases.
2. Locate the existing entrypoint, domain model, service/API, state, UI, persistence, and event path relevant to the feature.
3. Identify the smallest complete vertical slice. Reuse established abstractions and dependencies; do not create parallel infrastructure.
4. Define contracts before wiring layers: input, output, validation, errors, authorization, loading/empty/success states, and side effects.
5. Implement the vertical slice in dependency order. Keep each module cohesive and respect existing dependency direction.
6. Add tests for normal behavior, boundary conditions, failure paths, and authorization.
7. Verify integration across all affected layers. For UI, inspect the rendered result; for APIs, exercise real requests; for persistence, verify stored state.
8. Check backward compatibility, migrations, configuration, and release implications.
9. Report what is implemented and what remains unverified.

Never substitute mock behavior for a requested working feature. Clearly label any unavoidable stub and its blocker.

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
