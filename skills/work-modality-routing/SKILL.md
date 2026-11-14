---
name: "Work Modality Routing"
slug: work-modality-routing
version: 2.0.0
source: Supabase Skills Database
sourceId: 47
status: active
---

# Work Modality Routing

Canonical work-routing contract after Universal Task Router classification.

## Boundary

Universal Task Router owns response-type classification. This skill owns WORK_RESPONSE planning for work modalities. It must never reclassify ordinary conversation.

Response hierarchy:
CONVERSATIONAL_RESPONSE → direct answer
WORK_RESPONSE → DIRECT_TASK | WORK_MODALITY

## Work types

Every WORK_RESPONSE has one work type:
EXECUTE | GENESIS | CONTRACT | MODIFY | MEMORY | SELF_IMPROVEMENT | INTEGRATE

EXECUTE = complete existing work.
GENESIS = create governed structure: Vision, Goal, Task, System, ecosystem, repository, etc.
CONTRACT = define loop satisfaction, completion predicates, acceptance or verification contracts.
MODIFY = change an existing System, workflow, skill or architecture.
MEMORY = persist useful observations, decisions, facts or learned patterns.
SELF_IMPROVEMENT = remediate recurring problems or optimize already-working systems.
INTEGRATE = reconcile, synchronize, merge or release existing work.

## Registered modalities

- implementation-push
- new-repo
- feature
- reconciliation
- obstacle-system-tweak

The database catalogue is authoritative. Do not invent a modality. New modalities must be registered before routing.

## Planning contract

resolve → choose work type → resolve/reuse System/Vision/Goal → decompose into 1–4-action Tasks → persist dependencies/checkpoints/acceptance/verification → claim → execute → evidence → independentVerify → finalize

A modality prompt creates/reuses durable work structure before execution. A direct task prompt does not create duplicate structure; it resolves and claims the existing task.

## Self-improvement

SELF_IMPROVEMENT may remediate recurring obstacles or optimize already-working systems. Pattern: observe → analyze → memory/obstacle → create remediation/optimization work → implement → verify → propagate.

## System-first

Resolve an existing System before creating another. Every System belongs to a Universe. Parent/child Systems must share the same Universe. Cross-Universe relationships use explicit relationships/wormholes, never parentage.

## Persistence

Record WORK_RESPONSE classification in public.work_requests using request_mode as the persisted response_type field for compatibility. Record work_modality, prompt, resolved Goal/Task, agent/session and status. Goals and Tasks may carry the same response type and modality.

## Completion

A modality request is complete only when its descendant work is terminal, acceptance passes, evidence is persisted, independent verification succeeds and any required reconciliation is complete.
