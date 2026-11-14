---
name: "Work Modality Routing"
slug: work-modality-routing
version: 1.0.0
source: Supabase Skills Database
sourceId: 47
status: active
---

# Work Modality Routing

Classify every incoming prompt as conversation or work. Work is either direct-task execution or a work-modality request.

## Contract

conversation → answer directly.

work/direct-task → resolve the existing task, claim it through the Task Ledger, execute its persisted loop, record evidence, and require independent verification.

work/modality → do not execute the prompt as one task. Resolve the relevant Universe/System/Vision, create or reuse a Goal for the requested modality, decompose it into 1–4-action tasks, persist dependencies/checkpoints/verification, then dispatch workers.

## First-class modalities

- implementation-push
- new-repo
- feature
- reconciliation
- obstacle-system-tweak

The canonical catalogue is public.work_modalities. Unknown modality requests must map to an active registered modality or be reported as a capability gap.

## Persistent-context rule

For durable work, resolve existing System → existing appropriate Universe → create System in that Universe → create Universe then System. Never create duplicate systems for the same enduring subject. Child Systems must share the parent's universe_id.

## Obstacle elimination system tweak

Use obstacle-system-tweak when a durable/high-notoriety obstacle should be removed by changing the concerned System. Select the highest-notoriety relevant obstacle, inspect occurrences/resolutions, create a System-level Goal, implement root-cause changes, and verify recurrence reduction. Do not merely repeat a local workaround.

## Persistence

Record actionable requests in public.work_requests when supported, including request_mode, work_modality, prompt, resolved goal/task, agent/session and status. Goals/tasks may carry request_mode and work_modality. Modality is a work-planning mode, not a task_type.

## Completion

A modality request is complete only after its Goal's descendant tasks are independently verified, acceptance criteria pass, evidence is persisted and the final reconciliation is complete.
