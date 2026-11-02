---
name: "Testing Strategy"
slug: testing-strategy
version: 1.0.0
source: Supabase Skills Database
sourceId: 25
status: active
---

# Testing Strategy

Design and execute layered tests that verify behavior from units through integration and end-to-end workflows.

## Linked tools

- No tool links currently registered.

## Instructions

# Testing Strategy

1. Derive tests from observable requirements, invariants, and failure modes.
2. Choose the lowest layer that can prove each property: unit for pure logic, integration for boundaries and persistence, end-to-end for user workflows.
3. Test behavior and contracts, not private implementation details.
4. Cover valid inputs, invalid inputs, boundaries, empty states, permission failures, retries, concurrency, and partial failure as applicable.
5. Use deterministic fixtures and isolated test data. Avoid shared mutable state and timing-dependent assertions.
6. Prefer real implementations for the boundary under test; mock only external systems or nondeterministic dependencies that cannot be controlled.
7. Ensure regression tests reproduce the reported bug.
8. Run tests and inspect failures. Do not equate test discovery or compilation with test success.
9. Report command, test count, pass/fail/skip status, coverage gaps, and untested risks.

Do not inflate coverage with assertions that do not prove meaningful behavior.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "addyosmani/agent-skills"
}
```
