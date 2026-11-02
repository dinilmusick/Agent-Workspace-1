---
name: "Code Review"
slug: code-review
version: 1.0.0
source: Supabase Skills Database
sourceId: 13
status: active
---

# Code Review

Review changes for correctness, regressions, maintainability, security, and compliance with repository conventions.

## Linked tools

- No tool links currently registered.

## Instructions

# Code Review

Review the complete diff in context, not isolated changed lines.

## Review order
1. Understand the requirement and acceptance criteria.
2. Inspect the diff, surrounding callers, interfaces, data models, and relevant tests.
3. Check functional correctness, edge cases, error handling, state transitions, concurrency, and backward compatibility.
4. Check security boundaries: authentication, authorization, input validation, secrets, injection, data exposure, and unsafe defaults.
5. Check architecture: dependency direction, duplicated logic, API stability, coupling, and repository conventions.
6. Check performance and resource behavior where material.
7. Check test quality: whether tests assert observable outcomes and cover failure paths rather than implementation details.
8. Run targeted checks if tools and environment permit.

## Findings
Order findings by severity. Each finding must include file/line, concrete scenario, impact, and a correction. Distinguish confirmed defects from questions or speculative risks. Do not report style preferences as blockers.

Finish with merge readiness and checks actually executed. A clean diff is not proof of runtime correctness.

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
