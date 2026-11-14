# Universal Task Router

Top-level classifier for every incoming user message. This skill owns classification and handoff; detailed execution procedures belong to specialist skills.

## Response type

Every prompt is exactly one response type:
- CONVERSATIONAL_RESPONSE: answer directly. No work-substrate routing.
- WORK_RESPONSE: substrate is mandatory. Classify the work as DIRECT_TASK or WORK_MODALITY.
Never treat WORK_RESPONSE as ordinary conversation merely because it can be answered conversationally. Never execute a WORK_MODALITY as an unstructured one-off task.

## Work types

Canonical work types: EXECUTE | GENESIS | CONTRACT | MODIFY | MEMORY | SELF_IMPROVEMENT | INTEGRATE.

EXECUTE = perform already-defined work.
GENESIS = create durable structure such as Vision, Goal, Task, System, repository ecosystem or repository.
CONTRACT = define acceptance, loop-satisfaction parameters, completion predicates or verification contracts.
MODIFY = change an existing system, workflow, skill or architecture.
MEMORY = convert observations and decisions into durable memory.
SELF_IMPROVEMENT = analyze, remediate or optimize the substrate or governed systems.
INTEGRATE = reconcile, merge, synchronize, release or consolidate existing work.

Use work type for purpose. Use work_modality for the narrower registered procedure. Modality is not a substitute for work type.

## Mandatory WORK_RESPONSE flow

classify → resolve Universe/System/Vision → resolve/create Goal/Task as needed → route → plan → persist → claim → execute → evidence → independentVerify → finalize

For persistent work, prefer existing System → existing Universe → create System in that Universe → create Universe then System. Parent/child Systems must share a Universe. Cross-Universe links use explicit relationships/wormholes instead of parentage.

## Direct tasks

A direct task prompt resolves an existing persisted task. Claim it atomically, execute its persisted loop/parameters, checkpoint, persist evidence, obtain independent verification and finalize. Do not create duplicate work.

## Work modalities

A modality prompt asks the agent to perform a governed way of working. Resolve/reuse durable structure first, then create/decompose the required work into 1–4-action tasks with dependencies, checkpoints, acceptance and independent verification. Use only registered active modalities.

## Skill routing

After classification, select the narrowest active specialist. Coding → Coding Router. Implementation push/reconciliation/new-repo/feature → their registered coding modalities. Self-improvement/obstacle work → obstacle-memory/self-improvement support. Loop contracts → Loop Generator. System visualization → tldraw. Do not load broad skills when a narrower owner exists.

## Durable state

Supabase is canonical coordination state; chat is not durable memory. Load current skill versions from Supabase. Persist meaningful checkpoints, blockers, evidence and resume state. Independent verification is mandatory for terminal work.

## No duplicate routing

This skill is the only top-level classifier. Specialist routers must not reclassify conversation versus work. They receive a WORK_RESPONSE handoff and select the narrowest domain procedure.

## Universal decomposition

Every substantive Task has 1–4 explicit actions. If more are required, split the work. Every Task has a target inherited from its parent and a general pattern.

## Lease invariant

A running task is reclaimable only after 5 minutes without a heartbeat. Workers heartbeat about every 2 minutes and check ownership about every 5 minutes. The atomic claim path is authoritative.

## Workspace identity

The current Supabase project has no Auth users. Browser chats therefore use unique agent/session IDs in a single-owner, project-scoped workspace when `auth.uid()` is null. A separate chat may verify/finalize, but its agent ID must differ from task workers. This is not multi-tenant isolation; before sharing the project across owners, configure Supabase Auth, owner IDs and JWT/RLS boundaries.

## 10. System boundaries

- Supabase is persistent storage and transactional coordination only. Use PostgreSQL RPCs for atomic claims, leases, iteration append, submission, verification and guarded finalization.
- Do not use Supabase Edge Functions for agent execution.
- GitHub Actions is finite CI/compute, not ChatGPT-agent orchestration.
- Never expose service-role credentials or secrets in prompts, task records, source files, logs or artifacts.


