---
name: "Universal Task Router"
slug: universal-task-router
version: 2.6.0
source: Supabase Skills Database
sourceId: 28
status: active
---

# Universal Task Router

Top-level classifier for every incoming user message. Separate ordinary conversation, bounded one-step requests and actionable goals. Route actionable goals through the smallest sufficient skills and tools.

## 1. Conversation gate

- **Conversation:** greetings, acknowledgements, opinions, explanations, simple factual questions, casual discussion and ordinary follow-ups. Respond directly. Do not load skills just because the topic resembles one.
- **Direct one-step request:** a bounded request that can be completed in one response or one straightforward action. Complete directly or invoke one specialist only when it materially improves correctness. Do not create an artificial goal graph.
- **Actionable goal:** planning, multiple dependent actions, coordination, research, tool use, persistent changes, repeated practice or verification. Continue through the routing pipeline.

The user's explicit requested mode wins. If they ask for implementation, act rather than merely describing a plan.

## 2. Goal interpretation

Preserve intended outcome, scope, constraints, preferences, permissions, deadline and prior decisions. Derive observable success criteria. Use Prompt Map when the goal is multi-stage, ambiguous, cross-domain or dependency-heavy. Ask one targeted question only when an ambiguity materially changes the outcome; otherwise infer conservatively.

## 3. Loop routing

For actionable goals, inspect and load Loop Generator when repeated action/observation/diagnosis/verification is needed. A multi-task goal is itself a loop, and every task is also its own loop. These are separate persisted loops, not one synthetic task tree root.

The goal loop coordinates task loops and evaluates overall criteria. Task loops own task-specific execution, parameters, criteria and evidence. Use bounded iteration budgets. Stop on verified success, cancellation, safety/permission boundary, genuine blocker or budget exhaustion.

## 4. Domain routing

Select the narrowest active, published router or specialist:
- Software engineering / coding → Coding Router, then its specialist skills.
- Explicit implementation push / implementation pass / completion-pass requests → Implementation Push, with Coding Workflow + Testing Strategy and problem-specific supporting skills.
- Personal development, habits, values, learning goals or effectiveness → Personal Growth Router.
- Interpersonal communication, relationships, conflict, boundaries or repair → Personal Growth Router, then Relational Skills.
- Exercise, strength, conditioning, mobility or endurance → Fitness Coaching.
- Cooking, culinary technique, food science or meal preparation → Cooking and Culinary Skills.
- Other domains → inspect active skill categories and choose the closest specialist. If none exists, use available tools/research and report the capability gap.

## 5. Recursive skill nesting

Treat skill routing as a graph with arbitrary practical nesting depth:
- Inspect each selected skill's instructions, dependencies, capabilities and triggers before delegation.
- Track visited skill IDs/slugs and detect cycles.
- Load the smallest sufficient skill set, with one primary owner and bounded supporting skills.
- Required dependencies must be available; optional/recommended dependencies are loaded only when relevant.
- Stop descending when a concrete specialist owns the work. Preserve the parent-to-child handoff context.

## 6. Canonical persistent-goal workflow

For an agreed actionable goal requiring persistent progress, multiple tasks or independent ChatGPT conversations, load Task Ledger and Loop Generator.

### Universal goal overview
- At the beginning of every orchestration session, and whenever the user asks what goals remain, call `goal_ledger_overview(null)`.
- Present every visible planning, ready, active and blocked goal, not only the first unfinished goal. Include readable key, status, task counts, running workers, queued tasks, blockers, stale-heartbeat flags and verification state.
- Explain dependencies and why apparently queued work may not yet be claimable.
- A running task is reclaimable only after 60 minutes without a heartbeat. Lease expiry alone cannot bypass this threshold; claims are reassigned atomically.
- Use `goal_ledger_resume_by_key` to load complete context for the selected goal. The overview is discovery, not ownership; never infer a claim from it.
- Use the atomic goal-key claim RPC only after resume. Never directly update task ownership.

### Goal identity
- `goals.name` is the descriptive title shown to the user.
- `goals.goal_key` is the stable readable identifier generated from the title.
- `goals.tags` is the searchable classification set.
- UUIDs are internal relational keys; never present them as the goal's identity.

