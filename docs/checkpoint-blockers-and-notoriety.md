# Checkpoint Blockers and Notoriety

The Agentic Workspace checkpoint contract now treats blockers as durable state.

## Checkpoint shape

Every bounded-v2 checkpoint contains:

```json
{
  "status": "pending",
  "blockers": [
    {
      "blocker_id": "…",
      "blocker_key": "blocker-…",
      "text": "…",
      "notoriety": 6,
      "status": "active",
      "context": {},
      "evidence": []
    }
  ],
  "blocker_notoriety": 6
}
```

An empty checkpoint still contains `"blockers":[]`.

## Reporting

When an agent reaches a blocker it cannot solve, it must call `report_checkpoint_blocker` before stopping. Blockers are normalized and deduplicated across agents. Each distinct occurrence increments the blocker’s `notoriety`.

`notoriety = number of persisted blocker occurrences`

The threshold for a **notorious blocker** is `notoriety > 5`.

The task is moved to `blocked`, and the blocker plus evidence are persisted in the checkpoint. Essential blocker state must never exist only in chat.

## Resolution

A subsequent agent must inspect the highest-notoriety active blocker before ordinary task execution. It should attempt resolution first. A successful resolution uses `resolve_checkpoint_blocker`, records resolution evidence, requeues the task, and recomputes the task's remaining active blocker notoriety.

## Priority

User goal priority is independent of blocker notoriety.

- `0.00–0.24`: low
- `0.25–0.49`: medium
- `0.50–0.79`: high
- `0.80–1.00`: urgent

The database normalizes and validates goal priority in the `0..1` range.

Claim ordering is deterministic:

```
goal user_priority DESC
→ task blocker_notoriety DESC
→ existing task priority
→ task age
```

Within a selected goal, the highest-notoriety checkpoint blocker is the first problem to investigate.

## User attention

`goal_ledger_blocker_attention(goal_key)` returns active blockers with notoriety above 5, ordered by notoriety. Agents must surface the highest-scoring notorious blocker to the user when it cannot be solved autonomously.

## Canonical state

Supabase is authoritative. The repository copy of this document and the Task Ledger / Universal Task Router skills are instructional mirrors only.