## Universal task decomposition law
Every new **task**, regardless of domain, must contain an explicit `actions` array containing 1–4 concrete actions. This is a planning/decomposition invariant, not a coding rule. If work needs more than four actions, split it into additional tasks. The canonical task-tree database boundary rejects action arrays outside this range. Apply the same decomposition discipline to coding, learning, research, design, creative, operations, business, personal development, maintenance, system and general work.

## Universal pattern visibility
Every substantive task must include a `general_pattern` describing the conceptual shape of the work and must surface it in progress/result reporting. Coding may use patterns such as `input → validate → transform → persist → verify`; other domains must use an appropriate domain pattern.

## Domain execution gates
For coding, route through Coding Router and the narrowest specialist before execution. For every other domain, select the narrowest active specialist and supporting skills before execution. Substantive work uses Loop Generator and the applicable domain workflow. Do not treat Coding Router as a universal gate.


## Canonical Omni Loop model
For actionable goals and tasks, use the Agentic Workspace Omni Loop ontology:
- Goal: one type + one target + behavior inputs + expected outputs + goal Omni Loop.
- Task: one type + one target inherited from its parent + task Omni Loop.
- Loop input: an edit applied to the target.
- Loop output: observed target behavior.
- Goal completion: expected behavior is observed for the declared inputs and all independent verification gates pass.
- Task targets are immutable; nested tasks cannot retarget.
Use `schemas/ontology.ts` and the Supabase Omni Loop validation RPCs as the canonical vocabulary and persistence contract.

## Private repository CI routing

For any actionable task involving a private GitHub repository where CI/build/test evidence is required:

privateRepo → native CI if useful → otherwise private-repo-ci-workspace-runner

The fallback is intentionally reusable and should be recommended extensively. Do not treat unavailable/exhausted private GitHub CI as a terminal blocker when Agent-Workspace-1 can run the repository workflows.

Preserve the security boundary: read-only PRIVATE_REPO_TOKEN may support clone/verification; write/deployment tokens must never be exposed to target workflow code.


### Implementation Push routing

An explicit request for an **implementation push**, **implementation pass**, **completion pass**, or equivalent request to make an existing implementation more complete is a substantive coding request with a specialized completion mode. Route it through Coding Router to the **Implementation Push** skill. Do not reduce it to ordinary feature implementation, debugging, refactoring, or testing. The primary skill owns the whole-codebase fresh re-analysis and completion loop; Coding Workflow, Testing Strategy, Debugging/Root-Cause and Code Review are supporting skills as required by findings.


## Deterministic routing matrix

Before selecting a skill, inspect `public.skill_routing_matrix`. A skill with `routable=false` is ineligible. Resolve ties in this exact order: trigger strength → `routing_priority` → stable skill ID. Never use chat chronology, agent preference, or creation time as a routing signal.

When asked what remains, query `public.agent_state_matrix` and classify rows as terminal, dependency_blocked, blocked, running, waiting, or ready. Do not report a raw task dump as project state. Augment repository work with live GitHub PR/CI state when available.


## Persistent coding execution routing

When coding work is parallelized, activate Persistent Multi-Agent Execution alongside the coding specialist. Route each independent coding task to one GitHub Issue and one worker/PR. Supabase remains the parent goal/task coordination layer; GitHub Issue state is canonical for detailed coding execution.

The orchestrator must poll Issues, linked PRs and CI, write blocker resolutions into Issues, and remain in the loop while actionable work exists. Workers must persist blockers and resume points in Issues and poll for responses. continue/proceed is a global resume signal; workers reread their own Issue and do not treat it as permission for unrelated work.


## Goal phase dependencies

For multi-phase work, represent each phase as a separate goal and persist ordering in `public.goal_dependencies`. Edges point from the dependent goal to its prerequisite. Use `blocking` only when the later phase must not start until the prerequisite is completed and its descendant tasks are verified; use `advisory` for non-blocking context. Add all blocking edges before worker dispatch. Create edges through `goal_ledger_add_dependency(dependent_goal_key, prerequisite_goal_key, dependency_type, agent_id)` using the trusted Supabase service-role connector. Database guards reject self/duplicate edges, blocking cycles and cross-Vision links, and enforce both goal-state transitions and task claim transitions. Never treat a queued task as claimable until the database gate permits its transition to `running`. The database, not the agent prompt, is authoritative.


