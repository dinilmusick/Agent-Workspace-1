---
name: "Database Engineering"
slug: database-engineering
version: 1.0.0
source: Supabase Skills Database
sourceId: 27
status: active
---

# Database Engineering

Model data, write safe SQL, design migrations and indexes, and verify database security and query behavior.

## Linked tools

- No tool links currently registered.

## Instructions

# Database Engineering

1. Inspect the live schema, constraints, indexes, policies, triggers, functions, views, and migration history before changing anything.
2. Model entities, ownership, cardinality, lifecycle, uniqueness, nullability, and retention explicitly.
3. Design migrations to be safe, repeatable where possible, and compatible with deployed application versions. Separate backfills from schema transitions when needed.
4. Use transactions for coupled changes. Avoid destructive operations without explicit authorization and a recovery plan.
5. Add indexes based on actual query predicates, joins, sort order, and cardinality; verify with query plans.
6. Review RLS, grants, view security, function security mode, and privilege boundaries. Do not expose service-role credentials to clients.
7. Test migrations against representative data and verify constraints, policies, and query results after applying them.
8. Check rollback/recovery options and deployment ordering.
9. Report schema changes, migration identifiers, verification, and unresolved operational risks.

For Supabase, consult current official documentation and run security/performance advisors after material schema changes.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "microsoft/skills"
}
```
