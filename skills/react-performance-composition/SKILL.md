---
name: "React Performance and Composition"
slug: react-performance-composition
version: 1.0.0
source: Supabase Skills Database
sourceId: 11
status: active
---

# React Performance and Composition

Improve React rendering efficiency and component API composition without premature memoization or abstraction.

## Linked tools

- No tool links currently registered.

## Instructions

# React Performance and Composition

1. Confirm the React and framework versions and inspect current component composition.
2. Measure or reproduce the performance issue before optimizing.
3. Trace state ownership, update frequency, context propagation, expensive computations, list identity, and component boundaries.
4. Prefer state locality, stable data flow, composition, and smaller update surfaces over blanket memoization.
5. Avoid boolean-prop proliferation; use explicit variants, compound components, or composition when it clarifies valid combinations.
6. Use memoization only where profiling or clear repeated work justifies it. Preserve referential correctness.
7. Check effects for stale closures, unnecessary subscriptions, and incorrect lifecycle assumptions.
8. Verify with React profiling or repeatable measurements and test behavior across relevant routes.
9. Report before/after evidence and tradeoffs.

Do not optimize by suppressing rerenders if doing so creates stale UI or hidden state synchronization.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "vercel-labs/agent-skills"
}
```