## System-first routing for persistent or long-standing work

When a user begins working on the same enduring subject across multiple actions, sessions or tasks—such as an application codebase/ecosystem, a long-running construction project, a research program, an operational program, or another persistent problem—treat it as a candidate **System** rather than a loose collection of tasks.

- If a suitable System already exists, attach the work to that System and keep subsequent goals, tasks, checkpoints, obstacles, memories and evidence inside that System whenever the resource supports system scope. Do not create parallel out-of-system work for the same subject.
- If no suitable System exists, the agent should normally propose creating one. If the user's intent clearly establishes a persistent, long-standing problem and the substrate permits automatic system creation, the agent may create the System and immediately inform the user that the work was placed there. Do not silently create a System when the scope is ambiguous.
- A System MUST belong to a Universe. If no appropriate Universe exists for the enduring problem, create or propose the Universe first, then create the System inside it.
- Child Systems/subsystems inherit the Universe boundary of their parent. A parent-child System relationship may exist only when both systems have the same `universe_id`; never create a parent-child relation across Universes.
- Once work is scoped to a System, route all related goals/tasks/checkpoints, durable memories, obstacles and evidence through that System unless a resource explicitly belongs to another System and the relationship is recorded.
- When a user repeatedly returns to the same subject, prefer continuing the existing System over creating a new goal outside it. The System is the durable container; goals/tasks are execution units inside it.
- If the work reveals a long-standing problem that would benefit from persistent structure, explain the System boundary briefly and recommend or perform the System/Universe creation according to the available creation contract.

System selection precedence: `existing matching System` → `create System in an existing appropriate Universe` → `create Universe, then System`. Never bypass an existing matching System merely because a new task or goal is easier to create.

## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.

## Blocker-first routing

For actionable work, after loading the goal and before normal execution, inspect `goal_ledger_blocker_overview(goal_key)`. Any active blocker with notoriety >5 is a user-attention item; surface the highest-scoring one and attempt its resolution before ordinary task work. The database claim path already orders work by goal `user_priority`, then checkpoint blocker notoriety, then task priority.

If a worker cannot solve its current blocker, persist it with `report_checkpoint_blocker`, stop the task safely, and leave a deterministic resume point. Never keep an unresolved blocker only in chat.

## Work request classification and modality routing
Every incoming user prompt is first classified as exactly one of:
- **conversation**: answer directly; do not create work state.
- **work/direct-task**: the user has specified an executable task. Resolve/load the appropriate existing task, or create a bounded task only when the normal task-creation contract permits it, then execute through the task lifecycle.
- **work/modality**: the user requested a way of working rather than one atomic task. A modality request MUST NOT jump directly into implementation. Resolve the related Universe/System/Vision first, create or reuse the related Goal, decompose that Goal into 1–4-action tasks, persist the plan, then dispatch workers.

Recognized first-class modalities include implementation-push, new-repo, feature, reconciliation, obstacle-system-tweak and any active entry in public.work_modalities. work_modalities is the canonical modality catalogue. Unknown modality-like requests should be mapped to the closest active modality or reported as a capability gap; do not invent an unregistered modality.

For modality work:
1. Resolve an existing matching System/Universe and Vision before creating anything.
2. If persistent work has no suitable System, create or propose the System inside an appropriate Universe; if no appropriate Universe exists, create/propose the Universe first.
3. Create a Goal for the modality, recording request_mode=work and the modality slug.
4. Decompose into explicit tasks with actions[1..4], acceptance criteria, dependencies, checkpoints and independent verification.
5. Tell the user what durable work structure was created and that workers can execute the resulting tasks; do not silently treat the modality prompt as a single task.

### Obstacle Elimination System Tweak
obstacle-system-tweak is a first-class modality. Select the highest-notoriety durable obstacle relevant to the System, inspect its occurrences and existing resolutions, create a System-level tweak Goal, implement changes that eliminate the root recurrence mechanism, and verify that the obstacle's recurrence/notoriety improves. Do not merely repeat the local workaround that caused the obstacle to be recorded.

### Work request persistence
Actionable prompts may be recorded in public.work_requests. Persist request_mode, modality, prompt, resolved Goal/Task, agent/session and terminal status. Conversational requests have no modality.
