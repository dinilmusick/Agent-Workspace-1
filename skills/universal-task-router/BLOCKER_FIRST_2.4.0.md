# Universal Task Router 2.4.0 — Blocker-First Addendum

For every actionable goal:
1. Load the selected goal.
2. Inspect active checkpoint blockers.
3. Attempt the highest-notoriety blocker before normal task execution.
4. If the blocker is unsolved, persist it with `report_checkpoint_blocker`, stop safely, and surface notorious blockers (`notoriety > 5`) to the user.
5. Use normalized goal `user_priority` (0..1) independently from blocker notoriety.
6. Trust the database claim ordering: goal priority → blocker notoriety → task priority.
