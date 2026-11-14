# Task Ledger 2.6.0 — Blocker-First Addendum

- Every bounded-v2 checkpoint contains `blockers: []`.
- An agent that cannot solve a checkpoint blocker must call `report_checkpoint_blocker`, persist context/evidence, and stop safely.
- Blockers are normalized/deduplicated across agents. Each unique persisted occurrence increments `notoriety`.
- `notoriety > 5` is **notorious** and must be surfaced to the user when the worker cannot resolve it.
- Before ordinary execution, inspect `goal_ledger_blocker_overview(goal_key)` and attempt the highest-notoriety active blocker first.
- User goal priority is separate from blocker notoriety and is normalized to `0..1`: low `0-.24`, medium `.25-.49`, high `.50-.79`, urgent `.80-1`.
- Claim ordering is goal priority → blocker notoriety → existing task priority → age.
- Resolving a blocker persists resolution/evidence, requeues the task, and recomputes remaining task blocker notoriety.
- Supabase is canonical; never keep essential blocker state only in chat.
