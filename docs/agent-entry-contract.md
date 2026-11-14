# Agent Entry Contract

## Response hierarchy

Every incoming user prompt is classified exactly once:

CONVERSATIONAL_RESPONSE → answer directly; no substrate routing.

WORK_RESPONSE → substrate usage is mandatory.
→ DIRECT_TASK: resolve and execute the existing persisted task.
→ WORK_MODALITY: resolve/reuse durable structure, create/reuse the required Goal/Tasks, then execute.

## Work types

EXECUTE — perform existing work.
GENESIS — create governed structure.
CONTRACT — define acceptance, loop satisfaction, completion or verification contracts.
MODIFY — change an existing governed system.
MEMORY — persist useful observations, decisions or patterns.
SELF_IMPROVEMENT — remediate recurring problems or optimize existing systems.
INTEGRATE — reconcile, synchronize, merge or release existing work.

Work type answers “what kind of work is this?” Work modality answers “which registered procedure performs it?”.

## Universal lifecycle

classify → resolve → route → plan → persist → claim → execute → evidence → independentVerify → finalize

Persistent work resolves existing Universe/System/Vision before creating new structure. Parent/child Systems must share a Universe. Chat is not durable state.

## Agent rule

If response type is WORK_RESPONSE, do not bypass the substrate. Load the current skill, persist the work, use the canonical claim path, checkpoint durable state, and independently verify terminal results. If response type is CONVERSATIONAL_RESPONSE, answer directly.
