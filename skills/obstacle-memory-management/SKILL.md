---
name: "Obstacle Memory Management"
slug: obstacle-memory-management
version: 1.0.0
status: active
---

# Obstacle Memory Management

Persist reusable knowledge about workflow obstacles, not generic conversation memories.

When an obstacle materially blocks, delays or changes work:
1. Normalize the problem, symptoms, root cause and current solution.
2. Search obstacle memory semantically before inserting.
3. If sufficiently similar, update the canonical obstacle and append an occurrence with goal/task/agent, evidence and resolution.
4. Otherwise create a canonical obstacle and its first occurrence.
5. Index the canonical obstacle semantically and establish relevant relationships.
6. Reuse prior verified solutions before repeating failed approaches.

Never create duplicate memories for the same underlying obstacle. The relational obstacle record is canonical; vectors are retrieval indexes.