### Create
1. Discuss and define the desired end state, context, constraints and acceptance criteria.
2. Generate a goal-level Loop Generator contract.
3. Decompose into direct top-level task definitions. Every task and nested task has its own complete loop contract, acceptance criteria, verification plan and task-specific parameter contract where applicable.
4. Call `goal_ledger_create_hierarchical` with title, tags, goal loop and task definitions. Do not call legacy `goal_ledger_create_with_tasks` for new goals; do not create a synthetic root task.
5. Add dependencies, inspect ready leaf-task parallelism and recommend the number of worker chats. The user manually opens those ChatGPT conversations.

### Resume from a new chat
When asked to continue, finish or resume an unfinished goal:
1. Call `goal_ledger_list_unfinished` immediately.
2. If exactly one unfinished goal exists, load it. If multiple exist, show title, readable key, tags and status, then ask the user to choose.
3. If the selected goal is blocked, resume it, report its blocker and do not claim a task until it is unblocked.
4. Call `goal_ledger_resume_by_key` and load complete goal/task context, dependencies, events, goal iterations and task iterations.
5. Tell the user **Loaded goal: <title>**. If asked which goal is loaded, answer with the title, not the UUID.
6. Only after selection and resume, claim one eligible task with `goal_ledger_claim_task_by_key`.

### Execution and completion
- Each worker chat uses a unique agent ID and session ID, claims exactly one task, executes its persisted loop, records iterations/evidence and submits the result.
- Workers do not self-verify. An independent verifier checks every result.
- Record goal-level cycles with `goal_ledger_record_loop_iteration`.
- A goal loop may pass only after all descendant tasks are independently verified, all goal acceptance criteria are satisfied and non-empty evidence is recorded.
- Finalize through `goal_ledger_finalize_by_key`. The database is canonical; recover from Supabase rather than chat history.


### Proactive but consent-based task proposals
After the global overview, compare the user's current request with the persisted task tree. If one concrete missing work item is clearly relevant, propose one task and ask the user **“Should I add this as a task?”** Include title, parent goal key, scope, observable acceptance criteria, dependencies and proposed readable slug. Do not insert it until explicit confirmation. On confirmation, call the canonical task-tree creation RPC with its complete loop and verification contract, then report the exact returned task key. Never invent/reserve a key in advance. Do not manufacture tasks when the existing tree already covers the work.

## 7. Task parameters

Use task `parameters` for task-specific configuration, `parameter_contract.required` for mandatory values, and `parameter_contract.properties` for JSON types and optional enum constraints. Workers submit fulfilled values in `result_in.parameter_values`. The database rejects completion if required values are missing or invalid.

## 8. GitHub compute workspace

When an agent needs an actual computation, program, parser, simulation, test or generated artifact, use `.github/workflows/agent-compute.yml` where an authorized workflow-dispatch capability is available. Supported runtimes: Python, Node.js, TypeScript, Bash, Go, Rust, Java, C, C++, C#, Ruby, PHP, Perl, R and PowerShell.

The workflow runs on an ephemeral GitHub-hosted runner with read-only repository permission, no persisted checkout credentials, no application secrets and a bounded execution timeout. It returns an artifact. It is finite compute, not a persistent machine and does not spawn ChatGPT conversations. If the connected GitHub tools cannot dispatch workflows, create a GitHub issue titled `[agent-compute] <goal-key> <runtime>` with a JSON body containing `ref`, `runtime`, `source_file`, `arguments` and `timeout_seconds`. The issue-triggered workflow accepts only owners, members and collaborators. Track the Actions run and artifact. Never claim execution without a real run.

## 9. Execution handoff and output

Pass each skill a compact handoff containing goal, outcome, domain, scope, constraints, permissions, criteria, relevant context, prior work, tools, dependencies and evidence requirements. Verify at the layer where outcomes are observable.

For routed tasks, retain classification, selected skill path, loop activation decision, acceptance criteria, execution order and unresolved capability gaps. Keep ordinary responses concise; do not expose internal routing mechanics unless asked.

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
